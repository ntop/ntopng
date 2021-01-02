--
-- (C) 2013-21 - ntop.org
--

require "lua_utils"
local sys_utils = require "sys_utils"
local rest_utils = require("rest_utils")

local conf_utils = {}

local redis_key = "increased_max_num_host_or_flows"
local dir = "/usr/bin/ntopng-config"

-- ################################################################

function conf_utils.increase_num_host_num_flows(incr_num_hosts, incr_num_flows)
    local exit_status = ""

    -- Double the value of the hosts or of the flows
    if incr_num_hosts then
        exit_status = sys_utils.execShellCmd(dir .. " -x *2")
    elseif incr_num_flows then
        exit_status = sys_utils.execShellCmd(dir .. " -X *2")
    end

    local res = {
        exit_status = exit_status
    }

    if string.match(exit_status, "succesfully changed") then
        -- Set the redis key for the restart
        ntop.setCache(redis_key, true)
        rest_utils.answer(rest_utils.consts.success.ok, res)
        return
    end

    rest_utils.answer(rest_utils.consts.err.internal_error, res)
end

-- #################################

function conf_utils.restart_required()
    if ntop.getCache(redis_key) == '' then
        return false
    end

    return true
end

-- #################################

function conf_utils.reset()
    if ntop.getCache(redis_key) ~= '' then
        ntop.delCache(redis_key)
    end
end

-- #################################

return conf_utils