# DateTime::TimeZone::Zoneinfo

## ABSTRACT

A compact and fast loader for IANA Zoneinfo (TZif) files that provides a `DateTime::TimeZone` compatible interface.

## SYNOPSIS

```perl
  use DateTime::TimeZone::Zoneinfo qw(timezone);

  my $tz1 = timezone('Europe/Amsterdam');                              # Get a timezone object
  my $tz2 = DateTime::TimeZone::Zoneinfo->new(name => 'Pacific/Apia'); # Or use constructor directly

  # Use it with any DateTime-compatible library, like Time::Moment
  use Time::Moment;

  my $tm = Time::Moment->now;
  say $tz1->offset_for_datetime($tm);
```

## DESCRIPTION

This module provides a direct and efficient way to load and interact with the binary IANA Zoneinfo (also known as Olson)
files commonly found on Unix-like systems (e.g., in `/usr/share/zoneinfo`). It parses the raw TZif format (versions 1,
2, and 3), including historical transitions and future DST rules defined by POSIX-style TZ strings. It doesn't hard-code
any timezone data, relying strictly on the timezone database provided by the operating system.

It is designed to be compatible (to some extent) with the `DateTime::TimeZone` interface, allowing it to serve
as a drop-in timezone providing backend for modules like `Time::Moment` or `DateTime`.

## MOTIVATION

The primary goal is to offer a lightweight and fast alternative to other `DateTime::TimeZone` providers, especially for
applications that require quick startup or work in memory-constrained environments. It avoids heavy dependency chains
and complex configuration, acting as a direct interface to the system's own timezone data.

While `DateTime` is a cornerstone of the Perl ecosystem, its rich feature set and large dependency
tree can be overkill for applications where performance and a small memory footprint are critical.
[Time::Moment](https://github.com/chansen/p5-time-moment), an excellent module by Christian Hansen
(which in my opinion is both subjectively and objectively better than `DateTime`) is a modern,
immutable, and significantly faster alternative for handling timestamps.

However, `Time::Moment` itself does not handle the complexities of timezone rules;
it requires a [`DateTime::TimeZone`-compatible object](https://metacpan.org/dist/Time-Moment/view/lib/Time/Moment.pod#TIME-ZONES)
to resolve offsets. This module was created to bridge that gap. It provides a lean, fast, and beautiful
timezone provider with no dependencies, allowing developers to leverage the speed of `Time::Moment`
without pulling the entire `DateTime` ecosystem in.
It is the ideal companion for high-performance, modern Perl applications.

The second reason is a love for modern Perl itself. With the efforts of many people
(huge thanks to many contributors and especially [Paul Evans](https://github.com/leonerd)),
the language becomes more expressive and powerful every year. This module is an attempt to showcase
that beauty, proving that when written with modern features and a clean aesthetic in mind,
Perl is an elegant and powerful language.

## SEE ALSO

Several other modules exist for handling timezone information, each with its own strengths.
These modules are well-established and battle-tested options within the Perl ecosystem.
`DateTime::TimeZone::Zoneinfo` provides a more lightweight, performance-oriented alternative
with fewer dependencies.

* [**DateTime::TimeZone**](https://metacpan.org/pod/DateTime::TimeZone)
  The standard-bearer for timezone handling in the `DateTime` ecosystem.
  It is incredibly robust and feature-rich, supporting a wide variety of sources for timezone data.

* [**DateTime::TimeZone::Tzfile**](https://metacpan.org/pod/DateTime::TimeZone::Tzfile)
  A pure-Perl parser for TZif files, serving as a valuable reference.
  This module aims for higher performance by being a more direct interface to the system's compiled zoneinfo files.

* [**DateTime::Lite**](https://metacpan.org/pod/DateTime::Lite)
    A lighter-weight, low-dependency alternative to the full `DateTime` module, which bundles its own timezone solution.

## AUTHOR

- Andrew Grechkin

# LICENSE

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
See the `LICENSE` file for details.
