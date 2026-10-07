#!/usr/bin/env perl

use v5.40;

use Module::Build;

Module::Build->new(
    dist_abstract  => 'A compact loader for IANA Zoneinfo files providing a standard DateTime::TimeZone interface',
    dist_author    => 'Andrew Grechkin',
    license        => 'perl',
    module_name    => 'DateTime::TimeZone::Zoneinfo',
    build_requires => {
        'perl' => '5.040',
    },
    configure_requires => {
        'perl' => '5.040',
    },
    test_requires => {
        'Time::Moment' => 0,
        'perl'         => '5.040',
    },
    requires => {
        'perl' => '5.040',
    },
    meta_merge => {
        resources => {
            homepage   => 'https://github.com/andrew-grechkin/DateTime-TimeZone-Zoneinfo',
            bugtracker => {
                mailto => 'andrew.grechkin@gmail.com',
                web    => 'https://github.com/andrew-grechkin/DateTime-TimeZone-Zoneinfo/issues',
            },
            repository => {
                type => 'git',
                url  => 'https://github.com/andrew-grechkin/DateTime-TimeZone-Zoneinfo.git',
                web  => 'https://github.com/andrew-grechkin/DateTime-TimeZone-Zoneinfo',
            },
        },
    },
)->create_build_script;

exit 0;
