--
-- (C) 2020-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local json = require("dkjson")
local rest_utils = require("rest_utils")
local tracker = require("tracker")

-- ##############################################

local import_export_rest_utils = {}

import_export_rest_utils.IMPORT_EXPORT_JSON_VERSION = "1.0"

-- ##############################################

-- @brief Add an envelope to the module configurations
function import_export_rest_utils.pack(modules)
	local rc = rest_utils.consts.success.ok
	local envelope = {}

	-- Add a version to the envelope to track the dump version
	envelope.version = import_export_rest_utils.IMPORT_EXPORT_JSON_VERSION

	-- Add the ntopng product version so backups can be labeled in the UI
	envelope.ntopng_version = ntop.getInfo()["version"] or ""

	-- Add the configuration of all provided module
	envelope.modules = modules

	return envelope
end

-- ##############################################

-- @brief Return the raw configuration string and a boolean indicating whether
-- it is CSV. Handles both multipart file upload (_POST["uploaded_file"]) and
-- plain POST fields (_POST["pool_CSV"] / _POST["JSON"]).
-- When reading from a file upload the temp file is deleted after reading.
function import_export_rest_utils.get_raw_conf()
	local uploaded = _POST["uploaded_file"]
	if uploaded then
		local f = io.open(uploaded, "r")
		if not f then
			return nil, false
		end
		local content = f:read("*a")
		f:close()
		ntop.unlink(uploaded)
		return content, (_POST["is_csv"] == "1")
	end
	local csv = _POST["pool_CSV"]
	if csv then
		return csv, true
	end
	return _POST["JSON"], false
end

-- ##############################################

-- @brief Convenience wrapper around get_raw_conf() for callers that only
-- handle JSON (i.e. do not need to distinguish CSV from JSON).
function import_export_rest_utils.get_json_conf()
	local content = import_export_rest_utils.get_raw_conf()
	return content
end

-- ##############################################

-- @brief Decode the configuration in json format
-- and handle the envelope. Return the list of
-- configurations for all the modules to be imported.
function import_export_rest_utils.unpack(json_conf)
	-- Decode the json
	if json_conf == nil then
		return nil
	end

	local envelope = json.decode(json_conf)

	-- Check the envelope format and version
	if
		not envelope
		or not envelope.version == nil
		or envelope.version ~= import_export_rest_utils.IMPORT_EXPORT_JSON_VERSION
	then
		return nil
	end

	return envelope.modules
end

-- ##############################################

-- @brief Import the configuration for a list of (provided)
-- module instances
function import_export_rest_utils.import(items)
	local rc = rest_utils.consts.success.ok
	local list = {}

	for _, module in ipairs(items) do
		local res = module.instance:import(module.conf)
		if res.err then
			-- DEBUG
			-- tprint(module.name.." failure ")
			-- tprint(res)

			rc = res.err
		end
		list[#list] = module.name
	end

	rest_utils.answer(rc)

	-- TRACKER HOOK
	tracker.log("import", {
		modules = list,
	})
end

-- ##############################################

-- @brief Export the configuration for a list of (provided) module instances
function import_export_rest_utils.export(instances, is_download, return_envelope)
	local rc = rest_utils.consts.success.ok
	local modules = {}
	local list = {}
	local missing_modules = {}
	local config_file_name = ""

	-- Build the list of configurations for each module
	for name, instance in pairs(instances) do
		local conf = instance:export(name)
		if not conf then
			rc = rest_utils.consts.err.internal_error
			missing_modules[#missing_modules + 1] = name
		else
			modules[name] = conf
			list[#list] = name
		end
        config_file_name = name
	end

	local envelope = import_export_rest_utils.pack(modules)

	-- This if is to keep the compatibility with old code
	if return_envelope then
		-- return the configuration
		return envelope
	else
		-- send a rest response
		if is_download then
			-- Download as file

			if rc ~= rest_utils.consts.success.ok then
				traceError(
					TRACE_ERROR,
					TRACE_CONSOLE,
					"Failure exporting configuration for " .. table.concat(missing_modules, ", ")
				)
			end

			sendHTTPContentTypeHeader("application/json", 'attachment; filename="ntopng_' .. config_file_name .. '_configuration.json"')
			print(json.encode(envelope, nil))
		else
			-- Send as REST answer
			rest_utils.answer(rc, envelope)
		end

		-- TRACKER HOOK
		tracker.log("export", {
			modules = list,
		})
	end
end

-- ##############################################

-- @brief Reset the configuration for a list of (provided) module instances
function import_export_rest_utils.reset(instances)
	local rc = rest_utils.consts.success.ok
	local list = {}

	for name, instance in pairs(instances) do
		instance:reset()
		list[#list] = name
	end

	rest_utils.answer(rc)

	-- TRACKER HOOK
	tracker.log("reset", {
		modules = list,
	})
end

-- ##############################################

return import_export_rest_utils
