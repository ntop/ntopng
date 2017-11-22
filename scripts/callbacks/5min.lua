--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
  require("5min")

  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
require "rrd_utils"
local os_utils = require "os_utils"
local rrd_dump = require "rrd_dump_utils"
local host_pools_utils = require "host_pools_utils"
local callback_utils = require "callback_utils"

local when = os.time()
local verbose = ntop.verboseTrace()

-- We must complete within the 5 minutes
local time_threshold = when - (when % 300) + 300 - 10 -- safe margin

-- ########################################################

local interface_rrd_creation = ntop.getPref("ntopng.prefs.interface_rrd_creation")
local interface_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")
local host_rrd_creation = ntop.getPref("ntopng.prefs.host_rrd_creation")
local host_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")
local l2_device_rrd_creation = ntop.getPref("ntopng.prefs.l2_device_rrd_creation")
local l2_device_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.l2_device_ndpi_timeseries_creation")
local flow_devices_rrd_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation")
local host_pools_rrd_creation = ntop.getPref("ntopng.prefs.host_pools_rrd_creation")
local snmp_devices_rrd_creation = ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation")
local asn_rrd_creation = ntop.getPref("ntopng.prefs.asn_rrd_creation")
local vlan_rrd_creation = ntop.getPref("ntopng.prefs.vlan_rrd_creation")
local tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")

-- ########################################################
-- Populate some defaults
if(tostring(flow_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
   flow_devices_rrd_creation = "0"
end

if(tostring(snmp_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
   snmp_devices_rrd_creation = "0"
end

-- Interface RRD creation is on, with per-protocol nDPI
if isEmptyString(interface_rrd_creation) then interface_rrd_creation = "1" end
if isEmptyString(interface_ndpi_timeseries_creation) then interface_ndpi_timeseries_creation = "per_protocol" end

-- Local hosts RRD creation is on, with no nDPI rrd creation
if isEmptyString(host_rrd_creation) then host_rrd_creation = "1" end
if isEmptyString(host_ndpi_timeseries_creation) then host_ndpi_timeseries_creation = "none" end

-- Devices RRD creation is OFF, as OFF is the nDPI rrd creation
if isEmptyString(l2_device_rrd_creation) then l2_device_rrd_creation = "0" end
if isEmptyString(l2_device_ndpi_timeseries_creation) then l2_device_ndpi_timeseries_creation = "none" end

-- tprint({interface_rrd_creation=interface_rrd_creation, interface_ndpi_timeseries_creation=interface_ndpi_timeseries_creation,host_rrd_creation=host_rrd_creation,host_ndpi_timeseries_creation=host_ndpi_timeseries_creation})

local ifnames = interface.getIfNames()
local prefs = ntop.getPrefs()

-- ########################################################

callback_utils.foreachInterface(ifnames, nil, function(_ifname, ifstats)
  housekeepingAlertsMakeRoom(getInterfaceId(_ifname))
  scanAlerts("5mins", ifstats)

  if not interface_rrd_creation_enabled(ifstats.id) then
    goto continue
  end

  if interface_rrd_creation == "1" then
    local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")

    if interface_ndpi_timeseries_creation == "per_protocol" or interface_ndpi_timeseries_creation == "both" then
      rrd_dump.iface_update_ndpi_rrds(when, basedir, _ifname, ifstats, verbose)
    end

    if interface_ndpi_timeseries_creation == "per_category" or interface_ndpi_timeseries_creation == "both" then
      rrd_dump.iface_update_categories_rrds(when, basedir, _ifname, ifstats, verbose)
    end

    rrd_dump.iface_update_stats_rrds(when, basedir, _ifname, ifstats, verbose)
  end

  -- Save hosts stats (if enabled from the preferences)
  if host_rrd_creation ~= "0" then
    local in_time = callback_utils.foreachLocalHost(_ifname, time_threshold, function (hostname, host, hostbase)

    -- Crunch additional stats for local hosts only
    if(host.localhost) then
      -- Traffic stats
      if(host_rrd_creation == "1") then
        rrd_dump.host_update_stats_rrds(when, hostname, hostbase, host, ifstats, verbose)
      end

      if(host_ndpi_timeseries_creation == "per_protocol" or host_ndpi_timeseries_creation == "both") then
        rrd_dump.host_update_ndpi_rrds(when, hostname, hostbase, host, ifstats, verbose)
      end

      if(host_ndpi_timeseries_creation == "per_category" or host_ndpi_timeseries_creation == "both") then
        rrd_dump.host_update_categories_rrds(when, hostname, hostbase, host, ifstats, verbose)
      end
    end
  end)

  if not in_time then
    callback_utils.print(__FILE__(), __LINE__(), "ERROR: Cannot complete local hosts RRD dump in 5 minutes. Please check your RRD configuration.")
    return false
  end

  if l2_device_rrd_creation ~= "0" then
    local in_time = callback_utils.foreachDevice(_ifname, time_threshold, function (devicename, device, devicebase)
      rrd_dump.l2_device_update_stats_rrds(when, devicename, device, devicebase, ifstats, verbose)

      if l2_device_ndpi_timeseries_creation == "per_category" then
        rrd_dump.l2_device_update_categories_rrds(when, devicename, device, devicebase, ifstats, verbose)
      end
    end)

    if not in_time then
      callback_utils.print(__FILE__(), __LINE__(), "ERROR: Cannot devices RRD dump in 5 minutes. Please check your RRD configuration.")
      return false
    end
  end
end

  -- create RRD for ASN
  if asn_rrd_creation == "1" then
    rrd_dump.asn_update_rrds(when, ifstats, verbose)

    if tcp_retr_ooo_lost_rrd_creation == "1" then
      --[[ TODO: implement for ASes
      --]]
    end
  end

  -- Create RRD for vlans
  if vlan_rrd_creation == "1" then
    rrd_dump.vlan_update_rrds(when, ifstats, verbose)

    if tcp_retr_ooo_lost_rrd_creation == "1" then
        --[[ TODO: implement for VLANs
        --]]
    end
  end

  -- Create RRDs for flow and sFlow devices
  if(flow_devices_rrd_creation == "1" and ntop.isEnterprise()) then
    rrd_dump.sflow_device_update_rrds(when, ifstats, verbose)
    rrd_dump.flow_device_update_rrds(when, ifstats, verbose)
  end

  -- Save Host Pools stats every 5 minutes
  if((ntop.isPro()) and (tostring(host_pools_rrd_creation) == "1") and (not ifstats.isView)) then
    host_pools_utils.updateRRDs(ifstats.id, true --[[ also dump nDPI data ]], verbose)
  end

  ::continue::
end)

-- ########################################################

-- This must be placed at the end of the script
if(tostring(snmp_devices_rrd_creation) == "1") then
   snmp_update_rrds(time_threshold, verbose)
end
