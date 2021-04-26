--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
  packet_interface_only = true,
  
  -- Script category
  category = user_scripts.script_categories.network,

  packet_interface_only = true,
  nedge_exclude = true,

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_low_goodput,

  default_value = {
    severity = alert_severities.notice,
    
  },
  
  -- For a full list check "available_subdir.flow.available_fields" in user_scripts.lua
  filter = {
     default_filters = {
	{ l7_proto =   8 }, -- MDNS
	{ l7_proto =  26 }, -- ntop
        { l7_proto =  39 }, -- Signal
        { l7_proto =  48 }, -- QQ
        { l7_proto =  65 }, -- IRC
	{ l7_proto =  77 }, -- Telnet
	{ l7_proto =  92 }, -- SSH
        { l7_proto = 142 }, -- WhatsApp
        { l7_proto = 185 }, -- Telegram
        { l7_proto = 193 }, -- KakaoTalk
        { l7_proto = 197 }, -- WeChat
     },
     default_fields  = { "srv_addr", "srv_port", "l7_proto", }
  },

  gui = {
    i18n_title = "low_goodput.title",
    i18n_description = "low_goodput.description",
  }
}

-- #################################################################

return script
