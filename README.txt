SYNOPSIS
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

DESCRIPTION
    This is a basic module that allows you to provide a stanza of parameter
    type checks for your routes.

    It supports all three possible sources ("route", "query", and "body").

    Currently it does not have any known types and actions on its own. You
    you will need to write your own code to add them. The synopsis includes
    an example on adding your own.

  Methods
   "register_type_check"
    First you must register a type check, allowing you to test stuff:

        register_type_check 'Int' => sub {
            return Scalar::Util::looks_like_number( $_[0] );
        };

   "register_type_response"
        register_type_response 'error' => sub {
            my ( $app, $type_details ) = @_;
            my ( $source, $name, $type, $action ) = @{$type_details};

            send_error("Type check failed for $source $name ($type)");
        }

   "with_types"
    "with_types" defines checks for parameters for a route request.

        get '/:name' => with_request [
            [ 'route', 'name', 'Str', 'error' ]
        ] => sub {
            ...
        };

  Connecting existing type systems
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

