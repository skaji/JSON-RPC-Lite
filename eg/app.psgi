use strict;
use JSON::RPC::Lite;
use List::Util 'sum';

method sum => sub {
    my $c = shift;
    my $params = $c->params;
    return $c->res_invalid_params if ref $params ne 'ARRAY';
    my $sum = sum 0, @$params;
    my $res = $c->res;
    $res->result({sum => $sum});
    return $res;
};

start;
