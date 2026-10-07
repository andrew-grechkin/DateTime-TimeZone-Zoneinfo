# build a release tarball
dist:
    #!/usr/bin/env -S bash -Eeuo pipefail
    export PERL_JSON_BACKEND="JSON::PP"
    ./Build.PL
    ./Build dist

# remove build artifacts
@clean:
    ./Build clean
    git clean -Xdf

# run the test suite
@test:
    prove -r t/

# lint lib/ and t/ with perlcritic
critic:
    #!/usr/bin/env -S bash -Eeuo pipefail
    perlcritic lib/ t/ 2> >(perl -ne 'print unless m/^Policy ".*" is not installed/' >&2)

# reformat lib/ and t/ with perltidy
fix:
    #!/usr/bin/env -S bash -Eeuo pipefail
    shopt -s globstar
    perltidy -b -bext='/' -se Build.PL **/*.pm **/*.t

# manually open and parse every zoneinfo file on this system (binary + POSIX footer)
@test-system-zoneinfo:
    perl -Ilib t/manual-system-zoneinfo.pl
