package Dancer2::Plugin::ParamTypes;
# ABSTRACT: Parameter type checking plugin for Dancer2

use strict;
use warnings;

use DDP;
use Carp ();
use Dancer2::Plugin;
use Scalar::Util ();

## no critic qw(Subroutines::ProhibitCallsToUndeclaredSubs)
plugin_keywords(qw<register_type_check register_type_response with_types>);

has 'type_checks' => (
    'is'      => 'ro',
    'default' => sub { +{} },
);

has 'type_responses' => (
    'is'      => 'ro',
    'default' => sub { +{} },
);

sub register_type_check {
    my ( $self, $name, $cb ) = @_;
    $self->type_checks->{$name} = $cb;
    return;
}

sub register_type_response {
    my ( $self, $name, $cb ) = @_;
    $self->type_responses->{$name} = $cb;
    return;
}

sub with_types {
    my ( $self, $full_type_details, $cb ) = @_;
    my %params_to_check;

    for ( my $idx = 0; $idx <= $#{$full_type_details}; $idx++ ) {
        my $item = $full_type_details->[$idx];
        my ( $is_optional, $type_details )
            = ref $item eq 'ARRAY' ? ( 0, $item )
            : $item eq 'optional'  ? ( 1, $full_type_details->[ ++$idx ] )
            : Carp::croak("Unsupported type option: $item");

        @{$type_details} == 4
            or Carp::croak('Please provide 4 elements for each type');

        my ( $source, $name, $type, $response ) = @{$type_details};

        $source eq 'route' || $source eq 'query' || $source eq 'body'
            or
            Carp::croak("Type $name provided from unknown source '$source'");

        defined $self->type_checks->{$type}
            or Carp::croak("Type $name provided unknown type '$type'");

        defined $self->type_responses->{$response}
            or
            Carp::croak("Type $name provided unknown response '$response'");

        $params_to_check{$source}{$name} = [ $is_optional, $type_details ];
    }

    # Couldn't prove yet that this is required, but it makes sense to me
    Scalar::Util::weaken( my $plugin = $self );
    #my $plugin = $self;

    return sub {
        my @route_args = @_;

        # Hash::MultiValue has "each" method which we could use to
        # traverse it in the opposite direction (for each parameter sent
        # we find the appropriate value and check it), but that could
        # possibly introduce an attack vector of sending a lot of
        # parameters to force longer loops. For now, the loop is based
        # on how many parameters to added to be checked, which is a known
        # set. (GET has a max limit, PUT/POST...?) -- SX

        foreach my $param_source (qw<route query body>) {
            # Only check if anything was supplied
            if ( $params_to_check{$param_source} ) {
                foreach my $param_name (
                    keys %{ $params_to_check{$param_source} } )
                {
                    my ( $is_optional, $type_details )
                        = @{ $params_to_check{$param_source}{$param_name} };

                    $plugin->run_check( $is_optional, $type_details );
                }
            }

        }

        $cb->(@route_args);
    };
}

sub run_check {
    my ( $self, $is_optional, $type_details ) = @_;

    my ( $source, $name, $type, $action ) = @{$type_details};

    my $app     = $self->app;
    my $request = $app->request;

    my $params
        = $source eq 'route' ? $request->route_parameters
        : $source eq 'query' ? $request->query_parameters
        :                      $request->body_parameters;

    # No parameter value, is this okay or not?
    if ( !exists $params->{$name} ) {
        # It's okay, ignore
        $is_optional
            and return 1;

        # Not okay, missing when it's required!
        $self->dsl->send_error(
            "Missing $source parameter $name ($type)",
            500,
        );

        return $self->type_responses->{'error'}->( $app, $type_details );
    }

    my @param_values = $params->get_all($name);
    my $check_cb     = $self->type_checks->{$type};

    foreach my $param_value (@param_values) {
        if ( ! $check_cb->($param_value) ) {
            my $response_cb
                = $self->type_responses->{$action};

            return $response_cb->( $app, $type_details );
        }
    }

    return;
}

1;

__END__

=head1 SYNOPSIS

    package MyApp;
    use Dancer2;
    use Dancer2::Plugin::ParamTypes;

    # First we define some type checks and type responses
    # Read below for these two methods, they are required
    register_type_check(...);
    register_type_response(...);

    # Now we can provide types
    get '/:num' => with_types [
        [ 'query', 'id',  'positive_int', 'error' ],
        [ 'route', 'num', 'positive_int', 'error' ],

        'optional' => [ 'query', 'name', 'int', 'error' ],
    ] => sub {
        my $id = query_parameters->{'id'};
        ...
    };

=head1 DESCRIPTION

This is a basic module that allows you to provide a stanza of parameter
type checks for your routes.

It supports all three possible sources (C<route>, C<query>, and
C<body>).

Currently it does not have any known types and actions on its own. You
you will need to write your own code to add them. The synopsis includes
an example on adding your own.

=head2 Methods

=head3 C<register_type_check>

First you must register a type check, allowing you to test stuff:

    register_type_check 'Int' => sub {
        return Scalar::Util::looks_like_number( $_[0] );
    };

=head3 C<register_type_response>

    register_type_response 'error' => sub {
        my ( $app, $type_details ) = @_;
        my ( $source, $name, $type, $action ) = @{$type_details};

        send_error("Type check failed for $source $name ($type)");
    }

=head3 C<with_types>

C<with_types> defines checks for parameters for a route request.

    get '/:name' => with_request [
        [ 'route', 'name', 'Str', 'error' ]
    ] => sub {
        ...
    };

=head2 Connecting existing type systems

Because each type check is a callback, you can connect these to other
type systems:

    register_type_check 'Str' => sub {
        require MooX::Types::MooseLike::Base;

        # This call will die when failing,
        # so we put it in an eval
        eval {
            MooX::Types::MooseLike::Base::Str->( $_[0] );
            1;
        } or return;

        return 1;
    };
