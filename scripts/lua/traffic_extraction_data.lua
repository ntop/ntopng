--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local format_utils = require "format_utils"
local recording_utils = require "recording_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

if not recording_utils.isAvailable() then
  return
end

-- ################################################
-- Table parameters

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

-- ################################################
--  Sorting and Pagination

local sortPrefs = "traffic_extraction_jobs"

if isEmptyString(sortColumn) or sortColumn == "column_" then
   sortColumn = getDefaultTableSort(sortPrefs)
elseif sortColumn ~= "" then
   tablePreferences("sort_"..sortPrefs, sortColumn)
end

if isEmptyString(_GET["sortColumn"]) then
   sortOrder = getDefaultTableSortOrder(sortPrefs, true)
end

if _GET["sortColumn"] ~= "column_" and _GET["sortColumn"] ~= "" then
   tablePreferences("sort_order_"..sortPrefs, sortOrder, true)
end

if currentPage == nil then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if perPage == nil then
   perPage = 10
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number_policies", perPage)
end

local to_skip = (currentPage-1) * perPage

if sortOrder == "desc" then sOrder = rev_insensitive else sOrder = asc_insensitive end

-- ################################################

interface.select(ifname)

local ifstats = interface.getStats()

local jobs = recording_utils.getExtractionJobs(ifstats.id)
local num_results = 0

local sorter = {}
for id,job in pairs(jobs) do
  if sortColumn == "column_id" then
    sorter[id] = job.id
  elseif sortColumn == "column_extracted_packets" then
    sorter[id] = job.extracted_pkts
  elseif sortColumn == "column_extracted_bytes" then
    sorter[id] = job.extracted_bytes
  elseif sortColumn == "column_status" then
    sorter[id] = job.status
  else -- sortColumn == column_job_time
    sorter[id] = job.time
  end

  num_results = num_results + 1
end

local res = {}
local cur_num = 0
for id, _ in pairsByValues(sorter, sOrder) do
  cur_num = cur_num + 1
  if cur_num <= to_skip then
    goto continue
  elseif cur_num > to_skip + perPage then
    break
  end

  local job = jobs[id]

  local action_links = ""
  local job_files = 0

  if job.status == "completed" or job.status == "stopped" then
    job_files = recording_utils.getJobFiles(job.id)
    job_files = #job_files
  end

  local status_desc = i18n("traffic_recording."..job.status) 
  if job.status == "failure" then
    local error_desc
    if job.error_code == 2 or job.error_code == 3 then error_desc = i18n("traffic_recording.err_alloc")
    elseif job.error_code == 4 or job.error_code == 6 then error_desc = i18n("traffic_recording.err_open")
    elseif job.error_code == 5 then error_desc = i18n("traffic_recording.err_filter")
    elseif job.error_code == 9 then error_desc = i18n("traffic_recording.err_stuck")
    else error_desc = i18n("traffic_recording.err_unknown")
    end
    status_desc = status_desc.." ("..error_desc..")"
  end

  local chart_link = nil
  if not isEmptyString(job.chart_url) then
    chart_link = '<a href="'.. job.chart_url ..'"><i class="fas fa-lg fa-chart-area"></i></a>'
  end

  local bpf_filter = "-"
  if not isEmptyString(job.filter) then
    bpf_filter = shortenString(job.filter, 45)

    if bpf_filter ~= job.filter then
      -- string was shortened, show full filter into a tooltip
      bpf_filter = '<span title="'.. job.filter ..'">' .. bpf_filter .. '</span>'
    end
  end

  res[#res + 1] = { 
    column_id = job.id, 
    column_job_time = format_utils.formatEpoch(job.time),
    column_job_files = job_files,
    column_status = status_desc,
    column_chart = chart_link,
    column_status_raw = job.status,
    column_begin_time = format_utils.formatEpoch(job.time_from),
    column_end_time = format_utils.formatEpoch(job.time_to),
    column_bpf_filter = bpf_filter,
    column_extracted_packets = ternary(job.status == "completed" and job.extracted_pkts, formatPackets(job.extracted_pkts), "-"),
    column_extracted_bytes = ternary(job.status == "completed" and job.extracted_bytes, bytesToSize(job.extracted_bytes), "-"),
  }

  ::continue::
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = num_results
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
