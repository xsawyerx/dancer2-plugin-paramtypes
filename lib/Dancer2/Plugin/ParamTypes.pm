package Dancer2::Plugin::ParamTypes;
# ABSTRACT: Parameter type checking plugin for Dancer2

use strict;
use warnings;
use constant { 'INTERNAL_SERVER_ERROR' => 500 };
use DDP;
use Carp ();
use Dancer2::Plugin;
use Scalar::Util ();

# TODO: Types::Tiny ?
# PLZ OH PLZ FIX Types::Tiny::XS !!!

## no critic qw(Subroutines::ProhibitCallsToUndeclaredSubs)
plugin_keywords(qw<register_type_check register_type_response with_types>);

has 'type_checks' => (
    'is'      => 'ro',
    'default' => sub {
        (
            {
                'int' => sub { Scalar::Util::looks_like_number( $_[0] ) },

                'positive_int' => sub {
                    Scalar::Util::looks_like_number( $_[0] ) && $_[0] >= 0;
                },

                'negative_int' => sub {
                    Scalar::Util::looks_like_number( $_[0] ) && $_[0] < 0;
                },
            }
        );
    },
);

has 'type_responses' => (
    'is'      => 'ro',
    'default' => sub {
        (
            {
                'warn' => sub {
                    my ( $app, $type_details ) = @_;
                    printf STDERR '%s failed test "%s"',
                        @{$type_details}{qw<name type>};
                },

                'error' => sub {
                    my ( $app, $type_details ) = @_;
                    my $name = $type_details->{'name'};
                    $app->response->status( INTERNAL_SERVER_ERROR() );
                    $app->response->content("Type check failed for $name");
                },
            }
        );
    },
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

    foreach my $type_details ( @{$full_type_details} ) {
        my $name     = $type_details->{'name'};
        my $type     = $type_details->{'type'};
        my $response = $type_details->{'on_invalid'};
        my $source   = $type_details->{'source'}
            or Carp::croak("Type '$name' must provide a source");

        $source eq 'route' || $source eq 'query' || $source eq 'body'
            or
            Carp::croak("Type $name provided from unknown source '$source'");

        defined $self->type_checks->{$type}
            or Carp::croak("Type $name provided unknown type '$type'");

        defined $self->type_responses->{$response}
            or
            Carp::croak("Type $name provided unknown response '$response'");

        $params_to_check{$source}{$name} = $type_details;
    }

    Scalar::Util::weaken( my $plugin = $self );

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
                    my $type_details
                        = $params_to_check{$param_source}{$param_name};

                    $plugin->run_check($type_details);
                }
            }

        }

        $cb->(@route_args);
    };
}

sub run_check {
    my ( $self, $type_details ) = @_;

    my $param_name   = $type_details->{'name'};
    my $param_source = $type_details->{'source'};
    my $app          = $self->app;
    my $request      = $app->request;

    # This used to be a "? :" expression, but it makes it harder to
    # notice when a value wasn't supplied vs. empty string. In this
    # situation, we know it's undef if no value was provided. -- SX.
    my $param_value;
    if ( $param_source eq 'route' ) {
        $param_value = $request->route_parameters->get($param_name);
    } elsif ( $param_source eq 'query' ) {
        $param_value = $request->query_parameters->get($param_name);
    } elsif ( $param_source eq 'body' ) {
        $param_value =  $request->body_parameters->get($param_name);
    }

    # There is no value added to check for this
    defined $param_value
        or return 1;

    # There is no check for this
    my $check_cb = $self->type_checks->{ $type_details->{'type'} };

    if ( ! $check_cb->($param_value) ) {
        my $response_cb
            = $self->type_responses->{ $type_details->{'on_invalid'} };
        return $response_cb->( $app, $type_details );
    }

    return;
}

1;

__END__

=head1 SYNOPSIS

    package MyApp {
        use Dancer2;
        use Dancer2::Plugin::ParamTypes;

        get '/' => with_types[(
            {
                'name'       => 'id',
                'source'     => 'query',
                'type'       => 'positive_int',
                'on_invalid' => 'error',
            },
        )} => sub {
            my $id = query_parameters->get('id');

            # $id is a positive int, for sure
        };
    }

=head1 DESCRIPTION

This is a basic module that allows you to provide a stanza of
parameter type checks for your routes.

It supports all three possible sources (C<route>, C<query>, and
C<body>) and allows you to both add your own checks and your own
actions when a check fails.

=head1 TO DO

=over 4

=item * Add more types

Trivial examples are available as C<int>, C<positive_int>, and
C<negative_int>. A lot of other common types should be added.

=item * Support type systems

There are several type systems available. There's not a lot of use
writing another one unless special ones are added. Some type systems
already allow you to add advanced options like in-lined version of
your types.

L<Type::Tiny> comes to mind.

=item * Document the rest of the options

Duh.

=back
