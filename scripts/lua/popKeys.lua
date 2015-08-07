--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"


function cleanName(name)
   n = string.gsub(name, "'", "_")
   -- Cut the name at 128 chars
   n = string.sub(n, 1, 128)
   return(n)
end

interfaces_id     = 0
interfaces_hash   = { }
function interface2id(name)
   if(interfaces_hash[name] == nil) then
      id = interfaces_id
      interfaces_hash[name] = id
      interfaces_id = interfaces_id + 1
      return(id)
   else
      return(interfaces_hash[name])
   end
end

-- #########################

hosts_id     = 0
hosts_hash   = { }
function host2id(name)
   name = cleanName(name)
   if(hosts_hash[name] == nil) then
      id = hosts_id
      hosts_hash[name] = id
      hosts_id = hosts_id + 1
      return(id)
   else
      return(hosts_hash[name])
   end
end

-- #########################

sendHTTPHeader('text/html; charset=iso-8859-1')

begin = os.clock()
t = os.time() -- -86400
when = os.date("%y%m%d", t)
key_name = when..".keys"

--print(key_name.."\n")

local debug = true
local delete_keys = true

dump_dir = fixPath(dirs.workingdir .. "/datadump/")
ntop.mkdir(dump_dir)

fname = dump_dir .. "20".. when
activities_name = fname  .."_activities.csv"
contacts_name = fname  .."_contacts.csv"

hosts_name = fname  .."_hosts.csv"
interfaces_name = fname  .."_interfaces.csv"

tables_name = fname  ..".sql"

activities = io.open(activities_name, "w")
contacts = io.open(contacts_name, "w")
hosts = io.open(hosts_name, "w")
interfaces = io.open(interfaces_name, "w")
tables = io.open(tables_name, "w")

print("Please wait: we are dumping data into<ul>\n")
print("<li>"..activities_name.."\n")
print("<li>"..contacts_name.."\n")
print("<li>"..hosts_name.."\n")
print("<li>"..interfaces_name.."\n")
print("<li>"..tables_name.."\n")

print("</ul>\n")

interfaces:write("# idx | interface\n")
hosts:write("# idx | name\n")
contacts:write("# contacted_by=0, contacted_peers=1\n")

contact_idx = 0
idx = 0
repeat
   key = ntop.setPopCache(key_name)
   if(debug) then print("====> "..key_name.."<br>\n") end
   if((key == nil) or (key == "")) then break end

   if(debug) then print("=> "..key.."<br>\n") end
   k1 = when.."|"..key.."|contacted_by"
   v1 = ntop.getHashKeysCache(k1)
   if(v1 ~= nil) then
      res = split(k1, "|")

      if(res[2] == "host_contacts") then 
	 r = 0 
      else
	 -- aggregations
	 r = 1 
      end
      name = host2id(res[4])
      activities:write(idx..",".. interface2id(res[3])..","..name..",".. r.."\n")

      if(debug) then print("-> (1)"..k1.."\n") end
      for k,_ in pairs(v1) do
	 v = ntop.getHashCache(k1, k)
	 res = split(k, "@")
	 if(debug) then print("\t"..k .. "=" .. v.. "\n") end
	 if((res[1] ~= nil) and (res[2] ~= nil) and (v ~= nil)) then
	    contacts:write(contact_idx..","..idx..",0,"..host2id(res[1])..",".. res[2]..",".. v.."\n")
	    contact_idx = contact_idx + 1
	 end
	 if(delete_keys) then ntop.delHashCache(k1, k) end
      end

      idx = idx + 1
   end

   k2 = when.."|"..key.."|contacted_peers"
   v2 = ntop.getHashKeysCache(k2)
   if(v2 ~= nil) then
      res = split(k1, "|")

      if(res[2] == "host_contacts") then 
	 r = 0 
      else
	 -- aggregations
	 r = 1 
      end
      name = host2id(res[4])
      activities:write(idx..",".. interface2id(res[3])..",".. name ..",".. r .."\n")

      if(debug) then print("-> (2)"..k2.."\n") end
      for k,v in pairs(v2) do
	 v = ntop.getHashCache(k2, k)
	 res = split(k, "@")
	 if(debug) then print("\t"..k .. "=" .. v.. "\n") end
	 if((res[1] ~= nil) and (res[2] ~= nil) and (v ~= nil)) then
	    contacts:write(contact_idx..","..idx..",1,"..host2id(res[1])..",".. res[2]..",".. v.."\n")
	    contact_idx = contact_idx + 1
	 end
	 if(delete_keys) then ntop.delHashCache(k2, k) end
      end

      idx = idx + 1
   end

   until(key == "")

-- Dump Interfaces
print(interfaces_id.." interfaces found<br>\n")
for iface,id in pairs(interfaces_hash) do
   interfaces:write(id..","..iface.."\n")
end


-- Dump Hosts
print(hosts_id.." hosts found<br>\n")
for host,id in pairs(hosts_hash) do
   hosts:write(id..","..host.."\n")
end

contacts:close()
activities:close()
hosts:close()

-- #########################################################

tables:write("CREATE DATABASE IF NOT EXISTS `20"..when.."`;\nUSE `20"..when.."`;\n\n")
tables:write("\nCREATE TABLE IF NOT EXISTS `interfaces` (\n`idx` int(11) NOT NULL,\n`interface_name` VARCHAR(32) NOT NULL,\nPRIMARY KEY (`idx`)\n) ENGINE=InnoDB DEFAULT CHARSET=latin1;\n\n")
tables:write("\nCREATE TABLE IF NOT EXISTS `hosts` (\n`idx` int(11) NOT NULL,\n`host_name` VARCHAR(128) NOT NULL,\nPRIMARY KEY (`idx`)\n) ENGINE=InnoDB DEFAULT CHARSET=latin1;\n\n")
tables:write("\nCREATE TABLE IF NOT EXISTS `activities` (\n`idx` int(11) NOT NULL,\n`interface_idx` int(11) NOT NULL,\n`host_idx` int(11) NOT NULL,\n`type` INT(8) NOT NULL,\nPRIMARY KEY (`idx`)\n) ENGINE=InnoDB DEFAULT CHARSET=latin1;\n\n")
tables:write("\nCREATE TABLE IF NOT EXISTS `contacts` (\n`idx` int(11) NOT NULL,\n`activity_idx` int(11) NOT NULL,\n`contact_type` int(11) NOT NULL,\n`host_idx` int(11) NOT NULL,\n`contact_family` int(8) DEFAULT NULL,\n`num_contacts` int(8) NOT NULL,\nPRIMARY KEY (`idx`)\n) ENGINE=InnoDB DEFAULT CHARSET=latin1;\n\n")

tables:write('mysql --local-infile=1 -u root -p<pass> 20'..when..'\n')
tables:write('LOAD data local infile "/var/tmp/ntopng/datadump/20'..when..'_interfaces.csv" INTO TABLE interfaces fields terminated by "," ignore 1 lines;\n')
tables:write('LOAD data local infile "/var/tmp/ntopng/datadump/20'..when..'_hosts.csv" INTO TABLE hosts fields terminated by "," ignore 1 lines;\n')
tables:write('LOAD data local infile "/var/tmp/ntopng/datadump/20'..when..'_activities.csv" INTO TABLE activities fields terminated by "," ignore 1 lines;\n')
tables:write('LOAD data local infile "/var/tmp/ntopng/datadump/20'..when..'_contacts.csv" INTO TABLE contacts fields terminated by "," ignore 1 lines;\n')

tables:close()

sec = os.clock() - begin
print(string.format("Elapsed time: %.2f min\n", sec/60).."<br>\n")
print("\nDone.\n")

-- redis-cli KEYS "131129|*" | xargs redis-cli DEL
