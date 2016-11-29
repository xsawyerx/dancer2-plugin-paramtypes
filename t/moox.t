#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'tests' => 5;
use Plack::Test;
use HTTP::Request::Common;

## no critic qw(Subroutines::ProhibitCallsToUndeclaredSubs)

my $doc;

{
    package MyApp;
    use Dancer2;
    use Dancer2::Plugin::ParamTypes;

    register_type_check(
        'Int' => sub {
            require MooX::Types::MooseLike::Base;

            eval { MooX::Types::MooseLike::Base::Int()->( $_[0] ); 1; }
                or return;

            return 1;
        }
    );

    register_type_response(
        'doc' => sub {
            $doc++;
            send_error('Whoohoo error!');
        },
    );

    get '/:id' => with_types [
        [ 'route', 'id', 'Int', 'doc' ],
    ] => sub {
        return 'hello';
    };

    get '/' => with_types [
        [ 'query', 'id', 'Int', 'doc' ],
    ] => sub {
        return 'OK';
    };
}

my $test = Plack::Test->create( MyApp->to_app );

subtest 'Success' => sub {
    my $response = $test->request( GET '/30' );
    ok( $response->is_success, 'Successful response' );
    is( $response->content, 'hello', 'Correct response' );
};

subtest 'Failure' => sub {
    my $response = $test->request( GET '/foo' );
    ok( !$response->is_success, 'Error response' );
    like( $response->content, qr/Whoohoo\serror!/, 'Correct output' );
    is( $doc, 1, 'Error tackled' );
};

subtest 'Single query search' => sub {
    my $response = $test->request( GET '/?id=30' );
    ok( $response->is_success, 'Successful response' );
    is( $response->content, 'OK', 'Correct response' );
};


subtest 'Multiple query search, success' => sub {
    my $response = $test->request( GET '/?id=30&id=40' );
    ok( $response->is_success, 'Successful response' );
    is( $response->content, 'OK', 'Correct response' );
};

subtest 'Multiple query search, failure' => sub {
    my $response = $test->request( GET '/?id=30&id=str' );
    ok( ! $response->is_success, 'Failed response' );
    like( $response->content, qr/Whoohoo error!/, 'Correct response' );
};
