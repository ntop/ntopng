--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"


interface.select(ifname)

local nbox_host = ntop.getCache("ntopng.prefs.nbox_host")
local nbox_user = ntop.getCache("ntopng.prefs.nbox_user")
local nbox_password = ntop.getCache("ntopng.prefs.nbox_password")
if((nbox_host == nil) or (nbox_host == "")) then nbox_host = "localhost" end
if((nbox_user == nil) or (nbox_user == "")) then nbox_user = "nbox" end
if((nbox_password == nil) or (nbox_password == "")) then nbox_password = "nbox" end

-- Table parameters
action     = _GET["action"]
epoch_begin= _GET["epoch_begin"]
epoch_end  = _GET["epoch_end"]
task_id    = _GET["task_id"]

if action == nil then
	return "{}"
elseif action == "schedule" then
	local schedule_url = "https://"..nbox_host
	schedule_url = schedule_url.."/ntop-bin/sudowrapper_external.cgi?script=npcapextract_external.cgi"
	schedule_url = schedule_url.."&ifname="..ifname.."&begin="..epoch_begin.."&end="..epoch_end
	--io.write(schedule_url..'\n')
	local resp = ntop.httpGet(schedule_url, nbox_user, nbox_password, 10)
	-- tprint(resp)
	sendHTTPHeader('text/html; charset=iso-8859-1')
	if resp ~= nil and resp["CONTENT"] ~= nil then
		print(resp["CONTENT"])
	else
		print("{}")
	end
elseif action == "status" then
	local status_url = "https://"..nbox_host
	status_url = status_url.."/ntop-bin/check_status_tasks_external.cgi"
	local resp = ntop.httpGet(status_url, nbox_user, nbox_password, 10)
	--tprint(resp)
	sendHTTPHeader('text/html; charset=iso-8859-1')
	if resp ~= nil and resp["CONTENT"] ~= nil then
		local content = resp["CONTENT"]
		-- resp is not valid json: is buggy @ 08-01-2016:
		-- this is an example { "result" : "OK", "tasks" : { {"task_id" : "1_1452012196" , "status" : "done" } , {"task_id" : "1_1452012274" , "status" : "done" }}}
		-- double {{ and }} are not allowed and we must convert them to [{ and }] respectively
		content = string.gsub(content, "%s*","")
		content = string.gsub(content, "{%s*{","[{")
		content = string.gsub(content, "}%s*}","}]")
		--tprint(content)
		print(content)
	else
		print('{"tasks":[]}')
	end
elseif action == "download" then
	local download_url = "https://"..nbox_host
	download_url = download_url.."/ntop-bin/sudowrapper.cgi"
	download_url = download_url.."?script=n2disk_filemanager.cgi&opt=download_pcap&dir=/storage/n2disk/&pcap_name=/storage/n2disk/"
	download_url = download_url..task_id..".pcap"
	local resp = ntop.httpGet(download_url, nbox_user, nbox_password, 10)
	-- tprint(resp)
	if resp ~= nil and resp["CONTENT"] ~= nil then
		sendHTTPHeader(resp["CONTENT_TYPE"])
		print(resp["CONTENT"])
	else
		sendHTTPHeader('text/html; charset=iso-8859-1')
		print("{}")
	end
end


