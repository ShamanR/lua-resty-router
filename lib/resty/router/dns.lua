local _M = {
    _VERSION = "0.1"
}
local mt = { __index = _M }
local setmetatable = setmetatable

local ok, dns = pcall(require, "resty.dns.resolver")
if not ok then
    error("resty-dns-resolver module required")
end

local ok, cjson = pcall(require, "cjson")
if not ok then
    error("cjson module required")
end

local RECORD_A = dns.TYPE_A
local RECORD_SRV = dns.TYPE_SRV

local DEFAULT_PORT = 80
local DEFAULT_DNS_QUERY_TYPE = RECORD_A
local DEFAULT_DNS_RETRIES = 3
local DEFAULT_DNS_SERVERS = { "127.0.0.1" }
local DEFAULT_DNS_TIMEOUT = 5000

local router = require "resty.router"
local log_info = router.log_info
local log_warn = router.log_warn
local log_err = router.log_err
local MINIMUM_TTL = router.MINIMUM_TTL

function _M.new(self, opts)
    local opts_dns = {
        nameservers = DEFAULT_DNS_SERVERS,
        retrans = DEFAULT_DNS_RETRIES,
        timeout = DEFAULT_DNS_TIMEOUT,
        qtype = DEFAULT_DNS_QUERY_TYPE,
    }
    if opts.dns_opts then
        for k,v in pairs(opts_dns) do
            if opts.dns_opts[k] then
                opts_dns[k] = opts.dns_opts[k]
            end
        end
    end
    local resolver, err = dns:new(opts_dns)
    if not resolver then
        log_err("DNS resolver failure", err)
    end
    local self = {
        resolver = resolver,
        qtype = opts_dns.qtype,
    }
    return setmetatable(self, mt)
end

function _M.lookup(self, hostname)
    local answers, err = self.resolver:query(hostname, { qtype = self.qtype })
    if not answers then
        return nil, cjson.encode({"DNS query failure", hostname, err})
    elseif answers.errcode then
        return nil, cjson.encode({"DNS query error", hostname, answers})
    end
    local routes = {}
    local i = 1
    local ttl = MINIMUM_TTL
    for offset, record in ipairs(answers) do
        log_info("DNS response", record)
        local route = nil
        if record.type == RECORD_A then
            route = record.address .. ":" .. DEFAULT_PORT
        elseif record.type == RECORD_SRV then
            route = record.target .. ":" .. record.port
        end
        if route then
            if record.ttl and record.ttl > MINIMUM_TTL and record.ttl < ttl then
                ttl = record.ttl
            end
            routes[i] = route
            i = i + 1
        end
    end
    return routes, err, ttl
end

return _M
