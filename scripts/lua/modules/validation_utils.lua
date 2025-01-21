--
-- (C) 2021 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- #################################################################

local validation_utils = {}

-- #################################################################

local function validateNumber(p)
    -- integer number validation
    local num = tonumber(p)

    if (num == nil) then
        return false
    end

    if math.floor(num) == num then
        return true
    else
        -- this is a float number
        return false
    end
end

-- #################################################################

function validation_utils.validatePortRange(p)
    local v = string.split(p, "%-") or {p, p}

    if #v ~= 2 then
        return false
    end

    if not validateNumber(v[1]) or not validateNumber(v[2]) then
        return false
    end

    local p0 = tonumber(v[1]) or 0
    local p1 = tonumber(v[2]) or 0

    return (((p0 >= 1) and (p0 <= 65535)) and ((p1 >= 1) and (p1 <= 65535) and (p1 >= p0)))
end

-- #################################################################

return validation_utils
