# lua-resty-router

A simple dynamic request router for nginx. Pluggable backends for flexibility; ngx.shared.DICT caching for performance.

## Usage

Install openresty and put lua-resty-router in lualib. Install and run the following nginx.conf:

```
worker_processes  2;
error_log logs/error.log info;

events {
  worker_connections 1024;
}

http {
  lua_shared_dict locks 1m;
  lua_shared_dict cache_dict 1m;
  lua_package_path "/usr/local/openresty-debug/lualib/?.lua;/usr/local/openresty/lualib/?.lua;;";
  lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";

  server {
    listen 8888;
    location / {
      set $rr_route '';
      set $rr_status 'NOTFOUND';
      rewrite_by_lua '
        local router = require "resty.router"
        local r = router:new(
          "resty.router.dns",
          {
            dns_opts = {
              nameservers = { "8.8.8.8" }
            }
          }
        )
        local route = r:get_route(ngx.var.arg_host)
        if not route then
            return ngx.exit(404)
        end
        ngx.var.rr_route = route
        ngx.var.rr_status = ngx.ctx.shcache["resty_router_cache"].cache_status
      ';
      more_set_headers "X-RR-Key: $arg_host";
      more_set_headers "X-RR-State: $rr_status";
      more_set_headers "X-RR-Route: $rr_route";
      proxy_pass http://$rr_route;
    }
  }
}
```

This example uses the host arg as the key, but could just as easily use any HTTP header, host, or path part.

```
curl -I http://localhost:8888/?host=example.com
```

A more inventive approach for a microservices architecture is to use SRV records alongside a same-named record for the router. The careful reader will note our SRV record format is wanting a prefix like "_Service._Proto.". For applications using private DNS this seems unnecessary.

```
# example-service.example.com  IN CNAME  router.example.com.
# example-service.example.com  IN SRV    1 1 5000 10.1.1.1
# example-service.example.com  IN SRV    1 1 5000 10.1.1.2
# example-service.example.com  IN SRV    1 1 5000 10.1.1.3
...
location / {
  set $rr_route '';
  set $rr_status 'NOTFOUND';
  rewrite_by_lua '
    local router = require "resty.router"
    local r = router:new(
      "resty.router.dns",
      {
        dns_opts = {
          nameservers = { "8.8.8.8" },
          record_type = "SRV"
        }
      }
    )
    local route = r:get_route(ngx.var.http_host)
    if not route then
        return ngx.exit(404)
    end
    ngx.var.rr_route = route
    ngx.var.rr_status = ngx.ctx.shcache["resty_router_cache"].cache_status
  ';
  more_set_headers "X-RR-Key: $arg_host";
  more_set_headers "X-RR-State: $rr_status";
  more_set_headers "X-RR-Route: $rr_route";
  proxy_pass http://$rr_route;
}
...
```
