--
-- (C) 2014-22 - ntop.org
--

local clock_start = os.clock()

local dscp_consts = require "dscp_consts"

-- ##############################################

function printGETParameters(get)
  for key, value in pairs(get) do
    io.write(key.."="..value.."\n")
  end
end

-- ##############################################

function printASN(asn, asname)
  asname = asname:gsub('"','')
  if(asn > 0) then
   return("<A class='ntopng-external-link' href='http://as.robtex.com/as"..asn..".html'>"..asname.." <i class='fas fa-external-link-alt fa-lg'></i></A>")
  else
    return(asname)
  end
end

-- ##############################################

function printIpVersionDropdown(base_url, page_params)
   local ipversion = _GET["version"]
   local ipversion_filter
   if not isEmptyString(ipversion) then
      ipversion_filter = '<span class="fas fa-filter"></span>'
   else
      ipversion_filter = ''
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local ipversion_params = table.clone(page_params)
   ipversion_params["version"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.ip_version")) print[[]] print(ipversion_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, ipversion_params)) print[[">]] print(i18n("flows_page.all_ip_versions")) print[[</a></li>\
         <li><a class="dropdown-item ]] if ipversion == "4" then print('active') end print[[" href="]] ipversion_params["version"] = "4"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv4_only")) print[[</a></li>\
         <li><a class="dropdown-item ]] if ipversion == "6" then print('active') end print[[" href="]] ipversion_params["version"] = "6"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv6_only")) print[[</a></li>\
      </ul>]]
end

-- ##############################################

function printVLANFilterDropdown(base_url, page_params)
   local vlans = interface.getVLANsList()

   if vlans == nil then vlans = {VLANs={}} end
   vlans = vlans["VLANs"]

   local ids = {}
   for _, vlan in ipairs(vlans) do
      ids[#ids + 1] = vlan["vlan_id"]
   end

   local vlan_id = _GET["vlan"]
   local vlan_id_filter = ''
   if not isEmptyString(vlan_id) then
      vlan_id_filter = '<span class="fas fa-filter"></span>'
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local vlan_id_params = table.clone(page_params)
   vlan_id_params["vlan"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.vlan")) print[[]] print(vlan_id_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">]] print(i18n("flows_page.all_vlan_ids")) print[[</a></li>\]]
   for _, vid in ipairs(ids) do
      vlan_id_params["vlan"] = vid
      print[[
         <li>\
           <a class="dropdown-item ]] print(vlan_id == tostring(vid) and 'active' or '') print[[" href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">VLAN ]] print(tostring(getFullVlanName(vid))) print[[</a></li>\]]
   end
   print[[

      </ul>]]
end

-- ##############################################

function printDSCPDropdown(base_url, page_params, dscp_list)
   local dscp = _GET["dscp"]
   local dscp_filter
   if not isEmptyString(dscp) then
      dscp_filter = '<span class="fas fa-filter"></span>'
   else
      dscp_filter = ''
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local dscp_params = table.clone(page_params)
   dscp_params["dscp"] = nil
   -- Used to possibly remove tcp state filters when selecting a non-TCP l4 protocol
   local dscp_params_non_filter = table.clone(dscp_params)
   if dscp_params_non_filter["dscp"] then
      dscp_params_non_filter["dscp"] = nil
   end

   local ordered_dscp_list = {}

   for key, value in pairs(dscp_list) do
      local name = dscp_consts.dscp_descr(key)
      ordered_dscp_list[name] = {}
      ordered_dscp_list[name]["id"] = key
      ordered_dscp_list[name]["count"] = value.count
   end

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.dscp")) print[[]] print(dscp_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu dropdown-menu-end scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, dscp_params_non_filter)) print[[">]] print(i18n("flows_page.all_dscp")) print[[</a></li>]]

   for key, value in pairsByKeys(ordered_dscp_list, asc) do
	  print[[<li]]

	  print([[><a class="dropdown-item ]].. (tonumber(dscp) == value.id and 'active' or '') ..[[" href="]])

	  local dscp_table = ternary(key ~= 6, dscp_params_non_filter, dscp_params)

	  dscp_table["dscp"] = value.id
	  print(getPageUrl(base_url, dscp_table))

	  print[[">]] print(key) print [[ (]] print(string.format("%d", value.count)) print [[)</a></li>]]
   end

   print[[</ul>]]
end

-- ###################################

local function sub_quotes_to_string(string_to_fix)
  return string_to_fix:gsub("%'", "&sbquo;")
end

-- ###################################

function printHostPoolDropdown(base_url, page_params, host_pool_list)
   local host_pools = require "host_pools"

   local host_pools_instance = host_pools:create()
   local host_pool = _GET["host_pool_id"]
   local host_pool_filter
   if not isEmptyString(host_pool) then
      host_pool_filter = '<span class="fas fa-filter"></span>'
   else
      host_pool_filter = ''
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local host_pool_params = table.clone(page_params)
   host_pool_params["host_pool_id"] = nil
   -- Used to possibly remove tcp state filters when selecting a non-TCP l4 protocol
   local host_pool_params_non_filter = table.clone(host_pool_params)
   if host_pool_params_non_filter["host_pool_id"] then
      host_pool_params_non_filter["host_pool_id"] = nil
   end

   local ordered_host_pool_list = {}

   if host_pool then
      local id = tonumber(host_pool)
      ordered_host_pool_list[id] = {}
      ordered_host_pool_list[id]["count"] = host_pool_list[id]["count"]
   else
      for key, value in pairs(host_pool_list) do
	 ordered_host_pool_list[key] = {}
	 ordered_host_pool_list[key]["count"] = value.count
      end
   end

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("details.host_pool")) print[[]] print(host_pool_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu dropdown-menu-end scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, host_pool_params_non_filter)) print[[">]] print(i18n("flows_page.all_host_pool")) print[[</a></li>]]

   for key, value in pairsByKeys(ordered_host_pool_list, asc) do
      print[[<li]]

      print([[><a class="dropdown-item ]].. (tonumber(host_pool) == key and 'active' or '') ..[[" href="]])

      local host_pool_table = ternary(key ~= 6, host_pool_params_non_filter, host_pool_params)

      host_pool_table["host_pool_id"] = key
      print(getPageUrl(base_url, host_pool_table))
      
      print[[">]] print(sub_quotes_to_string(host_pools_instance:get_pool_name(key))) print [[ (]] print(string.format("%d", value.count)) print [[)</a></li>]]
   end

   print[[</ul>]]
end

-- ###################################

function printLocalNetworksDropdown(base_url, page_params)
   local networks_stats = interface.getNetworksStats()

   local ids = {}
   for n, local_network in pairs(networks_stats) do
      local network_name = getFullLocalNetworkName(local_network["network_key"])
      ids[network_name] = local_network
   end

   local local_network_id = _GET["network"]
   local local_network_id_filter = ''
   if not isEmptyString(local_network_id) then
      local_network_id_filter = '<span class="fas fa-filter"></span>'
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local local_network_id_params = table.clone(page_params)
   local_network_id_params["network"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.networks")) print[[]] print(local_network_id_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
	 <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, local_network_id_params)) print[[">]] print(i18n("flows_page.all_networks")) print[[</a></li>\]]

   for local_network_name, local_network in pairsByKeys(ids) do
      local cur_id = local_network["network_id"]
      local_network_id_params["network"] = cur_id
      print[[
	 <li>\
	   <a class="dropdown-item ]] print(local_network_id == tostring(cur_id) and 'active' or '') print[[" href="]] print(getPageUrl(base_url, local_network_id_params)) print[[">]] print(local_network_name) print[[</a></li>\]]
   end
   print[[

      </ul>]]
end

-- ##############################################

function printTrafficTypeFilterDropdown(base_url, page_params)
   local traffic_type = _GET["traffic_type"]
   local traffic_type_filter = ''
   if not isEmptyString(traffic_type) then
      traffic_type_filter = '<span class="fas fa-filter"></span>'
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local traffic_type_params = table.clone(page_params)
   traffic_type_params["traffic_type"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.direction")) print[[]] print(traffic_type_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_all")) print[[</a></li>\]]

   -- now forthe one-way
   traffic_type_params["traffic_type"] = "one_way"
   print[[
         <li>\
           <a class="dropdown-item ]] if traffic_type == "one_way" then print('active') end print[[" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_one_way")) print[[</a></li>\]]
   traffic_type_params["traffic_type"] = "bidirectional"
   print[[
         <li>\
           <a class="dropdown-item ]] if traffic_type == "bidirectional" then print('active') end print[[" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_two_ways")) print[[</a></li>\]]
   print[[
      </ul>]]
end

-- ##############################################

function printHostsDeviceFilterDropdown(base_url, page_params)
   -- Getting probes
   local flowdevs = interface.getFlowDevices() or {}
   local ordering_fun = pairsByKeys
   local cur_dev = _GET["deviceIP"]
   local cur_dev_filter = ''
   -- table.clone needed to modify some parameters while keeping the original unchanged
   local dev_params = table.clone(page_params)
   local devips = getProbesName(flowdevs)
   local devips_order = ntop.getPref("ntopng.prefs.flow_table_probe_order") == "1" -- Order by Probe Name

   if devips_order then
      ordering_fun = pairsByValues
   end

   if not isEmptyString(cur_dev) then
      cur_dev_filter = '<span class="fas fa-filter"></span>'
   end

   dev_params["deviceIP"] = nil

   if table.len(devips) > 0 then
      print[[, '<div class="btn-group float-right">]]

      print[[
         <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.device_ip")) print[[]] print(cur_dev_filter) print[[<span class="caret"></span></button>\
         <ul class="dropdown-menu dropdown-menu-end scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, dev_params)) print[[">]] print(i18n("flows_page.all_devices")) print[[</a></li>\]]

      for dev_ip, dev_resolved_name in ordering_fun(devips, asc) do
         local dev_name = dev_ip

         dev_params["deviceIP"] = dev_name

         if not isEmptyString(dev_resolved_name) and dev_resolved_name ~= dev_name then
            dev_name = dev_name .. " ["..shortenString(dev_resolved_name).."]"
         end

         print[[
         <li><a class="dropdown-item ]] print(dev_ip == cur_dev and 'active' or '') print[[" href="]] print(getPageUrl(base_url, dev_params)) print[[">]] print(i18n("flows_page.device_ip").." "..dev_name) print[[</a></li>\]]
      end

      print[[
         </ul>\
      ]]

      print[[</div>']]
   end
end

function processColor(proc)
  if(proc == nil) then
    return("")
  elseif(proc["average_cpu_load"] < 33) then
    return("<font color=green>"..proc["name"].."</font>")
  elseif(proc["average_cpu_load"] < 66) then
    return("<font color=orange>"..proc["name"].."</font>")
  else
    return("<font color=red>"..proc["name"].."</font>")
  end
end

-- print TCP flags
function printTCPFlags(flags)
   print(formatTCPFlags(flags))
end


-- ###########################################

function printWarningAlert(message)
   print[[<div class="alert alert-warning alert-dismissable" role="alert">]]
   print[[<i class="fas fa-exclamation-triangle fa-sm"></i> ]]
   print[[<strong>]] print(i18n("warning")) print[[</strong> ]]
   print(message)
   print[[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]]
   print[[</div>]]
end

-- ###########################################

-- Banner format: {type="success|warning|danger", text="..."}
function printMessageBanners(banners)
   for _, msg in ipairs(banners) do
      print[[
  <div class="alert alert-]] print(msg.type) print([[ alert-dismissible" style="margin-top:2em; margin-bottom:0em;">
    ]])

      if (msg.type == "warning") then
         print("<b>".. i18n("warning") .. "</b>: ")
      elseif (msg.type == "danger") then
         print("<b>".. i18n("error") .. "</b>: ")
      end

      print(msg.text)

      print[[
         <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  </div>]]
   end
end

-- ##############################################

function print_copy_button(id, data)
   print('<button style="" class="btn btn-sm border ms-1" data-placement="bottom" id="btn-copy-' .. id ..'" data="' .. data .. '"><i class="fas fa-copy"></i></button>')
   print("<script>$('#btn-copy-" .. id .. "').click(function(e) { NtopUtils.copyToClipboard($(this).attr('data'), '" .. i18n('copied') .. "', '" .. i18n('request_failed_message') .. "', $(this));});</script>")
end





if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end
