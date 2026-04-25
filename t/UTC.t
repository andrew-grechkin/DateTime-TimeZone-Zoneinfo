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

tests 'UTC Stability' => sub {
    my $tz = timezone('UTC');

    is($tz->name,                                         'UTC', 'Name is correct');
    is($tz->offset_for_local_datetime(Time::Moment->now), 0,     'UTC offset is always 0');
    ok(!$tz->has_dsts_changes, 'UTC has no DST changes');

    # Test a historical date to ensure -Inf transition works
    my $old_tm = Time::Moment->from_string('1900-01-01T00:00:00Z');
    is($tz->offset_for_local_datetime($old_tm), 0, 'Historical UTC is 0');
};

tests 'GMT Stability' => sub {
    my $tz = timezone('GMT');

    is($tz->name,                                         'GMT', 'Name is correct');
    is($tz->offset_for_local_datetime(Time::Moment->now), 0,     'GMT offset is always 0');
    ok(!$tz->has_dsts_changes, 'GMT has no DST changes');

    # Test a historical date to ensure -Inf transition works
    my $old_tm = Time::Moment->from_string('1900-01-01T00:00:00Z');
    is($tz->offset_for_local_datetime($old_tm), 0, 'Historical GMT is 0');
};

done_testing();

__END__
