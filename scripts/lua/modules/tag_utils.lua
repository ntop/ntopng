--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local tag_utils = {}

tag_utils.tag_operators = {
    ["eq"] = "=",
    ["lt"] = "<",
    ["gt"] = ">",
    ["gte"] = ">=",
    ["lte"] = "<=",
}

return tag_utils