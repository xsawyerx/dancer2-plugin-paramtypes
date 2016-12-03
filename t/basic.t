#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'tests' => 5;
use Plack::Test;
use HTTP::Request::Common;

## no critic qw(Subroutines::ProhibitCallsToUndeclaredSubs)

{
    package MyApp;
    use Dancer2;
    use Dancer2::Plugin::ParamTypes;

    register_type_check(
        'positive_int' => sub {
            return Scalar::Util::looks_like_number( $_[0] ) && $_[0] >= 0;
        }
    );

    register_type_check(
        'int' => sub { Scalar::Util::looks_like_number( $_[0] ) } );

    register_type_action(
        'warn' => sub {
            my ( $app, $type_details ) = @_;
            printf STDERR 'Failed test for "%s" with "%s"',
                @{$type_details}[ 1, 2 ];
        }
    );

    register_type_action(
        'error' => sub {
            my $type_details = shift;
            my $name = $type_details->{'name'};
            send_error( "Type check failed for: $name", 500 );
        }
    );

    get '/:num' => with_types [
        [ 'query', 'id',  'positive_int', 'error' ],
        [ 'route', 'num', 'positive_int', 'error' ],

        'optional' => [ 'query', 'name', 'int', 'error' ],
    ] => sub {
        return 'hello';
    };

    post '/upload' => with_types [
        [ ['query', 'body'], 'id',  'positive_int', 'error' ],
    ] => sub {
        if ( request->method eq 'GET' ) {
            return query_parameters->{'id'};
        } else {
            return body_parameters->{'id'};
        }
    };
}

my $test = Plack::Test->create( MyApp->to_app );

# success
subtest 'Mandatory arguments' => sub {
    my $response = $test->request( GET '/30?id=10' );
    ok( $response->is_success, 'Successful response' );
    is( $response->content, 'hello', 'Correct output' );
};

subtest 'Missing mandatory arguments' => sub {
    my $response = $test->request( GET '/30' );
    ok( !$response->is_success, 'Error response' );
    like(
        $response->content,
        qr{Missing query parameter: id \(positive_int\)},
        'Correct output'
    );
};

subtest 'Failing mandatory arguments' => sub {
    my $response = $test->request( GET '/not_an_int?id=10' );
    ok( !$response->is_success, 'Error response' );
    like(
        $response->content,
        qr{Type check failed for: num},
        'Correct output'
    );
};

subtest 'Optional arguments' => sub {
    my $response = $test->request( GET '/40?id=20&name=hello' );
    ok( !$response->is_success, 'Error response' );
    like(
        $response->content,
        qr{Type check failed for: name},
        'Correct output'
    );
};

subtest 'Multiple source values' => sub {
    {
        my $response = $test->request( POST '/upload?filename=foo' );
        ok( $response->is_success, 'Successful response' );
        is( $response->content, 'foo', 'Correct output' );
    }

    {
        my $response = $test->request( POST '/upload', 'filename=bar' );
        ok( $response->is_success, 'Successful response' );
        is( $response->content, 'bar', 'Correct output' );
    }
};
