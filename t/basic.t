#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'tests' => 3;
use Plack::Test;
use HTTP::Request::Common;

{
    package MyApp;
    use Dancer2;
    use Dancer2::Plugin::ParamTypes;

    register_type_check(
        'Int' => sub { Scalar::Util::looks_like_number( $_[0] ) } );

    get '/route/:id' => with_types [
        [ 'route', 'id',  'Int' ],
    ] => sub { return 'route'; };

    get '/query' => with_types [
        [ 'query', 'id', 'Int' ],
    ] => sub { return 'query'; };

    post '/body' => with_types [
        [ 'body', 'id', 'Int' ],
    ] => sub { return 'body' };
}

my $test = Plack::Test->create( MyApp->to_app );

sub successful_test {
    my ( $request, $source ) = @_;
    my $response = $test->request($request);
    ok( $response->is_success, "$source succeeded" );
    is( $response->content, $source, "$source matched and run" );
}

sub missing_test {
    my ( $request, $source, $param ) = @_;
    my $response = $test->request($request);
    ok( !$response->is_success, "$source failed with missing parameter" );
    like(
        $response->content,
        qr{\QMissing $source parameter: $param\E},
        "Correct error message for $source"
    );
}

sub failing_test {
    my ( $request, $source, $param, $type ) = @_;
    my $response = $test->request($request);
    ok( !$response->is_success, "$source failed with bad parameter value" );
    like(
        $response->content,
        qr{\Q$source parameter $param must be $type\E},
        "Correct error message for $source"
    );
}

subtest 'Correctly handled proper arguments' => sub {
    successful_test( GET('/route/30'),    'route' );
    successful_test( GET('/query?id=30'), 'query' );
    successful_test( GET('/query?id=30&id=4'), 'query' );
    successful_test( POST( '/body', 'Content' => 'id=30' ), 'body' );
    successful_test( POST( '/body', 'Content' => 'id=30&id=77' ), 'body' );
};

subtest 'Failing missing arguments' => sub {
    missing_test( GET('/query'), 'query', 'id' );
    missing_test( POST('/body'), 'body', 'id' );
};

subtest 'Failing incorrect arguments' => sub {
    failing_test( GET('/route/k'), 'route', 'id', 'Int', );
    failing_test( GET('/query?id=k'), 'query', 'id', 'Int', );
    failing_test( POST( '/body', 'Content' => 'id=k' ), 'body', 'id', 'Int' );
};
