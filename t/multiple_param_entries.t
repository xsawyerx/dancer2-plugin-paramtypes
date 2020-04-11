#!/usr/bin/perl

use lib '.';
use strict;
use warnings;

use HTTP::Request::Common;
use Plack::Test;
use Test::More 'tests' => 3;
use t::lib::Utils;

{

    package MyApp;
    use Dancer2;
    use Dancer2::Plugin::ParamTypes;

    register_type_check( NotEmpty => sub { $_[0] } );
    register_type_check( Int      => sub { Scalar::Util::looks_like_number( $_[0] ) } );

    get '/query' => with_types [ [ 'query', 'id', 'NotEmpty' ], [ 'query', 'id', 'Int' ] ] => sub {
        return 'query';
    };
}

my $test = Plack::Test->create( MyApp->to_app );

subtest 'Correctly handled proper parameters' => sub {
    successful_test( $test, GET('/query?id=4'), 'query' );
};

subtest 'Failing missing parameters' => sub {
    missing_test( $test, GET('/query'), 'query', 'id' );
};

subtest 'Failing incorrect parameters' => sub {
    failing_test( $test, GET('/query?id='),  'query', 'id', 'NotEmpty', );
    failing_test( $test, GET('/query?id=k'), 'query', 'id', 'Int', );
};
