--
-- (C) 2016-17 - ntop.org
--

local blacklistURLs = {
   "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"
}

-- ##################################################################

local function loadBlackListFromURL(url)
   local resp = ntop.httpGet(url)

   if(resp ~= nil) then
      local content = resp["CONTENT"]
      local line
      local lines = string.split(content, "\n")

      for _,line in pairs(lines) do
	 line = trimSpace(line)
	 if((string.len(line) > 0) and not(string.starts(line, "#"))) then
	    -- print("Loading "..line.."\n")
	    ntop.addToHostBlacklist(line)
	 end
      end
   end
end

-- ##################################################################

function loadHostBlackList()
   local bl = ntop.getCache("ntopng.prefs.host_blacklist")

   if((bl == "1") or (bl == "enabled")) then
      ntop.allocHostBlacklist()
      
      for _,url in pairs(blacklistURLs) do
	 loadBlackListFromURL(url)
      end
      
      ntop.swapHostBlacklist()
   end
end


