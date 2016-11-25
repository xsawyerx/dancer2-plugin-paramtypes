#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'tests' => 3;
use Test::Memory::Cycle;

use lib 'lib';

## no critic qw(Subroutines::ProhibitCallsToUndeclaredSubs)

package MyApp {
    use Dancer2;
    use Dancer2::Plugin::ParamTypes;

    get '/' => with_types [ [ 'query', 'id', 'positive_int', 'error' ], ] =>
        sub {1};
}

my $app    = MyApp->to_app;
my $runner = Dancer2->runner;

memory_cycle_ok( $runner, 'Runner has no memory cycles' );
memory_cycle_ok( $runner->apps->[0], 'App has no memory cycles' );
memory_cycle_ok( $app, 'App code has no memory cycles' );

