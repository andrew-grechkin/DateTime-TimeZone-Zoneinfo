#!/usr/bin/env perl

use v5.40;
use warnings qw(FATAL utf8);

use Time::Moment                 qw();
use DateTime::TimeZone::Zoneinfo qw();

# Non-tzfile metadata that some distros place inside the zoneinfo directory.
my %SKIP = map {($_ => 1)} qw(SECURITY iso3166.tab zone.tab zone1970.tab tzdata.zi leapseconds);

my @names = DateTime::TimeZone::Zoneinfo->all_names;
die "No zoneinfo files found under @{[DateTime::TimeZone::Zoneinfo->new(name => 'UTC')->dir]}\n" unless @names;

my $tm = Time::Moment->now_utc;
my $ok = 0;
my @failed;

for my $name (sort @names) {
    next if $SKIP{$name};
    next unless DateTime::TimeZone::Zoneinfo->is_valid_name($name);

    my $died = !eval {
        my $tz = DateTime::TimeZone::Zoneinfo->new(name => $name);

        # Exercise both the binary transition table and the POSIX footer recipe (if any).
        $tz->offset_for_datetime($tm);
        $tz->is_dst_for_datetime($tm);
        $tz->short_name_for_datetime($tm);

        1;
    };

    if ($died) {
        push @failed, "$name: $@";
    } else {
        $ok++;
    }
}

printf "%d/%d zoneinfo files parsed cleanly\n", $ok, $ok + @failed;

if (@failed) {
    say "\nFailures:";
    say "  $_" for @failed;
    exit 1;
}
