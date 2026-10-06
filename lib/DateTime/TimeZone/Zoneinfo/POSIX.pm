use v5.40;
use experimental qw(class);

class DateTime::TimeZone::Zoneinfo::POSIX {
    use Carp qw();

    field $recipe : param : reader;
    field $system : param = 'posix';

    field $std_abbrev;
    field $std_offset;
    field $dst_abbrev;
    field $dst_offset;
    field $start_rule;
    field $end_rule;

    ADJUST {
        # POSIX.1: std offset [dst [offset] [,start[/time],end[/time]]]
        # Abbreviations: <[+-0-9A-Za-z]{3,}> or [A-Za-z]{3,}
        my $abbrev_re = qr/(?: [[:alpha:]]{3,} | <[-+[:alnum:]]{3,}> )/x;
        my $offset_re = qr/[-+]? \d{1,3} (?::\d{2}(?::\d{2})?)? /x;
        my $rule_re   = qr/J\d+ | \d+ | M\d+ [.] \d+ [.] \d+/x;
        my $time_re   = qr/[-+]? \d{1,3} (?::\d{2}(?::\d{2})?)?/x;

        ## no critic [RegularExpressions::ProhibitComplexRegexes] already composed from named sub-patterns
        my $combined_re = qr{
            \A
                ($abbrev_re)
                ($offset_re)
                ($abbrev_re)
                ($offset_re)?
                (?:,($rule_re)(?:\/($time_re))?,($rule_re)(?:\/($time_re))?)?
            \z
        }x;

        if (my @m1 = ($recipe =~ m/\A ($abbrev_re) ($offset_re) \z/x)) {
            $std_abbrev = $self->_strip_brackets($m1[0]);
            $std_offset = $self->_parse_offset($m1[1]);
        } elsif ($recipe =~ $combined_re) {
            $std_abbrev = $self->_strip_brackets($1);
            $std_offset = $self->_parse_offset($2);
            $dst_abbrev = $self->_strip_brackets($3);
            $dst_offset = (defined $4 && length $4) ? $self->_parse_offset($4) : $std_offset + 3600;

            my $start_rule_raw = $5;
            my $start_time_raw = $6 // '02:00:00';
            my $end_rule_raw   = $7;
            my $end_time_raw   = $8 // '02:00:00';

            if (!defined $start_rule_raw) {
                # Legacy US rules (1976-1986): last Sunday in April to last Sunday in October
                $start_rule_raw = 'M4.5.0';
                $end_rule_raw   = 'M10.5.0';
            }

            $start_rule = {day => $start_rule_raw, time => $self->_parse_offset($start_time_raw, 1)};
            $end_rule   = {day => $end_rule_raw,   time => $self->_parse_offset($end_time_raw,   1)};
        } else {
            Carp::croak("Invalid POSIX TZ recipe: $recipe");
        }
    }

    method _strip_brackets($abbrev) {
        return $abbrev =~ s/\A<|>\z//gr;
    }

    method _parse_offset($offset_str, $is_time = 0) {
        my ($sign, $h, $m, $s);
        if ($offset_str =~ m/\A ([-+])? (\d{1,3}) (?::([0-5]\d)(?::([0-5]\d))?)? \z/x) {
            ($sign, $h, $m, $s) = ($1 // '+', $2, $3 // 0, $4 // 0);
        } else {
            Carp::croak("Invalid offset: $offset_str");
        }

        # Classic POSIX times/offsets max out at 24h; tzfile3 extends transition times to 167h.
        my $max_hours = $is_time && $system eq 'tzfile3' ? 167 : 24;
        Carp::croak("Invalid offset: $offset_str") if $h > $max_hours;

        my $seconds = $h * 3600 + $m * 60 + $s;

        return $is_time
            ? ($sign eq '-' ? -1 : 1) * $seconds                               # transition times are durations
            : ($sign eq '-' ? 1  : -1) * $seconds;                             # POSIX offsets are west-positive; we want east-positive
    }

    method offset_for_datetime($tm) {
        my $epoch = $tm->epoch;
        return $std_offset unless defined $dst_abbrev;

        my $year = (gmtime($epoch))[5] + 1900;

        # The transition to DST is interpreted using the standard offset, and vice versa.
        my $start_epoch = $self->_rule_to_epoch($year, $start_rule, $std_offset);
        my $end_epoch   = $self->_rule_to_epoch($year, $end_rule,   $dst_offset);

        # A non-reversed window spanning the whole year (e.g. a J0/0,J365/25 footer) means
        # perpetual DST: there's no real transition, so always use the DST offset.
        my $year_seconds = ($self->_is_leap($year) ? 366 : 365) * 86_400;
        return $dst_offset if $start_epoch < $end_epoch && $end_epoch - $start_epoch >= $year_seconds;

        # Northern hemisphere: start < end, DST runs inside the year (Standard -> DST -> Standard).
        # Southern hemisphere: start > end, DST wraps the year boundary (DST -> Standard -> DST).
        my $is_dst
            = $start_epoch < $end_epoch
            ? ($epoch >= $start_epoch && $epoch < $end_epoch)
            : ($epoch < $end_epoch || $epoch >= $start_epoch);

        return $is_dst ? $dst_offset : $std_offset;
    }

    method is_dst_for_datetime($tm) {
        return defined $dst_abbrev && $self->offset_for_datetime($tm) == $dst_offset;
    }

    method short_name_for_datetime($tm) {
        return $self->is_dst_for_datetime($tm) ? $dst_abbrev : $std_abbrev;
    }

    method _rule_to_epoch($year, $rule, $prev_offset) {
        my $day_rule = $rule->{day};
        my $time_sec = $rule->{time};
        my $mjd;

        if ($day_rule =~ m/\A M(\d+) [.] (\d+) [.] (\d+) \z/x) {
            my ($month, $week, $dow) = ($1, $2, $3);
            my $first_mjd = $self->_ymd_to_mjd($year, $month, 1);
            my $first_dow = ($first_mjd + 3) % 7;                              # 0 = Sunday

            my $day = ($dow - $first_dow + 7) % 7 + 1;
            if ($week < 5) {
                $day += ($week - 1) * 7;
            } else {
                # Week 5 means "last occurrence", so clamp back into the month.
                my $days_in_month = $self->_days_in_month($year, $month);
                $day += 28;
                $day -= 7 while $day > $days_in_month;
            }
            $mjd = $first_mjd + $day - 1;
        } elsif ($day_rule =~ m/\A J(\d+) \z/x) {
            # Jn ignores Feb 29: J1..J59 are Jan 1..Feb 28, J60 is always March 1.
            my $j = $1;
            $mjd = $self->_ymd_to_mjd($year, 1, 1) + $j - 1;
            $mjd++ if $j >= 60 && $self->_is_leap($year);
        } else {
            # n form (0-365) counts Feb 29, unlike Jn.
            $mjd = $self->_ymd_to_mjd($year, 1, 1) + $day_rule;
        }

        # MJD to Unix epoch, then shift by the transition time relative to the offset
        # that was in effect before the transition.
        return ($mjd - 40_587) * 86_400 + $time_sec - $prev_offset;
    }

    method _ymd_to_mjd($y, $m, $d) {
        if ($m <= 2) {
            $y--;
            $m += 12;
        }
        my $a = int($y / 100);
        my $b = 2 - $a + int($a / 4);
        return int(365.25 * ($y + 4716)) + int(30.6001 * ($m + 1)) + $d + $b - 2_400_001 - 1524;
    }

    method _is_leap($y) {
        return ($y % 4 == 0 && ($y % 100 != 0 || $y % 400 == 0));
    }

    method _days_in_month($y, $m) {
        return (31, ($self->_is_leap($y) ? 29 : 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[$m - 1];
    }
}
