--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local tcp_flow_state_utils = {}

function tcp_flow_state_utils.state2i18n(state)
   local states = {established = i18n("flows_page.tcp_state_established"),
		   connecting = i18n("flows_page.tcp_state_connecting"),
		   closed = i18n("flows_page.tcp_state_closed"),
		   reset = i18n("flows_page.tcp_state_reset")}

   return states[state or ''] or i18n("flows_page.tcp_state_unknown")
end

return tcp_flow_state_utils
