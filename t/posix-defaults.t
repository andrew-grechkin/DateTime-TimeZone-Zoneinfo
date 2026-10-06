#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Test2::V0;
use Test2::Tools::Spec;

use Time::Moment                        qw();
use DateTime::TimeZone::Zoneinfo::POSIX qw();

tests 'Ruleless DST (Legacy US 1976)' => sub {
    # Missing rules fall back to the US 1976 rules:
    # Start: last Sunday of April (M4.5.0); End: last Sunday of October (M10.5.0)
    my $recipe = 'EST5EDT';
    my $tz     = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => $recipe);

    # 2005-04-24 was the last Sunday; 02:00 local (EST) -> 07:00 UTC
    my $tm = Time::Moment->from_string('2005-04-24T06:59:59Z');
    is($tz->offset_for_datetime($tm),                  -18_000, 'Before legacy start');
    is($tz->offset_for_datetime($tm->plus_seconds(1)), -14_400, 'After legacy start');

    # 2005-10-30 was the last Sunday; 02:00 local (EDT) -> 06:00 UTC
    $tm = Time::Moment->from_string('2005-10-30T05:59:59Z');
    is($tz->offset_for_datetime($tm),                  -14_400, 'Before legacy end');
    is($tz->offset_for_datetime($tm->plus_seconds(1)), -18_000, 'After legacy end');
};

tests 'Implicit DST offset (+1 hour)' => sub {
    # A missing DST offset defaults to Standard + 1 hour
    my $recipe = 'CET-1CEST,M3.5.0,M10.5.0';
    my $tz     = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => $recipe);

    # CET is +1h (3600s), so CEST should be +2h (7200s)
    my $tm = Time::Moment->from_string('2024-06-01T12:00:00Z');
    is($tz->offset_for_datetime($tm), 7200, 'Implicit +1h DST offset');
};

tests 'Perpetual DST (via footer style, tzfile3)' => sub {
    # Some tzfile footers mean DST all year: Start J0/0, End J365/25
    my $recipe = 'AAA-2BBB,J0/0,J365/25';
    my $tz     = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => $recipe, system => 'tzfile3');

    is($tz->offset_for_datetime(Time::Moment->from_string('2023-01-01T00:00:00Z')),
        10_800, 'In DST at start of year');
    is($tz->offset_for_datetime(Time::Moment->from_string('2023-12-31T23:59:59Z')), 10_800,
        'In DST at end of year');
};

tests 'is_dst_for_datetime and short_name_for_datetime' => sub {
    my $recipe = 'EST5EDT,M3.2.0,M11.1.0';
    my $tz     = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => $recipe);

    my $tm_std = Time::Moment->from_string('2024-01-15T12:00:00Z');
    my $tm_dst = Time::Moment->from_string('2024-06-15T12:00:00Z');

    ok(!$tz->is_dst_for_datetime($tm_std), 'January is not DST');
    ok($tz->is_dst_for_datetime($tm_dst),  'June is DST');

    is($tz->short_name_for_datetime($tm_std), 'EST', 'January abbreviation is std');
    is($tz->short_name_for_datetime($tm_dst), 'EDT', 'June abbreviation is dst');

    # A recipe with no DST rule is never DST and always reports the std abbreviation.
    my $tz_no_dst = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'EST5');
    ok(!$tz_no_dst->is_dst_for_datetime($tm_dst), 'No-DST recipe is never DST');
    is($tz_no_dst->short_name_for_datetime($tm_dst), 'EST', 'No-DST recipe always uses std abbreviation');
};

done_testing();

__END__
