--
-- (C) 2025-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

--
-- Return chord chart test data
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/chord_test.lua
--

local rc = rest_utils.consts.success.ok


local res = {
    names = {
        "Site 1",
        "Office",
        "DC1",
        "Office 2",
        "Site 3",
        "Ingress Gateway"
    },

    -- Matrix[i][j] represents traffic from entity i to entity j
    matrix = {
        {0,    500,  800,  200,  0,    100},  -- site 1
        {450,  0,    0,    800,  0,    50,},  -- office
        {750,  600,  0,    300,  0,    400,},  -- dc1
        {150,  700,  250,  0,    0,    0, },  -- office 2
        {0,    0,    0,    0,    0,    0, },    -- site 3
        {80,   40,   350,  0,    0,    0, }   -- ingress gateway
    }
}

rest_utils.answer(rc, res)
