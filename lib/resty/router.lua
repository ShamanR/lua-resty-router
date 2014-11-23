local DEBUG = ngx.config.debug
local LOG_DEBUG = ngx.DEBUG
local LOG_ERR = ngx.ERR
local LOG_INFO = ngx.INFO
local LOG_WARN = ngx.WARN

local _M = {
    _VERSION = "0.1"
}
local mt = { __index = _M }
local setmetatable = setmetatable

function _M.log_info(...)
    ngx.log(LOG_INFO, "router: ", ...)
end

function _M.log_warn(...)
    ngx.log(LOG_WARN, "router: ", ...)
end

function _M.log_err(...)
    ngx.log(LOG_ERR, "router: ", ...)
end

function _M.log_debug(...)
    if not DEBUG then
        return
    end
    ngx.log(LOG_DEBUG, "router: ", ...)
end

return _M
