--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datasources/?.lua;" .. package.path

local json = require "dkjson"
local rest_utils = require "rest_utils"
-- Import the classes library.
local classes = require "classes"

-- ##############################################

local datasource = classes.class()

-- ##############################################

-- @brief Base class constructor
function datasource:init()
end

-- ##############################################

-- @brief Deserializes REST endpoint response into an internal datamodel
-- @param rest_response_data Response data as obtained from the REST call
function datasource:deserialize(rest_response_data)
   if rest_response_data and rest_response_data.RESPONSE_CODE == 200 then
      local data = json.decode(rest_response_data.CONTENT)
      local when = os.time()

      if data and data.rc == rest_utils.consts.success.ok.rc then
	 self.m = self.meta.datamodel:create(data.rsp.header)

	 for _, row in ipairs(data.rsp.rows) do
	    self.m:appendRow(when, data.rsp.header, row)
	 end
      end
   end
end

-- ##############################################

-- @brief Transform data according to the specified transformation
-- @param data The data to be transformed
-- @param transformation The transformation to be applied
-- @return transformed data
function datasource:transform(transformation)
   return self.m:getData(transformation)
end

-- ##############################################

return datasource

-- ##############################################
