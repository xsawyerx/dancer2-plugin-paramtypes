#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'tests' => 2;
use Test::Memory::Cycle;

use lib 'lib';

## no critic qw(Subroutines::ProhibitCallsToUndeclaredSubs)

package MyApp {
    use Dancer2;
    use Dancer2::Plugin::ParamTypes;

    get '/' => with_types [ (
        {
            'name'       => 'id',
            'source'     => 'query',
            'type'       => 'positive_int',
            'on_invalid' => 'error',
        },
    ) ] => sub {1};
}

my $app    = MyApp->to_app;
my $runner = Dancer2->runner;

memory_cycle_ok( $app, 'App has no memory cycles' );
memory_cycle_ok( $runner,
    'Runner has no memory cycles' );
