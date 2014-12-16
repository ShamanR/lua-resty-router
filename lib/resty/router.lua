local _M = {
    _VERSION = "0.1"
}
local mt = { __index = _M }
local setmetatable = setmetatable

local ok, shcache = pcall(require, "resty.shcache")
if not ok then
    error("lua-resty-shcache module required")
end

local ok, cjson = pcall(require, "cjson")
if not ok then
    error("cjson module required")
end

local DEBUG = ngx.config.debug
local LOG_DEBUG = ngx.DEBUG
local LOG_ERR = ngx.ERR
local LOG_INFO = ngx.INFO
local LOG_WARN = ngx.WARN

-- minimum TTL is 1 second, not 0, due to ngx.shared.DICT.set exptime
_M.MINIMUM_TTL = 1
local DEFAULT_ACTUALIZE_TTL = 1
local DEFAULT_NEGATIVE_TTL = 1
local DEFAULT_POSITIVE_TTL = 60

local function log(log_level, ...)
    ngx.log(log_level, "router: " .. cjson.encode({...}))
end

function _M.log_info(...)
    log(LOG_INFO, ...)
end

function _M.log_warn(...)
    log(LOG_WARN, ...)
end

function _M.log_err(...)
    log(LOG_ERR, ...)
end

function _M.log_debug(...)
    if not DEBUG then
        return
    end
    log(LOG_DEBUG, ...)
end

function _M.new(self, backend_name, opts)
    local backend_class = require(backend_name)
    local backend = backend_class:new(opts)
    local cache = nil
    local lookup_route = function (key)
        local lookup = function ()
            return backend:lookup(key)
        end
        if not cache then
            cache = shcache:new(
                ngx.shared.cache_dict,
                {
                    external_lookup = lookup,
                    encode = cjson.encode,
                    decode = cjson.decode,
                },
                {
                    positive_ttl = opts.positive_ttl or DEFAULT_POSITIVE_TTL,
                    negative_ttl = opts.negative_ttl or DEFAULT_NEGATIVE_TTL,
                    actualize_ttl = opts.actualize_ttl or DEFAULT_ACTUALIZE_TTL,
                    name = "resty_router_cache",
                }
            )
        end
        local data, is_hit = cache:load(key)
        return data
    end
    local self = {
        backend = backend,
        lookup = lookup_route
    }
    return setmetatable(self, mt)
end

function _M.get_route(self, key)
    local routes = self.lookup(key)
    if not routes or 0 == #routes then
        return nil
    end
    local route = routes[math.random(#routes)]
    self.log_info({ key = key, route = route })
    return route
end

return _M
