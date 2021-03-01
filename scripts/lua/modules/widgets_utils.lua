--
-- (C) 2020 - ntop.org
--

local widgets_utils = {}

require ("lua_utils")
local json = require("dkjson")
local rest_utils = require "rest_utils"
local datasources_utils = require("datasources_utils")
local datasource_keys = require "datasource_keys"

-------------------------------------------------------------------------------
-- Answer to a widget request
-- @param widget Is a widget defined above
-- @param params Is a table which contains overriding params.
--               Example: {ifid, key, metric, begin_time, end_time, schema }
-------------------------------------------------------------------------------
function widgets_utils.generate_response(widget, params)
   local ds = datasources_utils.get(widget.ds_hash)
   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/scripts/lua/datasources/?.lua;" .. package.path

   -- Remove trailer .lua from the origin
   local origin = ds.origin:gsub("%.lua", "")

   -- io.write("Executing "..origin..".lua\n")
   --tprint(widget)

   -- Call the origin to return
   local response = require(origin)

   if((response == nil) or (response == true)) then
      response = "{}"
   else
      response = response:getData(widget.type)
   end

   return json.encode({
	 widgetName = widget.name,
	 widgetType = widget.type,
	 dsRetention = ds.data_retention * 1000, -- msec
	 success = true,
	 data = response
   })
end

-- @brief Generate a rest response for the widget, by requesting data from multiple datasources and filtering it
function widgets_utils.rest_response()
   if not _POST or table.len(_POST) == 0 then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   -- Missing transformation
   if not _POST["transformation"] then
      rest_utils.answer(rest_utils.consts.err.widgets_missing_transformation)
      return
   end

   -- Check for datasources
   if not _POST["datasources"] or table.len(_POST["datasources"]) == 0 then
      rest_utils.answer(rest_utils.consts.err.widgets_missing_datasources)
      return
   end

   local datasources_data = {}
   for _, datasource in pairs(_POST["datasources"]) do
      -- Check if the datasource is valid and existing
      if not datasource.ds_type then
	 rest_utils.answer(rest_utils.consts.err.widgets_missing_datasource_type)
	 return
      end

      if not datasource_keys[datasource.ds_type] then
	 rest_utils.answer(rest_utils.consts.err.widgets_unknown_datasource_type)
	 return
      end

      -- Get the actual datasource key
      local datasource_key = datasource_keys[datasource.ds_type]
      -- Fetch the datasource class using the key
      local datasource_type = datasources_utils.get_source_type_by_key(datasource_key)
      local datasource_instance = datasource_type.new()

      -- Parse params into the instance
      if not datasource_instance:read_params(datasource.params) then
	 rest_utils.answer(rest_utils.consts.err.widgets_missing_datasource_params)
	 return
      end

      -- Fetch according to datasource parameters received via REST
      datasource_instance:fetch()

      -- Transform the data according to the requested transformation
      -- and set the transformed data as result
      local transformed_data = datasource_instance:transform(_POST["transformation"])

      datasources_data[#datasources_data + 1] = {
	 datasource = datasource,
	 metadata = datasource_instance:get_metadata(),
	 data = transformed_data
      }
   end
   
   rest_utils.answer(rest_utils.consts.success.ok, {
       datasources = datasources_data,
       axes = {}
   })
end

return widgets_utils
