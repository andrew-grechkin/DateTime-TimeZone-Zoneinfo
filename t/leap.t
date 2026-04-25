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

## no critic [Subroutines::ProtectPrivateSubs]

tests 'Leap Second Stability (1998-1999)' => sub {
    my $tz = timezone('Europe/Amsterdam');

    # Right before the 1998 leap second
    my $tm_before = Time::Moment->from_string('1998-12-31T23:59:59Z');
    # Right after (start of 1999)
    my $tm_after = Time::Moment->from_string('1999-01-01T00:00:00Z');

    is($tz->offset_for_local_datetime($tm_before), 3600, 'Correct offset before leap second (CET)');
    is($tz->offset_for_local_datetime($tm_after),  3600, 'Correct offset after leap second (CET)');

    # Verification: Ensure the internal epoch jump is exactly 1 second in your math
    my $e_before = DateTime::TimeZone::Zoneinfo::_rd_local_to_epoch([$tm_before->local_rd_values], 3600);
    my $e_after  = DateTime::TimeZone::Zoneinfo::_rd_local_to_epoch([$tm_after->local_rd_values],  3600);
    is($e_after - $e_before, 1, 'Rata Die math treats leap second interval as 1 standard second');
};

done_testing();

__END__
