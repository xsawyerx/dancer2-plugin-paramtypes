#!/usr/bin/perl
use strict;
use warnings;
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

        {
            'name'   => 'name',
            'source' => 'route',
            'type'   => 'positive_int',
            'on_invalid' => 'warn',
        },
    ) ] => sub {
        "HELLO\n";
    };
}

MyApp->to_app;
