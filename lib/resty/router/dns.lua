local _M = {
    _VERSION = "0.1"
}
local mt = { __index = _M }
local setmetatable = setmetatable

local ok, dns = pcall(require, "resty.dns.resolver")
if not ok then
    error("resty-dns-resolver module required")
end
local RECORD_A = dns.TYPE_A
local RECORD_SRV = dns.TYPE_SRV

local router = require "resty.router"
local log_info = router.log_info
local log_warn = router.log_warn
local log_err = router.log_err

local function lookup(resolver, hostname)
    local answers, err = resolver:query(hostname)
    if not answers then
        log_err("DNS query failed: ", err)
        return
    elseif answers.errcode then
        log_err("DNS query errored: ", answers.errcode, ": ", answers.errstr)
    else
        log_info("DNS query returned ", #answers, " records")
    end
    local routes = {}
    local i = 1
    for offset, record in ipairs(answers) do
        log_info("query returned: ", record.address, " type:", record.type,
            " class:", record.class, " ttl:", record.ttl)
        if record.type == RECORD_A then
            local route = {
                address = record.address,
                port = 80,
                path = "/"
            }
            routes[i] = route
            i = i + 1
        end
    end
    return routes
end

function _M.new(self, opts)
    local dns_settings = {
        nameservers = {"127.0.0.1"},
        retrans = 3,
        timeout = 5000,
    }
    if opts.dns then
        for k,v in pairs(opts.dns) do
            dns_settings[k] = v
        end
    end
    local resolver, err = dns:new(dns_settings)
    if not resolver then
        log_err("failed to instantiate resolver: ", err)
    end
    local self = {
        resolver = resolver
    }
    return setmetatable(self, mt)
end

function _M.get_route(self, key)
    local routes = lookup(self.resolver, key)
    if not routes or not #routes then
        return nil
    end
    local route = routes[math.random(#routes)]
    local route_string = route.address .. ":" .. route.port .. route.path
    log_info("chose route: ", route_string)
    return route_string
end

return _M
