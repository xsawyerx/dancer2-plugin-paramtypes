SYNOPSIS
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

DESCRIPTION
    This is a basic module that allows you to provide a stanza of parameter
    type checks for your routes.

    It supports all three possible sources ("route", "query", and "body")
    and allows you to both add your own checks and your own actions when a
    check fails.

TO DO
    *   Add more types

        Trivial examples are available as "int", "positive_int", and
        "negative_int". A lot of other common types should be added.

    *   Support type systems

        There are several type systems available. There's not a lot of use
        writing another one unless special ones are added. Some type systems
        already allow you to add advanced options like in-lined version of
        your types.

        Type::Tiny comes to mind.

    *   Document the rest of the options

        Duh.

