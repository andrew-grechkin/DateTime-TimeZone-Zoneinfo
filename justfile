# build a release tarball
@dist:
    ./Build.PL
    ./Build dist

# remove build artifacts
@clean:
    ./Build clean

# run the test suite
@test:
    prove -r t/

# lint lib/ and t/ with perlcritic
@critic:
    perlcritic lib/ t/

# reformat lib/ and t/ with perltidy
fix:
    #!/usr/bin/env -S bash -Eeuo pipefail
    shopt -s globstar
    perltidy -b -bext='/' -se **/*.pm **/*.t

# manually open and parse every zoneinfo file on this system (binary + POSIX footer)
@test-system-zoneinfo:
    perl -Ilib t/manual-system-zoneinfo.pl
