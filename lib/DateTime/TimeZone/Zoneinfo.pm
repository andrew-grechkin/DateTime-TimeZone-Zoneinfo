use v5.40;
use experimental qw(class declared_refs refaliasing);

class DateTime::TimeZone::Zoneinfo 1.001 {
    use Carp        qw();
    use Cwd         qw();
    use File::Find  qw();
    use File::Spec  qw();
    use Time::Local qw();

    use DateTime::TimeZone::Zoneinfo::DynamicTransition qw();
    use DateTime::TimeZone::Zoneinfo::Transition        qw();

    use Exporter qw(import);
    our @EXPORT_OK = qw(
        timezone
    );

    use constant {
        'DEFAULT_DIR'        => '/usr/share/zoneinfo',
        'EPOCH_RD_DAYS'      => 719_163,
        'SECONDS_IN_DAY'     => 86_400,
        'TZIF_HEADER_FORMAT' => 'a4 a1 x15 NNNNNN',
        'TZIF_TYPE_FORMAT'   => '(l> C C)*',
    };

    # constructor parameters
    field $dir : param : reader = _default_dir();
    field $name : param : reader;

    # public attributes
    field $path             : reader = File::Spec->catfile($dir, $name);
    field $has_dsts_changes : reader = false;
    field $is_olson         : reader = false;
    field $is_utc           : reader = false;
    field $transitions      : reader = [];
    field $category         : reader;
    field $footer           : reader;
    field $version          : reader;

    # private attributes
    field @offsets;
    field $fh;

    my %INSTANCE_CACHE;
    my @countries;
    my %zones_by_country;

    sub timezone($name = 'local') {
        my $dir;

        if (!$name or $name eq 'local') {
            ($dir, $name) = _get_local_timezone_name();
        }

        return $INSTANCE_CACHE{$name} //= __PACKAGE__->new(name => $name, (dir => $dir) x !!$dir);
    }

    ADJUST {
        Carp::croak("Failed to open zoneinfo file '$path': $!") unless open($fh, '<:raw', $path);

        # zoneinfo data of version >= 2 is backward compatible and always has first part of the file version 1 data.
        # Actual data for version 2+ follows it.
        my ($ttisgmtcnt, $ttisstdcnt, $leapcnt, $timecnt, $typecnt, $charcnt) = $self->_read_header;

        my \@transitions = $self->_read_transitions_v1($timecnt);
        my \@trans_idx   = $self->_read_indices($timecnt);
        my \@types       = $self->_read_types($typecnt);
        my \%abbrevs     = _parse_chars($self->_read($charcnt));

        # ignoring this data for now
        $self->_read(8 * $leapcnt);
        $self->_read(1 * $ttisstdcnt);
        $self->_read(1 * $ttisgmtcnt);

        if ($version >= 2) {
            ($ttisgmtcnt, $ttisstdcnt, $leapcnt, $timecnt, $typecnt, $charcnt) = $self->_read_header;

            \@transitions = $self->_read_transitions_v2($timecnt);
            \@trans_idx   = $self->_read_indices($timecnt);
            \@types       = $self->_read_types($typecnt);
            \%abbrevs     = _parse_chars($self->_read($charcnt));

            # ignoring this data for now
            $self->_read(12 * $leapcnt);
            $self->_read(1 * $ttisstdcnt);
            $self->_read(1 * $ttisgmtcnt);

            $footer = $self->_read_footer;
        }

        close($fh);
        undef($fh);

        my $first_non_dst;
        my %offsets;
        for (my $i = 0; $i < $typecnt; ++$i) {
            Carp::croak("Bad zoneinfo file '$path': invalid abbreviation index") if $types[$i][2] > $charcnt;

            $types[$i][2]     = $abbrevs{$types[$i][2]};
            $first_non_dst    = $i   if !defined($first_non_dst) && !$types[$i][1];
            $has_dsts_changes = true if $types[$i][1];
            undef $offsets{$types[$i][0]};
        }
        @offsets = sort {$a <=> $b} keys %offsets;

        if (@types) {
            my $type = $types[$first_non_dst // 0];
            push $transitions->@*,
                DateTime::TimeZone::Zoneinfo::Transition->new(
                    epoch        => -Inf,
                    offset       => $type->[0],
                    is_dst       => $type->[1] ? true : false,
                    abbreviation => $type->[2],
                );
        }

        for (my $i = 0; $i < $timecnt; ++$i) {
            push $transitions->@*,
                DateTime::TimeZone::Zoneinfo::Transition->from_zoneinfo($i, \@transitions, $types[$trans_idx[$i]]);
        }

        $self->_process_footer;
    }

    method is_dst_for_datetime($tm)     {return $self->_transition_for_epoch($tm->epoch)->is_dst($tm)}
    method short_name_for_datetime($tm) {return $self->_transition_for_epoch($tm->epoch)->abbreviation($tm)}
    method offset_for_datetime($tm)     {return $self->_transition_for_epoch($tm->epoch)->offset($tm)}

    method offset_for_local_datetime($tm, $fold = 1) {
        Carp::croak("Invalid fold value, must be 1 or 0 but got '$fold'") unless $fold == 1 or $fold == 0;

        my @local_rd_values = $tm->local_rd_values;
        my @candidates;

        foreach my $offset (@offsets) {
            my $epoch      = _rd_local_to_epoch(\@local_rd_values, $offset);
            my $transition = $self->_transition_for_epoch($epoch);
            my $new_offset = $transition->offset($tm);
            push @candidates, $offset if $offset == $new_offset;
        }

        return $candidates[0]      if @candidates == 1;
        return $candidates[-$fold] if @candidates > 1;                         # choose offset for ambiguous time [0 or 1]
        Carp::croak("Local time does not exist (due to DST gap): $tm");
    }

    # class methods
    sub is_valid_name($class, $name) {
        return _is_valid_name(undef, $name);
    }

    sub all_names($class) {
        my $dir = _default_dir();
        my @names;

        return unless -d $dir;

        File::Find::find(
            sub {
                return if !-e || -d || !m/^[[:upper:]]/x;
                push @names, $File::Find::name =~ s{^\Q$dir\E\/?}{}r;
            },
            $dir,
        );

        return @names;
    }

    sub categories($class) {
        my %categories;

        # A category is the part before the first '/'
        # Timezones without a '/' (e.g., UTC, GMT) are not considered to have a category.
        for my $name ($class->all_names) {
            if (my ($category) = $name =~ m{^([^/]+)/}) {
                $categories{$category} = 1;
            }
        }

        return (sort keys %categories);
    }

    sub links($class) {
        my $dir = _default_dir();
        my %links;

        return \%links unless -d $dir;

        File::Find::find(
            sub {
                my $path = $File::Find::name;
                return unless -l $path;

                my $link_name = $path =~ s{^\Q$dir\E\/?}{}r;
                my $target    = readlink($path) or return;
                $target =~ s{^\Q$dir\E\/?}{};

                $links{$link_name} = $target;
            },
            $dir,
        );

        return \%links;
    }

    sub names_in_category($class, $category) {
        # It is conventional to treat category names case-insensitively.
        my $lc_category = lc($category);
        my @names;

        for my $name ($class->all_names) {
            if ($name =~ m{^([^/]+)/} && lc($1) eq $lc_category) {
                push @names, $name;
            }
        }

        return @names;
    }

    sub countries($class) {
        _load_countries() unless @countries;
        return wantarray ? @countries : \@countries;
    }

    sub names_in_country($class, $country_code) {
        _load_zones() unless %zones_by_country;
        return wantarray ? $zones_by_country{lc $country_code}->@* : $zones_by_country{lc $country_code};
    }

    sub offset_as_seconds($class, $offset) {
        return $offset;
    }

    sub offset_as_string($class, $offset, $sep = ':') {
        my $sign = $offset < 0 ? '-' : '+';
        $offset = abs($offset);
        my $hours = int($offset / 3600);
        my $mins  = int(($offset % 3600) / 60);

        return sprintf('%s%02d%s%02d', $sign, $hours, $sep, $mins);
    }

    # private methods
    method _read($size) {
        my $read = read($fh, my $result, $size);
        Carp::croak("Failed to read from zoneinfo file '$path': $!") unless defined $read;
        Carp::croak("Bad zoneinfo file '$path': premature EOF")      unless $read == $size;
        return $result;
    }

    method _read_header() {
        my $bytes = $self->_read(44);
        my ($magic, $ver, @counts) = unpack(TZIF_HEADER_FORMAT, $bytes);

        Carp::croak("Bad zoneinfo file '$path': invalid magic number") unless $magic eq 'TZif';

        $version = $ver eq "\0" ? 1 : int($ver);
        Carp::croak("Bad zoneinfo file '$path': malformed version number")  if !(1 <= $version < 4);
        Carp::croak("Bad zoneinfo file '$path': no local time types found") unless $counts[4];

        return @counts;
    }

    method _read_transitions_v1($cnt) {return [unpack('N*',  $self->_read(4 * $cnt))]}
    method _read_transitions_v2($cnt) {return [unpack('q>*', $self->_read(8 * $cnt))]}
    method _read_indices($cnt)        {return [unpack('C*',  $self->_read(1 * $cnt))]}

    method _read_types($cnt) {
        my @values = unpack(TZIF_TYPE_FORMAT, $self->_read(6 * $cnt));
        return [map {[splice(@values, 0, 3)]} 1 .. $cnt];
    }

    method _read_footer() {
        Carp::croak("Bad zoneinfo file '$path': format error (missing newline)") unless $self->_read(1) eq "\n";
        my $footer = '';
        my $buffer;

        $footer .= $buffer while read($fh, $buffer, 4096);

        Carp::croak("Bad zoneinfo file '$path': format error (missing newline)") unless $footer =~ m/\R\z/;
        chomp($footer);

        return $footer;
    }

    method _process_footer() {
        if ($footer && $footer !~ m/(UTC|GMT)/n) {
            my $last_epoch = $transitions->@*      ? $transitions->[-1]->epoch : -Inf;
            my $epoch      = ($last_epoch == -Inf) ? -Inf : _get_start_of_next_year($last_epoch + 1);
            push $transitions->@*,
                DateTime::TimeZone::Zoneinfo::DynamicTransition->from_footer($epoch, $version, $footer);
        }

        return;
    }

    method _transition_for_epoch($target) {
        my \@transitions = $transitions;
        return 0 unless @transitions;

        my ($low, $high) = (0, scalar(@transitions) - 1);

        while ($low < $high) {
            my $m = int(($low + $high + 1) / 2);

            if ($target < $transitions[$m]->epoch) {
                $high = $m - 1;
            } else {
                $low = $m;
            }
        }

        return $transitions[$low];
    }

    sub _load_countries() {
        my $path = File::Spec->catfile(_default_dir(), 'iso3166.tab');
        Carp::croak("Failed to open zoneinfo file '$path': $!") unless open my $fh, '<:raw', $path;

        while (defined(my $line = <$fh>)) {
            next if $line =~ m/^\s*#/;
            chomp($line);
            my ($code, $name) = split m/\s+/, $line, 2;
            push @countries, lc $code;
        }

        @countries = sort @countries;

        return;
    }

    sub _load_zones() {
        my $path = File::Spec->catfile(_default_dir(), 'zone.tab');
        Carp::croak("Failed to open zoneinfo file '$path': $!") unless open my $fh, '<:raw', $path;

        while (defined(my $line = <$fh>)) {
            next if $line =~ m/^\s*#/;
            chomp($line);
            my ($code, $coordinates, $zone, $comments) = split m/\s+/, $line, 4;
            push $zones_by_country{lc $code}->@*, $zone;
        }

        return;
    }

    sub _default_dir() {
        return $ENV{DATETIME_TIMEZONE_ZONEINFO_DIR} || DEFAULT_DIR();
    }

    sub _parse_chars($chars) {
        my %result;

        pos($chars) = 0;

        while ($chars =~ m/\G([^\0]+)\0/g) {
            $result{pos($chars) - length($1) - 1} = $1;
        }

        return \%result;
    }

    sub _get_start_of_next_year($epoch) {
        my $year = (gmtime($epoch))[5];
        return Time::Local::timegm(0, 0, 0, 1, 0, $year + 1);
    }

    sub _rd_local_to_epoch($rd_aref, $offset) {
        my $unix_days = $rd_aref->[0] - EPOCH_RD_DAYS();
        return ($unix_days * SECONDS_IN_DAY()) + $rd_aref->[1] - $offset;
    }

    sub _is_valid_name($dir, $name) {
        return false unless $name;
        return _is_valid_path(File::Spec->catfile($dir || _default_dir(), $name));
    }

    sub _is_valid_path($path) {
        return false unless $path;
        return (-e $path && !-d $path) ? true : false;
    }

    sub _full_path_to_dir_and_name($path) {
        return unless $path;

        my ($volume, $dir, $file) = File::Spec->splitpath(Cwd::abs_path($path));
        my @dir  = File::Spec->splitdir($dir =~ s{[/\\]$}{}r);
        my @name = ($file);

        # NOTE: this heuristic is weak, I know, maybe something better is necessary in future
        if ($dir[-1] && $dir[-1] =~ m/^[[:upper:]]/ && $file && $file =~ m/^[[:upper:]]/) {
            unshift @name, pop @dir;
        }

        return (File::Spec->catdir($volume, @dir), File::Spec->catdir(@name));
    }

    sub _get_local_timezone_name() {
        my ($dir, $name);

        if ($ENV{TZ}) {
            if ($ENV{TZ} =~ m/^:/) {
                # A leading colon indicates the path is relative to the system's zoneinfo directory.
                ($dir, $name) = (undef, $ENV{TZ} =~ s/^:*//r);
            } elsif (_is_valid_path($ENV{TZ})) {
                ($dir, $name) = _full_path_to_dir_and_name($ENV{TZ});
            } else {
                ($dir, $name) = (undef, $ENV{TZ});
            }

            return ($dir, $name) if _is_valid_name($dir, $name);
        }

        my $localtime_path = '/etc/localtime';
        if (-l $localtime_path) {
            if (my $target = readlink $localtime_path) {
                ($dir, $name) = _full_path_to_dir_and_name($target);
                return ($dir, $name) if _is_valid_name($dir, $name);
            }
        }

        my $timezone_path = '/etc/timezone';
        if (-r $timezone_path && open(my $fh, '<', $timezone_path)) {
            my $payload = <$fh>;
            close $fh;
            if ($payload) {
                chomp $name;
                return (undef, $name) if _is_valid_name(undef, $name);
            }
        }

        Carp::croak('Could not determine the local timezone name from the system environment');
    }
}

__END__

=pod

=encoding utf8

=head1 DateTime::TimeZone::Zoneinfo

DateTime::TimeZone::Zoneinfo - A compact and fast loader for IANA Zoneinfo (TZif) files that provides
a `DateTime::TimeZone` compatible interface.

=head1 SYNOPSIS

  use DateTime::TimeZone::Zoneinfo qw(timezone);

  my $tz1 = timezone('Europe/Amsterdam');                              # Get a timezone object
  my $tz2 = DateTime::TimeZone::Zoneinfo->new(name => 'Pacific/Apia'); # Or use constructor directly

  # Use it with any DateTime-compatible library, like Time::Moment
  use Time::Moment;

  my $tm = Time::Moment->now;
  say $tz1->offset_for_datetime($tm);

=head1 DESCRIPTION

This module provides a direct and efficient way to load and interact with the binary
IANA Zoneinfo (also known as Olson) files commonly found on Unix-like systems (e.g., in C</usr/share/zoneinfo>).
It parses the raw TZif format (versions 1, 2, and 3), including historical transitions and future DST
rules defined by POSIX-style TZ strings.

This module doesn't hard-code any timezone information and relies strictly on timezone database provided by OS.

It is designed to be compatible (to some extent) with the C<DateTime::TimeZone> interface, allowing it to serve
as a drop-in timezone providing backend for modules like C<Time::Moment> or C<DateTime>.

=head1 FUNCTIONS

This module makes one function available for export.

=head2 timezone($name)

This is a factory function that returns a new C<DateTime::TimeZone::Zoneinfo> object for the given C<$name>.
It is a shortcut for C<DateTime::TimeZone::Zoneinfo-E<gt>new(name =E<gt> $name)>.
The objects are cached for performance.

=head1 CLASS METHODS

=head2 all_names

  my @all = DateTime::TimeZone::Zoneinfo->all_names;

Returns a sorted list of all available timezone names on the system, including links/aliases.

=head2 categories

  my @categories = DateTime::TimeZone::Zoneinfo->categories;

Returns a sorted list of all available timezone categories (e.g., C<America>, C<Europe>, C<Asia>).

=head2 is_valid_name($name)

  if (DateTime::TimeZone::Zoneinfo->is_valid_name('Europe/London')) { ... }

Returns true if the given C<$name> corresponds to a valid zoneinfo file on the filesystem.

=head2 links

  my $links = DateTime::TimeZone::Zoneinfo->links;

Returns a hash reference where the keys are link names (aliases) and the values are the target timezone
names (e.g., C<{ 'US/Eastern' =E<gt> 'America/New_York' }>)

=head2 names_in_category($category)

  my @zones = DateTime::TimeZone::Zoneinfo->names_in_category('Africa');

Returns a list of all timezone names in the given C<$category>.
The category name is treated case-insensitively.

=head2 countries()

  my @countries = DateTime::TimeZone::Zoneinfo->countries;

Depending on context returns list or arrayref of sorted lower-cased ISO3166 country codes

=head2 names_in_country()

  my @zones = DateTime::TimeZone::Zoneinfo->names_in_country($country_code);

Depending on context returns list or arrayref of timezones used in a country.

COMPATIBILITY: The returned zones don't have any special order.

=head2 offset_as_seconds($offset)

This method is provided for interface compatibility. It simply returns the offset value,
as offsets are always stored in seconds.

=head2 offset_as_string($offset, $separator)

  my $pretty = DateTime::TimeZone::Zoneinfo->offset_as_string(-18000); # -05:00

Returns the given offset formatted as a string, like C<+0100> or C<-05:30>.
The separator default is ':'.

=head1 OBJECT METHODS

These are the primary methods for a timezone object, as required by the C<DateTime::TimeZone> interface.

=head2 offset_for_datetime($dt)

Takes a time object and returns the offset in seconds for that object's UTC epoch time.
This method expects datetime object to describe exact moment in time.

=head2 offset_for_local_datetime($dt)

Takes a time object and returns the offset in seconds for that object's local time.

Objset is expected to provide C<local_rd_values> method.

This method expects datetime object to describe local wall clock time. The timezone or offset information in
provided object will be ignored. For example in time "2026-04-27T08:52:00+02:00" offset will be ignored and
only wall clock time "2026-04-27 08:52:00" will be respected.

This method handles DST ambiguities.
For ambigous times (autumn DST) this method can return smallest or biggest offset, defaulting to the bigger one.

For the time gaps (spring DST) this method will croak if wall clock time doesn't exist in the timezone.

=head2 short_name_for_datetime($dt)

Takes a time object and returns the short abbreviation for the timezone at that time (e.g., C<CET> or C<CEST>).

=head2 is_dst_for_datetime($dt)

Takes a time object and returns true if Daylight Saving Time is in effect at that time.

=head1 AUTHOR

- Andrew Grechkin

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
See the C<LICENSE> file for details.

=cut
