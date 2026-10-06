#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Test2::V0;
use Test2::Tools::Spec;

use Time::Moment                        qw();
use DateTime::TimeZone::Zoneinfo::POSIX qw();

sub test_rule($recipe, $timespec, $expected_offset, $label) {
    my $tz = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => $recipe);
    my $tm = Time::Moment->from_string($timespec);
    is($tz->offset_for_datetime($tm), $expected_offset, "$label ($recipe at $timespec)");
}

tests 'Jn (Julian Day, no Feb 29)' => sub {
    # J59 is Feb 28, J60 is March 1
    my $recipe = 'STD0DST,J59,J60';

    # Non-leap year (2023)
    test_rule($recipe, '2023-02-28T01:59:59Z', 0,    'Before start');
    test_rule($recipe, '2023-02-28T02:00:00Z', 3600, 'In DST (Feb 28)');
    test_rule($recipe, '2023-03-01T00:59:59Z', 3600, 'In DST (March 1 before transition)');
    test_rule($recipe, '2023-03-01T01:00:00Z', 0,    'After end (March 1 at transition)');

    # Leap year (2024): J60 is still March 1
    test_rule($recipe, '2024-02-28T02:00:00Z', 3600, 'In DST (Feb 28)');
    test_rule($recipe, '2024-02-29T12:00:00Z', 3600, 'In DST (Feb 29 - leap day skipped by rule J)');
    test_rule($recipe, '2024-03-01T00:59:59Z', 3600, 'In DST (March 1)');
    test_rule($recipe, '2024-03-01T01:00:00Z', 0,    'After end');
};

tests 'Sunday (0) transitions' => sub {
    my $recipe = 'STD0DST,M3.1.0,M12.5.0';
    test_rule($recipe, '2024-03-03T01:59:59Z', 0,    'Before 1st Sunday');
    test_rule($recipe, '2024-03-03T02:00:00Z', 3600, 'At 1st Sunday');
};

tests 'Week 5 is last occurrence' => sub {
    my $recipe = 'STD0DST,M2.5.2,M12.3.1';
    test_rule($recipe, '2023-02-28T01:59:59Z', 0,    'Before last Tuesday (Feb 28)');
    test_rule($recipe, '2023-02-28T02:00:00Z', 3600, 'At last Tuesday (Feb 28)');
};

tests 'Year-end boundaries' => sub {
    my $recipe = 'STD0DST,J1,J365/23';
    test_rule($recipe, '2023-12-31T21:59:59Z', 3600, 'Still in DST near year end');
    test_rule($recipe, '2023-12-31T22:00:00Z', 0,    'Exit DST at year end');
};

tests 'n (Julian Day, counts Feb 29)' => sub {
    my $recipe = 'STD0DST,58,59';
    test_rule($recipe, '2023-02-28T02:00:00Z', 3600, 'In DST (Feb 28)');
    test_rule($recipe, '2023-03-01T00:59:59Z', 3600, 'In DST (March 1)');
    test_rule($recipe, '2023-03-01T01:00:00Z', 0,    'After end');
    test_rule($recipe, '2024-02-28T02:00:00Z', 3600, 'In DST (Feb 28)');
    test_rule($recipe, '2024-02-29T00:59:59Z', 3600, 'In DST (Feb 29)');
    test_rule($recipe, '2024-02-29T01:00:00Z', 0,    'After end (Feb 29)');
};

tests 'Mm.w.d (Month.Week.Day)' => sub {
    my $recipe = 'EST5EDT,M3.2.0,M11.1.0';
    test_rule($recipe, '2024-03-10T06:59:59Z', -18_000, 'Before start');
    test_rule($recipe, '2024-03-10T07:00:00Z', -14_400, 'Start DST');

    my $last_sun = 'CET-1CEST,M3.5.0,M10.5.0';
    test_rule($last_sun, '2024-03-31T00:59:59Z', 3600, 'Before last Sunday');
    test_rule($last_sun, '2024-03-31T01:00:00Z', 7200, 'Start on last Sunday');
};

tests 'Southern hemisphere (DST wraps the year boundary)' => sub {
    # Sydney: DST (start < end would be Northern); here end < start, so DST
    # covers Jan, wraps across the New Year, and standard time sits mid-year.
    my $recipe = 'AEST-10AEDT,M10.1.0,M4.1.0/3';

    test_rule($recipe, '2023-01-15T12:00:00Z', 39_600, 'Mid-January is DST');
    test_rule($recipe, '2023-07-15T12:00:00Z', 36_000, 'Mid-July is standard time');

    # 2023-04-02 is the 1st Sunday of April; end transition at 03:00 local (DST, +11) -> 2023-04-01T16:00 UTC
    test_rule($recipe, '2023-04-01T15:59:59Z', 39_600, 'Before DST end');
    test_rule($recipe, '2023-04-01T16:00:00Z', 36_000, 'After DST end');

    # 2023-10-01 is the 1st Sunday of October; start transition at 02:00 local (STD, +10) -> 16:00 UTC
    test_rule($recipe, '2023-09-30T15:59:59Z', 36_000, 'Before DST start');
    test_rule($recipe, '2023-09-30T16:00:00Z', 39_600, 'After DST start');
};

done_testing();

__END__
