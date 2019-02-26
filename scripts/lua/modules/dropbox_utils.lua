--
-- (C) 2019 - ntop.org
--

local dropbox = {}

function dropbox.getNamespaces()
   local db = interface.dumpDropboxHosts()
   local namespaces = {}
   
   for host,ns in pairs(db) do
      -- print tprint(db)
      -- tprint(ns)
      
      for k,v in pairs(ns.namespaces) do
	 -- print(host.." "..k.."<br>\n")
	 if(namespaces[k] == nil) then
	    namespaces[k] = {}
	 end
	 
	 table.insert(namespaces[k], host)
      end
   end

   return namespaces
end

function dropbox.getHostNamespaces(ipaddr)
   local ns = dropbox.getNamespaces()
   local ret = {}
   
   for _,hosts in pairs(ns) do
      local found = false
      
      for a,b in pairs(hosts) do
	 if(b == ipaddr) then
	    found = true
	 end
      end

      if(found == true) then
	 for _,c in pairs(hosts) do
	    if(c ~= ipaddr) then
	       ret[c] = true
	    end
	 end
      end
   end
   
   return ret
end

return dropbox

