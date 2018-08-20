--
-- (C) 2016-18 - ntop.org
--

-- NOTE: see lists_utils.lua

local blacklist_utils = {}

local blacklistURLs = {
   "http://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"
}

-- ##################################################################

local function loadBlackListFromURL(url)
   local resp = ntop.httpGet(url)

   if((resp ~= nil) and (resp["CONTENT"] ~= nil)) then
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

local function shouldReload(force_purge)
   return blacklist_utils.isBlacklistEnabled() or (force_purge)
end

-- ##################################################################

function blacklist_utils.isBlacklistEnabled()
   local bl = ntop.getPref("ntopng.prefs.host_blacklist")
   return (bl ~= "0")
end

-- ##################################################################

function blacklist_utils.beginLoad(force_purge)
   local bl = ntop.getCache("ntopng.prefs.host_blacklist")
   local bl_enabled = ((bl == "1") or (bl == "enabled"))

   if shouldReload(force_purge) then
      ntop.allocHostBlacklist()
   end

   if blacklist_utils.isBlacklistEnabled() then
      for _,url in pairs(blacklistURLs) do
	 loadBlackListFromURL(url)
      end
   end
end

-- ##################################################################

function blacklist_utils.endLoad(force_purge)
   if shouldReload(force_purge) then
      ntop.swapHostBlacklist()
   end
end

return blacklist_utils
