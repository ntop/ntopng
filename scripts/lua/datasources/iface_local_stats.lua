--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local datasources_utils = require("datasources_utils")
local datamodel = require("datamodel_utils")

local function reportError(msg)
    print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

local ifid              = _GET["ifid"]
local key_ip            = _GET["key_ip"]
local key_mac           = _GET["key_mac"]
local key_asn           = _GET["key_asn"]
local key_metric        = _GET["key_metric"]

local m = datamodel:create({"l2r", "r2l"})
local when = 0

local dataset = "Traffic Distribution"

m:appendRow(when, dataset, {1, 2})

return(m)
