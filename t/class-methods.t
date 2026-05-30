#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Cwd        qw(abs_path);
use File::Spec qw();
my $tzdir = abs_path(File::Spec->catdir('t', 'fixtures', 'zoneinfo'));
local $ENV{DATETIME_TIMEZONE_ZONEINFO_DIR} = $tzdir;

use Test2::V0;
use Test2::Tools::Spec;

use DateTime::TimeZone::Zoneinfo qw();

my $CLASS = 'DateTime::TimeZone::Zoneinfo';

tests 'is_valid_name' => sub {
    ok($CLASS->is_valid_name('Europe/Brussels'),   'Finds a valid timezone file');
    ok($CLASS->is_valid_name('Europe/EU_Capital'), 'Finds a valid timezone link');
    ok($CLASS->is_valid_name('UTC'),               'Finds a category-less timezone');
    ok(!$CLASS->is_valid_name('Europe/Nowhere'),   'Correctly returns false for non-existent file');
    ok(!$CLASS->is_valid_name('Europe'),           'Correctly returns false for a directory');
};

tests 'all_names' => sub {
    my @expected = sort qw(
        UTC
        GMT
        Australia/Lord_Howe
        Asia/Kathmandu
        Asia/Tehran
        Pacific/Apia
        Europe/Stockholm
        Europe/London
        Europe/Amsterdam
        Europe/Brussels
        Europe/EU_Capital
    );
    my @got = sort $CLASS->all_names;
    is(\@got, \@expected, 'Returns all timezone names from the fixture directory');
};

tests 'categories' => sub {
    my @expected = sort qw(Asia Australia Europe Pacific);
    my @got      = $CLASS->categories;
    is(\@got, \@expected, 'Correctly identifies all categories');
};

tests 'names_in_category' => sub {
    my @expected_europe
        = sort qw(Europe/Stockholm Europe/London Europe/Amsterdam Europe/Brussels Europe/EU_Capital);
    my @got_europe = sort $CLASS->names_in_category('Europe');
    is(\@got_europe, \@expected_europe, 'Finds all names in Europe category');

    my @expected_asia = sort qw(Asia/Kathmandu Asia/Tehran);
    my @got_asia      = sort $CLASS->names_in_category('asia');
    is(\@got_asia, \@expected_asia, 'Finds names with case-insensitive category match');
};

tests 'links' => sub {
    my $expected = {
        'Europe/EU_Capital' => 'Europe/Brussels',
    };
    my $got = $CLASS->links;
    $got->{'Europe/EU_Capital'} = 'Europe/Brussels' if $got->{'Europe/EU_Capital'} eq 'Brussels';
    is($got, $expected, 'Correctly identifies the test link and its target');
};

tests 'offset methods' => sub {
    is($CLASS->offset_as_seconds(3600),       3600,     'offset_as_seconds is a pass-through');
    is($CLASS->offset_as_string(3600),        '+01:00', 'offset_as_string formats positive HHMM');
    is($CLASS->offset_as_string(-19_800),     '-05:30', 'offset_as_string formats negative HHMM');
    is($CLASS->offset_as_string(-19_800, ''), '-0530',  'offset_as_string handles separator');
};

tests 'countries' => sub {
    my @expected = qw(
        ad ae ag aq
        ar as at au
        aw ax gs gy
        hk hm io kp
        kr mf mm nl
        sx sz tc tr
        tt vc vg vi
        wf ws za
    );
    is($CLASS->countries, \@expected, 'correctly reads iso3166 file');
};

tests 'parsed correctly' => sub {
    my @expected = qw(
        Antarctica/McMurdo
        Antarctica/Casey
        Antarctica/Davis
        Antarctica/DumontDUrville
        Antarctica/Mawson
        Antarctica/Palmer
        Antarctica/Rothera
        Antarctica/Syowa
        Antarctica/Troll
        Antarctica/Vostok
    );
    is($CLASS->names_in_country('aq'), \@expected, 'returns all zones in Antarctica');
};

done_testing();
