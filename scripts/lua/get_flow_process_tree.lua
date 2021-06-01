--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('text/json')

local flow_key = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]
local flow = interface.findFlowByKeyAndHashId(tonumber(flow_key), tonumber(flow_hash_id))
local tree = {}

local function format_proc(name, pid)
   return string.format("%s [pid: %u]", name, pid)
end

local function proc_branch(host, proc)
   local proc_link = ntop.getHttpPrefix().."/lua/process_details.lua?pid="..proc.pid.."&pid_name="..proc.name.."&host=".. host .."&page=flows"
   local proc_leaf = {name = format_proc(proc.name, proc.pid), link = proc_link, type = "proc", children = {}}

   if (proc.pid ~= 1) and (proc.father_pid ~= nil) then
      local father_leaf = {name = format_proc(proc.father_name, proc.father_pid), type = "proc", children = {}}

      father_leaf["children"] = {proc_leaf}
      proc_leaf = father_leaf

      -- TODO: rather than simply adding the system, it would be desirable to
      -- go up into the tree recursively and get all the processes
      -- if proc.father_pid ~= 1 then
      --	 local systemd_leaf = {name = format_proc("systemd", 1), type="proc", children = {}}

      --	 systemd_leaf["children"] = {proc_leaf}
      --	 proc_leaf = systemd_leaf
      -- end
   end

   return proc_leaf
end

local function host_branch(host_name, host, procs)
   local link = hostinfo2detailsurl(host, {page = "flows"})

   local children = {}
   for _, proc in pairs(procs) do
      children[#children + 1] = proc
   end

   local branch = {name = host_name, type = "host", link = link, children = children}

   return branch
end

-- EXAMPLE of tree format
-- tree = {name = "", type="root",
--	children = {
--	   {name="client", type="host",
--	    children={{name="systemd", type="proc"}, {name="p", type="proc", children = {{name="q", type = "proc"}}}}},
--	   {name="server", type="host",
--	    children={}}}}


if flow then
   if flow.client_process and flow.server_process then
      if flow["cli.ip"] ~= flow["srv.ip"] then
	 tree = {name = "", type = "root",
		 children = {
		    host_branch(flowinfo2hostname(flow, "cli"), flow2hostinfo(flow, "cli"),
				{proc_branch(flow["cli.ip"], flow.client_process)}),
		    host_branch(flowinfo2hostname(flow, "srv"), flow2hostinfo(flow, "srv"),
				{proc_branch(flow["srv.ip"], flow.server_process)})
		 }
	 }
      else
	 tree = host_branch(flowinfo2hostname(flow, "cli"), flow2hostinfo(flow, "cli"),
			    {proc_branch(flow["cli.ip"], flow.client_process),
			     proc_branch(flow["srv.ip"], flow.server_process)})
      end

   elseif flow.client_process then
      tree = host_branch(flowinfo2hostname(flow, "cli"), flow2hostinfo(flow, "cli"),
			 {proc_branch(flow["cli.ip"], flow.client_process)})

   elseif flow.server_process then
      tree = host_branch(flowinfo2hostname(flow, "srv"), flow2hostinfo(flow, "srv"),
			 {proc_branch(flow["srv.ip"], flow.server_process)})
   end
end

print(json.encode(tree))
