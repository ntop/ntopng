--
-- (C) 2017-20 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

-- ##############################################

local base_recipients = {}

-- ##############################################

function base_recipients:create(args)
   if args then
      -- We're being sub-classed
      if not args.key then
	 return nil
      end
   end

   local this = args or {key = "base"}

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

function base_recipients:_initialize()
end

-- ##############################################

function base_recipients:dispatch_store_notification(notification)
   return true
end

-- ##############################################

function base_recipients:dispatch_trigger_notification(notification)
   return true
end

-- ##############################################

function base_recipients:dispatch_release_notification(notification)
   return true
end

-- ##############################################

function base_recipients:process_notifications()
   return true
end

-- ##############################################

return base_recipients
