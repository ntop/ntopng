--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local control_groups = require "control_groups"
local alert_consts = require "alert_consts"

-- Cleanup
control_groups.cleanup()

local one_group_members = {"192.168.2.0/24","192.168.3.0/24"}
local another_group_members = {"192.168.2.1/32"}
local yet_another_group_members = {"192.168.2.222/32", "192.168.2.225/32"}

local one_group_id = control_groups.add_control_group("One Group" --[[ the name --]], one_group_members)
local another_group_id = control_groups.add_control_group("Another Group" --[[ the name --]], another_group_members)
local yet_another_group_id = control_groups.add_control_group("Yet Another Group" --[[ the name --]], yet_another_group_members)

local get_one_group = control_groups.get_control_group(one_group_id)
local get_another_group = control_groups.get_control_group(another_group_id)
local get_yet_another_group = control_groups.get_control_group(yet_another_group_id)



-- ##############################################

-- Checks on expected ids
assert(one_group_id == get_one_group.control_group_id)
assert(another_group_id == get_another_group.control_group_id)
assert(yet_another_group_id == get_yet_another_group.control_group_id)

-- Checks on expected members
assert(table.compare(get_one_group.members, one_group_members))
assert(table.compare(get_another_group.members, another_group_members))
assert(table.compare(get_yet_another_group.members, yet_another_group_members))



-- ##############################################

-- Checks on delete
control_groups.delete_control_group(another_group_id)
local get_another_group = control_groups.get_control_group(another_group_id)
assert(get_another_group == nil)

-- Check ID reuse
local additional_group_id = control_groups.add_control_group("Additional Group" --[[ the name --]], one_group_members)
assert(additional_group_id == another_group_id)



-- ##############################################

-- Edit
local edited_ok = control_groups.edit_control_group(one_group_id, "One Group Edited", another_group_members)
local get_one_group = control_groups.get_control_group(one_group_id)
assert(edited_ok)
assert(get_one_group.name == "One Group Edited")
assert(table.compare(get_one_group.members, another_group_members))



-- ##############################################

-- Checks on disabled alerts
local a_disabled_alert = alert_consts.alert_types.alert_data_exfiltration.meta.alert_key
local another_disabled_alert = alert_consts.alert_types.alert_dns_invalid_query.meta.alert_key

-- First disabled alert
local a_disabled_ok = control_groups.disable_control_group_flow_alert(one_group_id, a_disabled_alert)
assert(a_disabled_ok)
local get_one_group = control_groups.get_control_group(one_group_id)
assert(table.compare(get_one_group.disabled_alerts, {a_disabled_alert}))

-- Second disabled alert
local another_disabled_ok = control_groups.disable_control_group_flow_alert(one_group_id, another_disabled_alert)
assert(another_disabled_ok)
local get_one_group = control_groups.get_control_group(one_group_id)
assert(table.compare(get_one_group.disabled_alerts, {a_disabled_alert, another_disabled_alert}))



-- ##############################################

-- Checks to re-enable alerts

-- Checks on disabled alerts
local a_enabled_alert = alert_consts.alert_types.alert_data_exfiltration.meta.alert_key
local another_enabled_alert = alert_consts.alert_types.alert_dns_invalid_query.meta.alert_key

-- First enabled alert
local a_enabled_ok = control_groups.enable_control_group_flow_alert(one_group_id, a_enabled_alert)
assert(a_enabled_ok)
local get_one_group = control_groups.get_control_group(one_group_id)
assert(table.compare(get_one_group.disabled_alerts, {another_disabled_alert}))

-- Second enabled alert
local another_disabled_ok = control_groups.enable_control_group_flow_alert(one_group_id, another_enabled_alert)
assert(another_disabled_ok)
local get_one_group = control_groups.get_control_group(one_group_id)
assert(table.compare(get_one_group.disabled_alerts, {}))



-- ##############################################

-- Cleanup
control_groups.cleanup()

print("OK\n")

