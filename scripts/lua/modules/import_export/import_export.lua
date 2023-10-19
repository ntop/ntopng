--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()

-- ##############################################

local import_export = {}

-- ##############################################

function import_export:create(args)
   if args then
      -- We're being sub-classed
      if not args.key then
	 return nil
      end
   end

   local this = args or { key = "import_export" }

   setmetatable(this, self)
   self.__index = self

   return this
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function import_export:import(conf)
   --
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function import_export:export()
   local conf = {}
   return conf
end

-- ##############################################

-- @brief Reset configuration
function import_export:reset()
   --
end

-- ##############################################

return import_export
