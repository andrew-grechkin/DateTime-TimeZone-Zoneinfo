@dist:
    ./Build.PL
    ./Build dist

@clean:
    ./Build clean

@test:
    prove -r t/
