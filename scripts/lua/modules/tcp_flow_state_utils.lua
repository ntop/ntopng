--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local tcp_flow_state_utils = {}

function tcp_flow_state_utils.state2i18n(state)
   local states = {syn_only = i18n("flows_page.tcp_state_syn_only"),
		   rst = i18n("flows_page.tcp_state_rst"),
		   fin = i18n("flows_page.tcp_state_fin"),
		   syn_rst_only = i18n("flows_page.tcp_state_syn_rst_only"),
		   fin_rst = i18n("flows_page.tcp_state_fin_rst"),
		   established_only = i18n("flows_page.tcp_state_established_only"),
		   not_established_only = i18n("flows_page.tcp_state_not_established_only")
		  }

   return states[state or ''] or i18n("flows_page.tcp_state_unknown")
end

return tcp_flow_state_utils
