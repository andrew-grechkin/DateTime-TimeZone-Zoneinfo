#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Cwd        qw(abs_path);
use File::Spec qw();
my $tzdir = abs_path(File::Spec->catdir('t', 'fixtures', 'zoneinfo'));
local $ENV{DATETIME_TIMEZONE_ZONEINFO_DIR} = $tzdir;

use Test2::V0;
use Test2::Tools::Spec;

use DateTime::TimeZone::Zoneinfo qw(timezone);

describe 'Local timezone detection' => sub {
    tests 'Handles leading colon in $ENV{TZ}' => sub {
        local $ENV{TZ} = ':Asia/Tehran';
        my $tz = timezone();
        is($tz->name, 'Asia/Tehran', "Support TZ=$ENV{TZ}");
    };

    tests 'Detects local timezone from $ENV{TZ} full path' => sub {
        local $ENV{TZ} = File::Spec->catfile($tzdir, 'Europe/Amsterdam');
        my $tz = timezone();
        is($tz->name, 'Europe/Amsterdam', "Support TZ=$ENV{TZ}");
    };

    tests 'Detects local timezone from $ENV{TZ} timezone name' => sub {
        local $ENV{TZ} = 'Europe/Brussels';
        my $tz = timezone();
        is($tz->name, 'Europe/Brussels', "Support TZ=$ENV{TZ}");
    };

    tests 'Works when name is "local"' => sub {
        local $ENV{TZ} = 'Europe/Brussels';
        my $tz = timezone('local');
        is($tz->name, 'Europe/Brussels', 'Name local initiates detection');
    };
};

done_testing();
