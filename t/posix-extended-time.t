#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Test2::V0;
use Test2::Tools::Spec;

use Time::Moment                        qw();
use DateTime::TimeZone::Zoneinfo::POSIX qw();

sub test_rule($recipe, $timespec, $expected_offset, $label, $system = 'posix') {
    my $tz = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => $recipe, system => $system);
    my $tm = Time::Moment->from_string($timespec);
    is($tz->offset_for_datetime($tm), $expected_offset, "$label ($recipe at $timespec)");
}

tests 'Default transition time (02:00:00)' => sub {
    my $recipe = 'STD0DST,J1,J365';
    test_rule($recipe, '2023-01-01T01:59:59Z', 0,    'Before default start');
    test_rule($recipe, '2023-01-01T02:00:00Z', 3600, 'At default start');
};

tests 'POSIX 24:00 (next day)' => sub {
    # 24:00 on J1 -> Jan 2 00:00
    my $recipe = 'STD0DST,J1/24,J365';
    test_rule($recipe, '2023-01-01T23:59:59Z', 0,    'Before 24:00');
    test_rule($recipe, '2023-01-02T00:00:00Z', 3600, 'At 24:00');
};

tests 'Transition context offsets' => sub {
    # DST start is relative to the standard offset, DST end relative to the DST offset
    my $recipe = 'STD5DST4,M3.2.0/02,M11.1.0/02';

    # 2024-03-10 02:00 local (STD) -> 07:00 UTC
    test_rule($recipe, '2024-03-10T06:59:59Z', -18_000, 'Before DST start');
    test_rule($recipe, '2024-03-10T07:00:00Z', -14_400, 'At DST start');

    # 2024-11-03 02:00 local (DST) -> 06:00 UTC
    test_rule($recipe, '2024-11-03T05:59:59Z', -14_400, 'Before DST end');
    test_rule($recipe, '2024-11-03T06:00:00Z', -18_000, 'At DST end');
};

tests 'Negative times (tzfile3)' => sub {
    # /-01:00:00 means 1 hour before the start of the day; J2/-01 -> Jan 1 at 23:00
    my $recipe = 'STD0DST,J2/-01,J365';
    test_rule($recipe, '2023-01-01T22:59:59Z', 0,    'Before negative start');
    test_rule($recipe, '2023-01-01T23:00:00Z', 3600, 'At negative start');
};

tests 'Multi-day rollover (> 24h, tzfile3)' => sub {
    # /48:00:00 means 2 days later; J1/48 -> Jan 3 at 00:00
    my $recipe = 'STD0DST,J1/48,J365';
    test_rule($recipe, '2023-01-02T23:59:59Z', 0,    'Before 48h start', 'tzfile3');
    test_rule($recipe, '2023-01-03T00:00:00Z', 3600, 'At 48h start',     'tzfile3');
};

done_testing();

__END__
