--
-- (C) 2017-21 - ntop.org
--

local json = require "dkjson"

-- ##############################################

local recipients = {}

-- ##############################################

function recipients:create(args)
   if args then
      -- We're being sub-classed
      if not args.key then
	 return nil
      end
   end

   local this = args or {key = "base", enabled = true}

   setmetatable(this, self)
   self.__index = self

   if args then
      -- Initialization is only run if a subclass is being instanced, that is,
      -- when args is not nil
      this:_initialize()
   end

   return this
end

-- ##############################################

-- @brief Performs initialization operations at the time when the instance is created
function recipients:_initialize()
   -- Possibly create a default recipient (if not existing)
end

-- ##############################################

-- @brief Dispatches a store `notification` to the recipient
-- @param notification A JSON string with all the alert information
-- @return true If the dispatching has been successfull, false otherwise
function recipients:dispatch_store_notification(notification)
   return self.enabled
end

-- ##############################################

-- @brief Dispatches a trigger `notification` to the recipient
-- @param notification A JSON string with all the alert information
-- @return true If the dispatching has been successfull, false otherwise
function recipients:dispatch_trigger_notification(notification)
   return self.enabled
end

-- ##############################################

-- @brief Dispatches a release `notification` to the recipient
-- @param notification A JSON string with all the alert information
-- @return true If the dispatching has been successfull, false otherwise
function recipients:dispatch_release_notification(notification)
   return self.enabled
end

-- ##############################################

-- @brief Process notifications previously dispatched with one of the dispatch_{store,trigger,release}_notification
function recipients:process_notifications()
   return self.enabled
end

-- ##############################################

return recipients
