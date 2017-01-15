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

function loadHostBlackList(force_purge)
   local bl = ntop.getCache("ntopng.prefs.host_blacklist")
   local bl_enabled = ((bl == "1") or (bl == "enabled"))
   local should_reload = ((bl_enabled) or (force_purge))

   if should_reload then
      ntop.allocHostBlacklist()
   end

   if bl_enabled then
      for _,url in pairs(blacklistURLs) do
	 loadBlackListFromURL(url)
      end
   end

   if should_reload then
      ntop.swapHostBlacklist()
   end
end


