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

function _M.new(self, backend_class, opts)
    local opts_global = {
    }
    if opts then
        for k,v in pairs(opts) do
            if type(v) ~= "table" then
                opts_global[k] = v
            end
        end
    end
    local backend = require(backend_class)
    local self = {
        opts = opts_global,
        backend = backend:new(opts)
    }
    return setmetatable(self, mt)
end

function _M.get_route(self, key)
    local routes = self.backend:lookup(key)
    if not routes or not #routes then
        return nil
    end
    local route = routes[math.random(#routes)]
    local url = route.address .. ":" .. route.port .. route.path
    self.log_info("selected route", url)
    return url
end

return _M
