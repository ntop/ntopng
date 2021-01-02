--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path
local recipients = require "recipients"
local json = require "dkjson"
local sqlite_recipients = {}

-- ##############################################

function sqlite_recipients:create()
   -- Instance of the base class
   local _sqlite_recipients = recipients:create()
   self.enabled = true -- Toggle this to skip dispatch and processing of notifications

   -- Subclass using the base class instance
   self.key = "sqlite"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _sqlite_recipients_instance = _sqlite_recipients:create(self)

   -- Return the instance
   return _sqlite_recipients_instance
end

-- ##############################################

function sqlite_recipients:dispatch_store_notification(notification)
   if self.enabled then
      return ntop.pushSqliteAlert(notification)
   end

   return false
end

-- ##############################################

function sqlite_recipients:dispatch_release_notification(notification)
   if self.enabled then
      return ntop.pushSqliteAlert(notification)
   end

   return false
end

-- ##############################################

function sqlite_recipients:process_notifications()
   if not self.enabled or not areAlertsEnabled() then
      return false
   end

   -- SQLite Alerts
   while(true) do
      local alert_json = ntop.popSqliteAlert()

      if(not alert_json) then
	 break
      end

      local alert = json.decode(alert_json)

      if(alert) then
	 interface.select(string.format("%d", alert.ifid))

	 if(alert.is_flow_alert) then
	    interface.storeFlowAlert(alert)
	 else
	    interface.storeAlert(
	       alert.alert_tstamp, alert.alert_tstamp_end, alert.alert_granularity,
	       alert.alert_type, alert.alert_subtype, alert.alert_severity,
	       alert.alert_entity, alert.alert_entity_val,
	       alert.alert_json)
	 end
      end

      if ntop.isDeadlineApproaching() then
	 return(false)
      end
   end

   return(true)
end

-- ##############################################

return sqlite_recipients
