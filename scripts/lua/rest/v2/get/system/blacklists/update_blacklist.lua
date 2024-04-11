--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
local rest_utils = require "rest_utils"
local lists_utils = require "lists_utils"
local list_name = _GET["list_name"]

if isEmptyString(list_name) then
   rest_utils.answer(rest_utils.consts.err.bad_content)
   return 
end
lists_utils.updateList(list_name)

rest_utils.answer(rest_utils.consts.success.ok)