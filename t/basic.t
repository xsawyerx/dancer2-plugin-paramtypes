#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'tests' => 4;
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

    register_type_response(
        'warn' => sub {
            my ( $app, $type_details ) = @_;
            printf STDERR 'Failed test for "%s" with "%s"',
                @{$type_details}[ 1, 2 ];
        }
    );

    register_type_response(
        'error' => sub {
            my ( $app, $type_details ) = @_;
            my $name = $type_details->[1];
            $app->response->status(500);
            $app->response->content("Type check failed for: $name");
        }
    );

    get '/:num' => with_types [
        [ 'query', 'id',  'positive_int', 'error' ],
        [ 'route', 'num', 'positive_int', 'error' ],

        'optional' => [ 'query', 'name', 'int', 'error' ],
    ] => sub {
        return 'hello';
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
    is( $response->content, 'Type check failed for: id', 'Correct output' );
};

subtest 'Failing mandatory arguments' => sub {
    my $response = $test->request( GET '/not_an_int?id=10' );
    ok( !$response->is_success, 'Error response' );
    is( $response->content, 'Type check failed for: num', 'Correct output' );
};

subtest 'Optional arguments' => sub {
    my $response = $test->request( GET '/40?id=20&name=hello' );
    ok( !$response->is_success, 'Error response' );
    is( $response->content, 'Type check failed for: name', 'Correct output' );
};
