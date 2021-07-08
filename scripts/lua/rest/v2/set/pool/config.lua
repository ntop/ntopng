--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local info = ntop.getInfo() 

local json = require ("dkjson")
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local host_pools_nedge = require "host_pools_nedge"
local rest_utils = require("rest_utils")
local tracker = require("tracker")
local auth = require "auth"

--
-- Import host pools configuration
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local ifid = _GET["ifid"]

if not auth.has_capability(auth.capabilities.pools) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) then
   ifid = interface.name2id(ifname)
end

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

if(_POST["JSON"] == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local data = json.decode(_POST["JSON"])

if(table.empty(data)) then
  rest_utils.answer(rest_utils.consts.err.bad_format)
  return
end

if data["0"] == nil then
  rest_utils.answer(rest_utils.consts.err.bad_content)
  return
end

-- ################################################

local success = host_pools_nedge.import(data)

ntop.reloadHostPools()

if not success then
  rest_utils.answer(rest_utils.consts.err.internal_error)
  return
end

-- ################################################

-- TRACKER HOOK
tracker.log('set_pool_config', {})

rest_utils.answer(rest_utils.consts.success.ok)
