#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Cwd        qw(abs_path);
use File::Spec qw();
my $tzdir = abs_path(File::Spec->catdir('t', 'fixtures', 'zoneinfo'));
local $ENV{DATETIME_TIMEZONE_ZONEINFO_DIR} = $tzdir;

use Test2::V0;
use Test2::Tools::Spec;

use Time::Moment                 qw();
use DateTime::TimeZone::Zoneinfo qw(timezone);

use experimental qw(class declared_refs defer refaliasing);

sub tst($in_tm, $out_tz, $out_tm, $desc) {
    my $tm1 = Time::Moment->from_string($in_tm);
    my $of1 = $out_tz->offset_for_datetime($tm1) / 60;
    is($tm1->with_offset_same_instant($of1), $out_tm, $desc . " @{[$out_tz->name]}");
}

tests 'Samoa day lost' => sub {
    my $tz_samoa = timezone('Pacific/Apia');

    tst('2011-12-30T09:59:59Z', $tz_samoa, '2011-12-29T23:59:59-10:00', 'before lost day');
    tst('2011-12-30T10:00:00Z', $tz_samoa, '2011-12-31T00:00:00+14:00', '    at lost day');
    tst('2011-12-30T10:00:01Z', $tz_samoa, '2011-12-31T00:00:01+14:00', ' after lost day');
};

tests 'Iran abolish DST in September 2022' => sub {
    my $tz_iran = timezone('Asia/Tehran');

    tst('2021-02-01T22:00:00Z', $tz_iran, '2021-02-02T01:30:00+03:30', 'Before    DST');
    tst('2021-05-01T22:00:00Z', $tz_iran, '2021-05-02T02:30:00+04:30', 'Still had DST');
    tst('2025-05-01T22:00:00Z', $tz_iran, '2025-05-02T01:30:00+03:30', 'Ditched   DST');
};

tests 'Nepal changes timezone' => sub {
    my $tz_nepal = timezone('Asia/Kathmandu');

    tst('1985-12-31T18:29:59Z', $tz_nepal, '1985-12-31T23:59:59+05:30', 'Nepal last  second of +05:30');
    tst('1985-12-31T18:30:00Z', $tz_nepal, '1986-01-01T00:15:00+05:45', 'Nepal first second of +05:45');
};

tests 'Stockholm joins CET' => sub {
    my $tz_stockholm = timezone('Europe/Stockholm');

    tst('1893-03-31T23:06:31Z', $tz_stockholm, '1893-03-31T23:59:31+00:53', 'Stockholm last second of LMT');
    tst('1893-03-31T23:06:32Z', $tz_stockholm, '1893-04-01T00:06:32+01:00', 'Stockholm move to CET');
};

tests 'Lord Howe island' => sub {
    my $tz_lord_howe = timezone('Australia/Lord_Howe');

    tst('2026-10-03T15:29:59Z', $tz_lord_howe, '2026-10-04T01:59:59+10:30', 'last second of standard time');
    tst('2026-10-03T15:30:00Z', $tz_lord_howe, '2026-10-04T02:30:00+11:00', 'first second of DST (30-min jump)');

    tst('2058-04-06T14:59:59Z', $tz_lord_howe, '2058-04-07T01:59:59+11:00', 'dynamic rule for future DST');
    tst('2058-04-06T15:00:00Z', $tz_lord_howe, '2058-04-07T01:30:00+10:30', 'dynamic rule for future standard');

    tst('2038-10-02T15:29:59Z', $tz_lord_howe, '2038-10-03T01:59:59+10:30', 'Last second of Standard');
    tst('2038-10-02T15:30:00Z', $tz_lord_howe, '2038-10-03T02:30:00+11:00', 'Spring Forward (jumps to 02:30)');

    tst('2100-07-01T12:00:00Z', $tz_lord_howe, '2100-07-01T22:30:00+10:30', 'Standard Time via POSIX string');
    tst('2100-12-01T12:00:00Z', $tz_lord_howe, '2100-12-01T23:00:00+11:00', 'DST via POSIX string');
};

done_testing();

__END__
