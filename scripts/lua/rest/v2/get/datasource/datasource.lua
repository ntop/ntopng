--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datasources/?.lua;" .. package.path

local json = require "dkjson"
local rest_utils = require "rest_utils"
local template = require "resty.template"
-- Import the classes library.
local classes = require "classes"

-- ##############################################

local datasource = classes.class()

-- ##############################################

-- This is the base REST prefix for all the available datasources
datasource.BASE_REST_PREFIX = "/lua/rest/v2/get/datasource/"

-- ##############################################

-- @brief Base class constructor
function datasource:init()
   self._dataset_params     = {}  -- Holds per-dataset params
   self._datamodel_instance = nil -- Instance of the datamodel holding data for each dataset
end

-- ##############################################

-- @brief Parses params
-- @param params_table A table with submitted params
-- @return True if parameters parsing is successful, false otherwise
function datasource:read_params(params_table)
   if not params_table then
      self.parsed_params = nil
      return false
   end

   self.parsed_params = {}
   for _, param in pairs(self.meta.params or {}) do
      local parsed_param = params_table[param]

      -- Assumes all params mandatory and not empty
      -- May override this behavior in subclasses
      if isEmptyString(parsed_param) then
	 -- Reset any possibly set param
	 self.parsed_params = nil

	 return false
      end

      self.parsed_params[param] = parsed_param
   end

   -- Ok, parsin has been successful
   return true
end

-- ##############################################

-- @brief Parses params submitted along with the REST endpoint request. If parsing fails, a REST error is sent.
-- @param params_table A table with submitted params, either _POST or _GET
-- @return True if parameters parsing is successful, false otherwise
function datasource:_rest_read_params(params_table)
   if not self:read_params(params_table) then
      rest_utils.answer(rest_utils.consts.err.widgets_missing_datasource_params)
      return false
   end

   return true
end

-- ##############################################

-- @brief Send datasource data via REST
function datasource:rest_send_response()
   -- Make sure this is a direct REST request and not just a require() that needs this class
   if not _SERVER -- Not executing a Lua script initiated from the web server (i.e., backend execution)
   or not _SERVER["URI"] -- Cannot reliably determine if this is a REST request
   or not _SERVER["URI"]:starts(datasource.BASE_REST_PREFIX) -- Web Lua script execution but not for this REST endpoint
   then
      -- Don't send any REST response
      return
   end

   if not self:_rest_read_params(_POST) then
      -- Params parsing has failed, error response already sent by the caller
      return
   end

   self:fetch()

   rest_utils.answer(
      rest_utils.consts.success.ok,
      self.datamodel_instance:get_data()
   )
end

-- ##############################################

-- @brief Deserializes REST endpoint response into an internal datamodel
-- @param rest_response_data Response data as obtained from the REST call
function datasource:deserialize(rest_response_data)
   if rest_response_data and rest_response_data.RESPONSE_CODE == 200 then
      local data = json.decode(rest_response_data.CONTENT)
      local when = os.time()

      if data and data.rc == rest_utils.consts.success.ok.rc then
	 self.datamodel_instance = self.meta.datamodel:new(data.rsp.header)

	 for _, row in ipairs(data.rsp.rows) do
	    self.datamodel_instance:appendRow(when, data.rsp.header, row)
	 end
      end
   end
end

-- ##############################################

-- @brief Returns instance metadata, which depends on the current instance and parsed_params
function datasource:get_metadata()
   local res = {}

   -- Render a url with submitted parsed_params
   if self.meta.url then
      local url_func = template.compile(self.meta.url, nil, true)
      local url_rendered = url_func({
	    params = self.parsed_params,
      })

      res["url"] = url_rendered
   end

   return res
end

-- ##############################################

-- @brief Transform data according to the specified transformation
-- @param data The data to be transformed
-- @param transformation The transformation to be applied
-- @return transformed data
function datasource:transform(transformation)
   return self.datamodel_instance:transform(transformation)
end

-- ##############################################

return datasource

-- ##############################################
