[![Build Status](https://travis-ci.org/skaji/JSON-RPC-Lite.svg?branch=master)](https://travis-ci.org/skaji/JSON-RPC-Lite)

# NAME

JSON::RPC::Lite - create JSON-RPC 2.0 application

# SYNOPSIS

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

# DESCRIPTION

JSON::RPC::Lite is a minimal framework for
[JSON-RPC 2.0](http://www.jsonrpc.org/specification) application.

JSON::RPC::Lite offers two interfaces: DSL and OO.

## DSL

See SYNOPSIS.

## OO

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

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
