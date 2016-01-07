--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

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

if action == nil then
	return "{}"
elseif action == "schedule" then
	local schedule_url = "https://"..nbox_host
	schedule_url = schedule_url.."/ntop-bin/sudowrapper_external.cgi?script=npcapextract_external.cgi"
	schedule_url = schedule_url.."&ifname="..ifname.."&begin="..epoch_begin.."&end="..epoch_end
	io.write(schedule_url..'\n')
	local resp = ntop.httpGet(schedule_url, nbox_user, nbox_password, 10)
	tprint(resp)
	if resp["CONTENT"] ~= nil then
		print(resp["CONTENT"])
	else
		print("{}")
	end
end


