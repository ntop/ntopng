--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local format_utils = require "format_utils"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_redis_reads_writes_exceeded = classes.class(alert)

-- ##############################################

alert_redis_reads_writes_exceeded.meta = {
  alert_key = other_alert_keys.alert_redis_reads_writes_exceeded,
  i18n_title = "alerts_dashboard.redis_reads_writes_exceeded",
  icon = "fas fa-fw fa-undo",
  entities = {
    alert_entities.system
  },

  -- Mitre Att&ck Matrix values
  -- mitre_values = {
  --  mitre_tactic = mitre.tactic.exfiltration,
  --  mitre_technique = mitre.technique.exfiltration_over_c2_channel,
  --  mitre_id = "T1041"
  -- },
}

-- ##############################################

function alert_redis_reads_writes_exceeded:init(zscorer, zscorew)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      zscorer = zscorer,
      zscorew = zscorew,
   }
end

-- #######################################################

function alert_redis_reads_writes_exceeded.format(ifid, alert, alert_type_params)

  return(i18n("alert_messages.redis_reads_writes_exceeded", {
    zscorer = alert_type_params.zscorer,
    zscorew = alert_type_params.zscorew,
  }))
end

return alert_redis_reads_writes_exceeded
