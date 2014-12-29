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
                        nameservers = { "8.8.8.8" }
                    }
                }
            )
            ngx.say(r:get_route("a.lua-resty-router.jbyers.com"))
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
10.1.1.1:80



=== TEST 1: mock no response
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = { },
                }
            )
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
nil
NO_DATA



=== TEST 2: mock zero TTL
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = {
                        { routes = { "1.1.1.1:81" }, ttl = 0 },
                    },
                }
            )
            -- minimum TTL is 1 second, not 0, due to ngx.shared.DICT.set exptime
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.say(r:get_route("bar"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.sleep(1)
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
1.1.1.1:81
MISS
nil
NO_DATA
1.1.1.1:81
STALE



=== TEST 3: mock with TTL
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = {
                        { routes = { "2.2.2.2:82" }, ttl = 100 },
                    },
                }
            )
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.say(r:get_route("baz"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
2.2.2.2:82
MISS
2.2.2.2:82
HIT
2.2.2.2:82
HIT
nil
NO_DATA



=== TEST 4: mock mixed TTL
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = {
                        { routes = { "1.1.1.1:81" }, ttl = 0 },   -- foo
                        { routes = { "2.2.2.2:82" }, ttl = 100 }, -- bar
                    },
                }
            )
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.say(r:get_route("bar"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.sleep(1)
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.say(r:get_route("bar"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
1.1.1.1:81
MISS
2.2.2.2:82
MISS
1.1.1.1:81
STALE
2.2.2.2:82
HIT



=== TEST 5: mock negative cache
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.mock",
                {
                    mock_opts = {
                        { routes = { "1.1.1.1:81" }, ttl = 0 },
                    },
                }
            )
            ngx.say(r:get_route("foo"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.sleep(1)
            ngx.say(r:get_route("bar"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
            ngx.sleep(1)
            ngx.say(r:get_route("bar"))
            ngx.say(ngx.ctx.shcache["resty_router_cache"].cache_status)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
1.1.1.1:81
MISS
nil
NO_DATA
nil
HIT_NEGATIVE



=== TEST 5: public SRV record
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local router = require "resty.router"
            local r = router:new(
                "resty.router.dns",
                {
                    dns_opts = {
                        nameservers = { "8.8.8.8" },
                        qtype = 33
                    }
                }
            )
            ngx.say(r:get_route("srv.lua-resty-router.jbyers.com"))
            ngx.say(r:get_route("no-record.lua-resty-router.jbyers.com"))
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
10.1.1.2:5000
nil
