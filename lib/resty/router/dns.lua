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

function _M.lookup(self, hostname)
    local answers, err = self.resolver:query(hostname)
    if not answers then
        log_err("DNS query failed", err)
        return
    elseif answers.errcode then
        log_err("DNS query errored", answers.errcode, ": ", answers.errstr)
    else
        log_info("DNS query record count", #answers)
    end
    local routes = {}
    local i = 1
    for offset, record in ipairs(answers) do
        log_info("query result", record.address, " type:", record.type,
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
    local opts_dns = {
        nameservers = {"127.0.0.1"},
        retrans = 3,
        timeout = 5000,
    }
    if opts.dns then
        for k,v in pairs(opts.dns) do
            opts_dns[k] = v
        end
    end
    local resolver, err = dns:new(opts_dns)
    if not resolver then
        log_err("failed to instantiate resolver", err)
    end
    local self = {
        resolver = resolver
    }
    return setmetatable(self, mt)
end

return _M
