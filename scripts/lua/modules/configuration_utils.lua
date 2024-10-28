--
-- (C) 2013-24 - ntop.org
--

require "lua_utils"
local sys_utils = require "sys_utils"
local rest_utils = require("rest_utils")

local conf_utils = {}

local dirs = ntop.getDirs()
local dir = dirs.bindir .. "/ntopng-config"
local redis_key = "increased_max_num_host_or_flows"

-- ################################################################

local function closestNumber(n)
    if n > 0 and (n & (n - 1)) == 0 then
        return n
    end
    -- Find the closest 2^ to the number n
    local x = 2 ^ math.ceil(math.log(n) / math.log(2))
    local i, _ = math.modf(x)
    return i
end

-- ################################################################

function conf_utils.increase_num_host_num_flows(incr_num_hosts, incr_num_flows)
    local exit_status
    -- Double the value of the hosts or of the flows
    if incr_num_hosts then
        local num_hosts = interface.getNumHosts()
        num_hosts = closestNumber(num_hosts)
        exit_status = sys_utils.execShellCmd(dir .. " -x " .. num_hosts)
    elseif incr_num_flows then
        local num_flows = interface.getNumFlows()
        num_flows = closestNumber(num_flows)
        exit_status = sys_utils.execShellCmd(dir .. " -X " .. num_flows)
    end

    local res = {
        exit_status = exit_status
    }

    if string.find(exit_status, "succesfully changed") then
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
