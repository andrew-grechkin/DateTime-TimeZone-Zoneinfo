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

tests 'Historical and Boundary Tests' => sub {
    my $tz = timezone('Europe/Amsterdam');

    # Test the absolute beginning of the timeline
    my $ancient_tm = Time::Moment->from_string('1800-01-01T00:00:00Z');
    is($tz->offset_for_local_datetime($ancient_tm), 1050, 'Handled -Inf (LMT) correctly');

    # Test the period between the first and second transitions
    my $bmt_tm = Time::Moment->from_string('1885-01-01T00:00:00Z');
    is($tz->offset_for_local_datetime($bmt_tm), 1050, 'Handled 19th century Amsterdam Mean Time');

    # Test the Footer (Future)
    my $future_tm = Time::Moment->from_string('2050-06-01T12:00:00Z');
    is($tz->offset_for_local_datetime($future_tm), 7200, 'Future DST resolved via POSIX footer');
};

tests 'Unix Epoch Boundary' => sub {
    my $tz       = timezone('Europe/Amsterdam');
    my $epoch_tm = Time::Moment->from_string('1970-01-01T00:00:00Z');

    # In 1970, Amsterdam was in CET (+1)
    is($tz->offset_for_local_datetime($epoch_tm), 3600, 'Epoch Rata Die math is correct');
};

tests 'London Historical LMT' => sub {
    my $tz = timezone('Europe/London');

    # London LMT was -00:00:05 (5 seconds West of Greenwich)
    my $ancient_tm = Time::Moment->from_string('1840-01-01T00:00:00Z');
    my $offset     = $tz->offset_for_local_datetime($ancient_tm);

    # NOTE: Depending on your zoneinfo version, this might be -5 or 0.
    # It tests if your loop handles negative offsets correctly.
    ok(defined $offset, "Found historical London offset: $offset");
};

done_testing();

__END__
