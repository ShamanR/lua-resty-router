local _M = {
    _VERSION = "0.1"
}
local mt = { __index = _M }
local setmetatable = setmetatable

local router = require "resty.router"
local log_info = router.log_info
local log_warn = router.log_warn
local log_err = router.log_err
local MINIMUM_TTL = router.MINIMUM_TTL

--
-- Pass in a table of responses in order and mock will respond thusly, e.g.
-- {
--     { route = "1.1.1.1:81", ttl = 0 },
--     { route = "2.2.2.2:82", ttl = 100 },
--     { route = "3.3.3.3:83", ttl = 0 },
-- }
--
function _M.new(self, opts)
    local self = {
        responses = opts.mock_opts,
        current_response = 0
    }
    return setmetatable(self, mt)
end

function _M.lookup(self, key)
    self.current_response = self.current_response + 1
    local data = self.responses[self.current_response]
    log_info(data)
    if data and data.route and data.ttl then
        if data.ttl < 1 then
            data.ttl = MINIMUM_TTL
        end
        return { data.route }, nil, data.ttl
    else
        return { }, nil, nil
    end
end

return _M
