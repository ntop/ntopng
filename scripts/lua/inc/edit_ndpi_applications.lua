--
-- (C) 2017-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require "template_utils"
local protos_utils = require "protos_utils"

local has_protos_file = protos_utils.hasProtosFile()

template_utils.render("pages/edit-applications.template", {
  ifid = interface.getId(),
  has_protos_file = has_protos_file,
})