# local CPAN setup:
# cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
# cpanm Test::Nginx::Socket

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_shared_dict locks 1m;
    lua_shared_dict cache_dict 10m;
    lua_package_path "$pwd/lib/?.lua;/usr/local/openresty-debug/lualib/?.lua;/usr/local/openresty/lualib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

no_long_string();

run_tests();

__DATA__

=== TEST 0: public A record
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.dns",
                {
                    dns_opts = {
                        nameservers = {"8.8.8.8"}
                    }
                }
            )
            ngx.say(r:get_route("example.com"))
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
93.184.216.34:80



=== TEST 1: mock zero TTL
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = {
                        { route = "1.1.1.1:81", ttl = 0 },
                    },
                }
            )
            -- minimum TTL is 1 second, not 0, due to ngx.shared.DICT.set exptime
            ngx.say(r:get_route("foo"))
            ngx.say(r:get_route("bar"))
            ngx.sleep(1.1)
            ngx.say(r:get_route("foo"))
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
1.1.1.1:81
nil
nil



=== TEST 2: mock with TTL
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = {
                        { route = "2.2.2.2:82", ttl = 100 },
                    },
                }
            )
            ngx.say(r:get_route("foo"))
            ngx.say(r:get_route("foo"))
            ngx.say(r:get_route("foo"))
            ngx.say(r:get_route("zod"))
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
2.2.2.2:82
2.2.2.2:82
2.2.2.2:82
nil



=== TEST 2: mock mixed TTL
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = {
                        { route = "1.1.1.1:81", ttl = 1 },
                        { route = "2.2.2.2:82", ttl = 100 },
                    },
                }
            )
            ngx.say(r:get_route("foo"))
            ngx.say(r:get_route("bar"))
            ngx.sleep(1.1)
            ngx.say(r:get_route("foo"))
            ngx.say(r:get_route("bar"))
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
1.1.1.1:81
2.2.2.2:82
nil
2.2.2.2:82
