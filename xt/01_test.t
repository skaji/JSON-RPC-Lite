use strict;
use warnings;
use Test::More;
use Plack::Test;
use JSON::RPC::Lite ();
use HTTP::Request::Common;
use JSON ();
sub decode {
    my $res = shift;
    eval { JSON::decode_json($res->content) } || +{};
}

my $rpc = JSON::RPC::Lite->new;

$rpc->add_method(sum => sub {
    my $c = shift;
    my $sum = List::Util::sum(@{$c->params});
    $c->res->result({sum => $sum});
});
$rpc->add_method(max => sub {
    my $c = shift;
    my $max = List::Util::max(@{$c->params});
    $c->res->result({max => $max});
});

my $test = Plack::Test->create($rpc->to_app);
my $res;

$res = $test->request(GET "/");
is $res->code, 200;
is decode($res)->{jsonrpc}, "2.0";
is decode($res)->{error}{code}, -32600;

$res = $test->request(
    POST "/", 'Content-Type' => 'application/json', 'Content' => JSON::encode_json(+{
        jsonrpc => "2.0",
        id => 100,
        method => 'sum',
        params => [1..10],
    })
);
is $res->code, 200;
is decode($res)->{jsonrpc}, "2.0";
is decode($res)->{id}, 100;
ok !exists decode($res)->{error};
is decode($res)->{result}{sum}, 55;

$res = $test->request(
    POST "/", 'Content-Type' => 'application/json', 'Content' => JSON::encode_json(+{
        jsonrpc => "2.0",
        id => 10,
        method => 'max',
        params => [1..10, 99, 98],
    })
);
is $res->code, 200;
is decode($res)->{jsonrpc}, "2.0";
is decode($res)->{id}, 10;
ok !exists decode($res)->{error};
is decode($res)->{result}{max}, 99;


done_testing;
