use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
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
            local router = require "resty.router.dns"
            local r = router:new{
              dns = {
                nameservers = {"8.8.8.8"}
              }
            }
            ngx.say(r:get_route("example.com"))
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
93.184.216.34:80/
