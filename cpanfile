requires 'perl', '5.008005';
requires 'Plack';
requires 'JSON';
requires 'Router::Boom';
requires 'parent';

on develop => sub {
    requires 'HTTP::Request::Common';
};
