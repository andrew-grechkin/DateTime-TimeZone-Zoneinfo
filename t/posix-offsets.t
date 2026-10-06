#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Test2::V0;
use Test2::Tools::Spec;

use Time::Moment                        qw();
use DateTime::TimeZone::Zoneinfo::POSIX qw();

sub test_tz($recipe, $expected_std, $expected_dst, $label) {
    my $tz = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => $recipe);

    # Months that are definitely standard or definitely DST under standard rules
    my $tm_jan = Time::Moment->from_string('2024-01-15T12:00:00Z');
    my $tm_jun = Time::Moment->from_string('2024-06-15T12:00:00Z');

    is($tz->offset_for_datetime($tm_jan), $expected_std, "$label (Standard month) for $recipe");
    if (defined $expected_dst) {
        is($tz->offset_for_datetime($tm_jun), $expected_dst, "$label (DST month) for $recipe");
    }
}

tests 'Sign Inversion (West is Positive)' => sub {
    test_tz('EST5',                   -18_000, undef,   'EST5');               # -5h
    test_tz('EET-2',                   7200,   undef,   'EET-2');              # +2h
    test_tz('MST7MDT,M3.2.0,M11.1.0', -25_200, -21_600, 'MST7MDT');            # Std -7h, DST -6h
};

tests 'Complex Offsets' => sub {
    test_tz('NST3:30NDT,M3.2.0,M11.1.0', -12_600, -9000, 'Newfoundland');
    test_tz('TEST1:02:03',               -3723,   undef, 'Seconds support');
};

tests 'Zero Offsets' => sub {
    test_tz('GMT0',  0, undef, 'GMT0');
    test_tz('UTC-0', 0, undef, 'UTC-0');
};

tests 'Maximum Offsets (24h)' => sub {
    test_tz('MAX24',  -86_400, undef, 'MAX24');
    test_tz('MIN-24',  86_400, undef, 'MIN-24');
};

tests 'Bracketed/quoted abbreviations' => sub {
    my $tz = DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => '<+04>-4');
    my $tm = Time::Moment->from_string('2024-01-15T12:00:00Z');
    is($tz->offset_for_datetime($tm),     14_400, 'Bracketed std abbreviation offset');
    is($tz->short_name_for_datetime($tm), '+04',  'Bracketed std abbreviation keeps sign, drops <>');

    test_tz('<-05>5<-04>,M3.2.0,M11.1.0', -18_000, -14_400, 'Bracketed std and dst abbreviations');
};

tests 'Invalid recipes croak' => sub {
    like(
        dies {DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'garbage!!')},
        qr/Invalid POSIX TZ recipe: garbage!!/,
        'Unparseable recipe',
    );
    like(
        dies {DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'EST')},
        qr/Invalid POSIX TZ recipe: EST/,
        'Std abbreviation without an offset',
    );
    like(
        dies {DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'EST1:2')},
        qr/Invalid POSIX TZ recipe: EST1:2/,
        'Offset with a non-two-digit minutes field',
    );
    like(
        dies {DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'EST1:99')},
        qr/Invalid offset: 1:99/,
        'Offset with an out-of-range minutes field',
    );
    like(
        dies {DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'EST1:00:99')},
        qr/Invalid offset: 1:00:99/,
        'Offset with an out-of-range seconds field',
    );
    like(
        dies {DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'EST25')},
        qr/Invalid offset: 25/,
        'Std offset beyond 24h',
    );
    like(
        dies {DateTime::TimeZone::Zoneinfo::POSIX->new(recipe => 'STD0DST,M3.2.0/48,M11.1.0')},
        qr/Invalid offset: 48/,
        'Transition time beyond 24h is rejected under classic posix system',
    );
};

done_testing();

__END__
