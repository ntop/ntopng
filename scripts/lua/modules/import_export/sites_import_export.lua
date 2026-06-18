--
-- (C) 2019-26 - ntop.org
--
-- Sites import/export.
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"
local import_export = require "import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local site_utils = require "site_utils"

local sites_import_export = {}

-- CSV header (also the canonical column order when no header is present)
local CSV_HEADER = "name,description,latitude,longitude"

-- ##############################################
-- Private CSV helpers

-- Escape a single CSV field: wrap in double quotes if it
-- contains a comma, quote or newline, doubling any embedded quote.
local function csv_escape(value)
	value = tostring(value or "")
	if value:find('[,"\r\n]') then
		value = '"' .. value:gsub('"', '""') .. '"'
	end
	return value
end

-- Parse a single CSV line into an array of fields. Handles quoted fields,
-- embedded commas and escaped double quotes (""). A trailing CR is stripped to
-- support CRLF line endings.
local function parse_csv_line(line)
	line = line:gsub("\r$", "")

	local fields = {}
	local field = ""
	local in_quotes = false
	local i = 1
	local len = #line

	while i <= len do
		local c = line:sub(i, i)

		if in_quotes then
			if c == '"' then
				-- Either the closing quote or an escaped quote ("")
				if line:sub(i + 1, i + 1) == '"' then
					field = field .. '"'
					i = i + 1
				else
					in_quotes = false
				end
			else
				field = field .. c
			end
		else
			if c == '"' then
				in_quotes = true
			elseif c == ',' then
				fields[#fields + 1] = field
				field = ""
			else
				field = field .. c
			end
		end

		i = i + 1
	end

	fields[#fields + 1] = field
	return fields
end

-- ##############################################

-- Configuration backup/restore interface
function sites_import_export:create(args)
	-- Instance of the base class
	local _sites_import_export = import_export:create()

	-- Subclass using the base class instance
	self.key = "sites"
	-- self is passed as argument so it will be set as base class metatable
	-- and this will actually make it possible to override functions
	local _sites_import_export_instance = _sites_import_export:create(self)

	-- Return the instance
	return _sites_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true on success, or a key "err"
--         set to one of rest_utils.consts.err on failure.
function sites_import_export:import(conf)
	local err = site_utils.restore(conf)

	local res = {}
	if err then
		res.err = err
	else
		res.success = true
	end

	return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current Sites configuration (definitions + network associations)
function sites_import_export:export(name)
	return site_utils.export()
end

-- ##############################################

-- @brief Reset configuration (remove every user-defined Site)
function sites_import_export:reset()
	site_utils.remove_all_sites()
end

-- ##############################################

-- Returns a CSV string with all the user-defined Sites.
-- The system-reserved Default site is skipped since it cannot be re-created.
-- NOTE: the header row (CSV_HEADER) is intentionally NOT emitted; the export
-- contains data rows only, in the canonical column order
-- (name,description,latitude,longitude). On import the header is still accepted
-- if present (see import_csv), so externally edited files keep working.
function sites_import_export.export_csv()
	local sites = site_utils.getSites()
	local lines = {}

	for _, site in ipairs(sites) do
		if not site.reserved then
			lines[#lines + 1] = table.concat({
				csv_escape(site.name),
				csv_escape(site.description),
				csv_escape(site.latitude or 0),
				csv_escape(site.longitude or 0),
			}, ",")
		end
	end

	-- CRLF for maximum compatibility with spreadsheet applications
	return table.concat(lines, "\r\n") .. "\r\n"
end

-- ##############################################

-- Imports Sites from a CSV string.
-- The CSV may optionally contain a header row (name,description,latitude,longitude);
-- if no header is found the columns are assumed to be in that fixed order.
-- Each row is added through site_utils.addSite(), so the same validation as the
-- manual creation applies. Rows that fail validation (e.g. duplicated names) are
-- skipped and reported in the feedback.
function sites_import_export.import_csv(csv_string)
	if isEmptyString(csv_string) then
		return rest_utils.consts.err.add_site_failed, { feedback = "No CSV data provided" }
	end

	-- Split the input into non-empty rows
	local rows = {}
	for line in (csv_string .. "\n"):gmatch("(.-)\n") do
		if not isEmptyString(trimSpace(line)) then
			rows[#rows + 1] = parse_csv_line(line)
		end
	end

	if #rows == 0 then
		return rest_utils.consts.err.add_site_failed, { feedback = "Empty CSV" }
	end

	-- Detect an (optional) header row and build the column -> index map
	local col = {}
	local has_header = false
	for idx, name in ipairs(rows[1]) do
		local key = trimSpace(tostring(name)):lower()
		if key == "name" or key == "description" or key == "latitude" or key == "longitude" then
			col[key] = idx
			has_header = true
		end
	end

	local start_row = 1
	if has_header then
		start_row = 2 -- skip the header
	else
		-- No header: assume the canonical fixed order
		col = { name = 1, description = 2, latitude = 3, longitude = 4 }
	end

	local added = 0
	local skipped = 0
	local duplicates = 0
	local errors = {}

	-- Names already present (case-insensitive). Used to skip duplicates
	-- silently instead of reporting them as errors. The set is updated as new
	-- Sites are added, so duplicates *within* the same CSV are skipped too.
	local existing_names = {}
	for _, s in ipairs(site_utils.getSites()) do
		existing_names[tostring(s.name):lower()] = true
	end

	for r = start_row, #rows do
		local fields = rows[r]

		local site = {
			site_name = trimSpace(fields[col.name] or ""),
			site_description = trimSpace(fields[col.description] or ""),
			latitude = fields[col.latitude] or 0,
			longitude = fields[col.longitude] or 0,
		}

		-- Silently ignore completely empty rows
		if not isEmptyString(site.site_name) then
			local name_key = site.site_name:lower()

			if existing_names[name_key] then
				-- Site already present (in Redis or added earlier in this
				-- batch): not an error, just skip it silently
				duplicates = duplicates + 1
			else
				local rc, msg = site_utils.addSite(site)
				if rc == rest_utils.consts.success.ok then
					added = added + 1
					existing_names[name_key] = true
				else
					-- Real validation error (invalid coordinates, illegal
					-- name, ...): report it
					skipped = skipped + 1
					errors[#errors + 1] = site.site_name .. ": " .. (msg or "error")
				end
			end
		end
	end

	local feedback = string.format("Imported %d site(s)", added)
	if duplicates > 0 then
		feedback = feedback .. string.format(", %d already existing (skipped)", duplicates)
	end
	if skipped > 0 then
		feedback = feedback .. string.format(", %d skipped", skipped)
	end
	if #errors > 0 then
		feedback = feedback .. " (" .. table.concat(errors, "; ") .. ")"
	end

	-- Treat the import as a failure only if nothing was imported AND there was
	-- nothing to skip as a duplicate, i.e. the file had no usable rows or only
	-- invalid ones. Re-importing an already-present configuration (all
	-- duplicates) is a no-op, not a failure.
	if added == 0 and duplicates == 0 then
		return rest_utils.consts.err.add_site_failed, { feedback = feedback }
	end

	return rest_utils.consts.success.ok, { feedback = feedback }
end

-- ##############################################

return sites_import_export
