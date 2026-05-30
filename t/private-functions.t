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

tests '_parse_chars' => sub {
    my $sub = $CLASS->can('_parse_chars');
    is($sub->("GMT\0"), {0 => 'GMT'}, 'Parses one item string');
    is(
        $sub->("LMT\0BMT\0CET\0CEST\0"),
        {0 => 'LMT', 4 => 'BMT', 8 => 'CET', 12 => 'CEST'},
        'Parses multiple items string',
    );
};

done_testing();
