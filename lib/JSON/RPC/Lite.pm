package JSON::RPC::Lite;
use strict;
use warnings;
our $VERSION = '0.001';

{
    package JSON::RPC::Lite::Response;
    use parent 'Plack::Response';

    sub new {
        my ($class, %option) = @_;
        my $self = $class->SUPER::new(200);
        $self->{_json} = $option{json};
        $self->{_jsonrpc_body} = {};
        $self;
    }

    for my $name (qw(jsonrpc error result id)) {
        no strict 'refs';
        *$name = sub {
            my $self = shift;
            if (@_) {
                $self->{_jsonrpc_body}{$name} = shift;
                return $self;
            } else {
                return $self->{_jsonrpc_body}{$name};
            }
        };
    }

    sub finalize {
        my $self = shift;
        my $encoded = eval { $self->{_json}->encode($self->{_jsonrpc_body}) } || "";
        $self->body($encoded);
        $self->content_type("application/json; charset=utf-8");
        $self->content_length(length $encoded);
        $self->SUPER::finalize;
    }
}

{
    package JSON::RPC::Lite::Controller;
    use Plack::Request;

    sub new {
        my ($class, %option) = @_;
        my $req = Plack::Request->new($option{env});
        bless { req => $req, json => $option{json}, _jsonrpc_body => {} }, $class;
    }

    sub _jsonrpc_body {
        my $self = shift;
        return $self->{_jsonrpc_body} if %{$self->{_jsonrpc_body}};

        my $body = $self->{req}->raw_body;
        my $decoded = eval { $self->{json}->decode($body) };
        if (!$@ and ref $decoded eq 'HASH') {
            return $self->{_jsonrpc_body} = $decoded;
        } else {
            return {};
        }
    }

    sub validate {
        my $self = shift;
        return (0, 405) if $self->{req}->method ne "POST";
        return (0, 415) if ($self->{req}->content_type || "") !~ m{^application/json\b}i;
        return (0, 200) unless my $jsonrpc_body = $self->_jsonrpc_body;
        if (($jsonrpc_body->{jsonrpc} || 0) eq '2.0'
            and defined $jsonrpc_body->{method}
            and exists $jsonrpc_body->{id}
        ) {
            return (1, undef);
        } else {
            return (0, 200);
        }
    }

    for my $name (qw(jsonrpc id method params)) {
        no strict 'refs';
        *$name = sub {
            my $self = shift;
            if (@_) {
                $self->_jsonrpc_body->{$name} = shift;
                return $self;
            } else {
                return $self->_jsonrpc_body->{$name};
            }
        };
    }

    sub res {
        my $self = shift;
        my $res = JSON::RPC::Lite::Response->new(json => $self->{json});
        $res->id($self->id);
        $res->jsonrpc("2.0");
        $res;
    }

    my %error = (
        parse_error => -32700,
        invalid_request => -32600,
        method_not_found => -32601,
        invalid_params => -32602,
        internal_error => -32603,
        server_error => -32000,
    );
    for my $name (keys %error) {
        my $message = $name;
        $message =~ s/^(.)/ uc $1 /e;
        $message =~ s/_(.)/ " " . uc($1) /eg;
        no strict 'refs';
        *{ "res_$name" } = sub {
            my $res = shift->res;
            $res->error({code => $error{$name}, message => $message});
            return $res;
        };
    }
}

use JSON ();

sub import {
    my $class = shift;
    my $caller = caller;

    my $self = $class->new;
    {
        no strict 'refs';
        *{$caller . "::method" } = sub { $self->add_method(@_) };
        *{$caller . "::start"  } = sub { $self->to_app };
    }
}

sub new {
    my ($class, %option) = @_;
    my $json = $option{json} || JSON->new->utf8(1)->canonical(1)->pretty(1);
    bless { router => +{}, json => $json }, $class;
}

sub add_method {
    my ($self, $name, $sub) = @_;
    $self->{router}{$name} = $sub;
    $self;
}

sub to_app {
    my $self = shift;
    sub {
        my $env = shift;
        my $c = JSON::RPC::Lite::Controller->new(env => $env, json => $self->{json});
        my ($ok, $status) = $c->validate;
        if (!$ok) {
            my $res = $c->res_invalid_request;
            $res->status(200); # XXX use $status ?
            return $res->finalize;
        }
        my $method = $c->method;
        if (my $sub = $self->{router}{$method}) {
            my $res = eval { $sub->($c) };
            my $err = $@;
            if (!$err and $res and eval { $res->isa(JSON::RPC::Lite::Response::) }) {
                return $res->finalize;
            } else {
                if ($err) {
                    warn $err;
                } else {
                    warn "method '$method' does not return a response object";
                }
                return $c->res_internal_error->finalize;
            }
        } else {
            return $c->res_method_not_found->finalize;
        }
    };
}

1;
__END__

=encoding utf-8

=head1 NAME

JSON::RPC::Lite - create JSON-RPC 2.0 application

=head1 SYNOPSIS

  # app.psgi
  use JSON::RPC::Lite;
  use List::Util 'sum';

  method 'sum' => sub {
    my $c = shift;
    my $params = $c->params;
    return $c->res_invalid_params if ref $params ne 'ARRAY';
    my $sum = sum 0, @$params;
    my $res = $c->res;
    $res->result({sum => $sum});
    return $res;
  };

  start;

Then

  $ plackup app.psgi

=head1 DESCRIPTION

JSON::RPC::Lite is a minimal framework for
L<JSON-RPC 2.0|http://www.jsonrpc.org/specification> application.

JSON::RPC::Lite offers two interfaces: DSL and OO.

=head2 DSL

See SYNOPSIS.

=head2 OO

  use Plack::Builder;
  use JSON::RPC::Lite ();

  my $rpc = JSON::RPC::Lite->new;

  $rpc->add_method("sum", sub {
    my $c = shift;
    ...;
  });

  builder {
    mount "/" => Some::App->to_app;
    mount "/rpc" => $rpc->to_app;
  };

=head1 AUTHOR

Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
