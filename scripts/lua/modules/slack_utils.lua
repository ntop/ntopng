--
-- (C) 2014-17 - ntop.org
--

dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path

require "lua_trace"

function sendSlackMessages()
  local prefs = ntop.getPrefs()
  local debug = false
  local webhook

  if(prefs.slack_enabled == false) then
    return
  end
  
  webhook = ntop.getCache("ntopng.alerts.slack_webhook")
  if((webhook == nil) or (webhook == "")) then
     return
  end

  while(true) do
    local json_message = ntop.lpopCache("ntopng.alerts.notifications_queue")

    if((json_message == nil) or (json_message == "")) then
      break
    end

    if(debug) then
      print("URL: "..webhook.." / Message: "..json_message.."\n")
    end		   

    ntop.postHTTPJsonData("", "", webhook, json_message)    
  end
end