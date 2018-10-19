--
-- (C) 2013-18 - ntop.org
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

local sorter = {}
for id,job in pairs(jobs) do
  sorter[id] = job.time
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

  if job.status == "processing" then
    action_links = action_links.."<a onclick='stopJob("..job.id..")' style='cursor: pointer'><span class=\"label label-danger\">"..i18n("stop").."</span></a>"
  else
    action_links = action_links.."<a onclick='deleteJob("..job.id..")' style='cursor: pointer'><span class=\"label label-danger\">"..i18n("delete").."</span></a>"
  end

  if job.status == "completed" or job.status == "stopped" then
    local job_files = recording_utils.getJobFiles(job.id)
    if #job_files > 1 then
      local links = "<ul>"
      for file_id = 1,#job_files do
        links = links.."<li><a href=\\'"..ntop.getHttpPrefix().."/lua/get_extracted_traffic.lua?job_id="..job.id.."&file_id="..file_id.."\\'>"..i18n("download").." Pcap "..file_id.."</a></li>"
      end
      links = links.."<ul>"
      action_links = action_links.." <a onclick=\"downloadJobFiles('"..links.."')\" style='cursor: pointer'><span class=\"label label-info\">"..i18n("download").."</span></a>"
    elseif #job_files == 1 then
      action_links = action_links.." <a href="..ntop.getHttpPrefix().."/lua/get_extracted_traffic.lua?job_id="..job.id.."><span class=\"label label-info\">"..i18n("download").."</span></a>"
    end
  end

  res[#res + 1] = { 
    column_id = job.id, 
    column_job_time = format_utils.formatEpoch(job.time), 
    column_status = i18n("traffic_recording."..job.status), -- job.error_code 
    column_begin_time = format_utils.formatEpoch(job.time_from),
    column_end_time = format_utils.formatEpoch(job.time_to),
    column_bpf_filter = ternary(isEmptyString(job.filter), "-", job.filter),
    column_extracted_packets = ternary(job.status == "completed" and job.extracted_pkts, formatPackets(job.extracted_pkts), "-"),
    column_extracted_bytes = ternary(job.status == "completed" and job.extracted_bytes, bytesToSize(job.extracted_bytes), "-"),
    column_actions = action_links
  }

  ::continue::
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = #res
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
