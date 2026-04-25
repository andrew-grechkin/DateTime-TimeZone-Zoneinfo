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

tests 'Europe/Amsterdam Spring Transition: 2026-03-29' => sub {
    my $tz = timezone('Europe/Amsterdam');

    # Spring (gap) 02:00:00 CET -> 03:00:00 CEST
    # when local functions are used offset (Z or any else) is ignored, only wall clock matters
    my $spring_tm1 = Time::Moment->from_string('2026-03-29T01:59:59Z');
    my $spring_tm2 = Time::Moment->from_string('2026-03-29T02:00:00Z');
    my $spring_tm3 = Time::Moment->from_string('2026-03-29T02:59:59Z');
    my $spring_tm4 = Time::Moment->from_string('2026-03-29T03:00:00Z');

    is($tz->offset_for_local_datetime($spring_tm1), 3600, 'DST gap right before');
    is($tz->offset_for_local_datetime($spring_tm4), 7200, 'DST gap right after ');
    like(dies {$tz->offset_for_local_datetime($spring_tm2)}, qr/local time does not exist/i, 'DST gap inside');
    like(dies {$tz->offset_for_local_datetime($spring_tm3)}, qr/local time does not exist/i, 'DST gap inside');
};

tests 'Europe/Amsterdam Autumn Transition: 2026-10-25' => sub {
    my $tz = timezone('Europe/Amsterdam');
    # Autumn (ambiguity) 03:00:00 CEST -> 02:00:00 CET
    # when local functions are used offset (Z or any else) is ignored, only wall clock matters

    my $autumn_tm1 = Time::Moment->from_string('2026-10-25T01:59:59Z');
    my $autumn_tm2 = Time::Moment->from_string('2026-10-25T02:00:00Z');
    my $autumn_tm3 = Time::Moment->from_string('2026-10-25T02:30:00Z');
    my $autumn_tm4 = Time::Moment->from_string('2026-10-25T02:59:59Z');
    my $autumn_tm5 = Time::Moment->from_string('2026-10-25T03:00:00Z');

    is($tz->offset_for_local_datetime($autumn_tm1), 7200, 'DST Before overlap (CEST)');
    is($tz->offset_for_local_datetime($autumn_tm2), 7200, 'DST Start of overlap (ambiguous)');
    is($tz->offset_for_local_datetime($autumn_tm3), 7200, 'DST Middle of overlap (ambiguous)');
    is($tz->offset_for_local_datetime($autumn_tm4), 7200, 'DST End of overlap (ambiguous)');
    is($tz->offset_for_local_datetime($autumn_tm5), 3600, 'DST After overlap (CET)');

    is($tz->offset_for_local_datetime($autumn_tm2, 1), 7200, 'DST ambiguous: fold 1');    # Fold 1: The "First" 02:30 AM (Daylight Time / CEST)
    is($tz->offset_for_local_datetime($autumn_tm2, 0), 3600, 'DST ambiguous: fold 0');    # Fold 0: The "Last" 02:30 AM (Standard Time / CET)
};

done_testing();

__END__
