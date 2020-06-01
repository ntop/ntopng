--
-- (C) 2019-20 - ntop.org
--
-- MUD - Manufacturer Usage Description
-- https://tools.ietf.org/id/draft-ietf-opsawg-mud-22.html
--
-- Information stored varies based on the host classification and connection
-- type:
--
-- <General Purpose Host>
--  - Local: <l4_proto, peer_key, srv_port>
--  - Remote: <l4_proto, l7_proto, fingerprint_type, host_fingerprint>
-- <Special Purpose Host>
--  - Local: <l4_proto, peer_key, srv_port>
--  - Remote: <l4_proto, l7_proto, fingerprint_type, host_fingerprint, peer_fingerprint, peer_key>
--
-- Items marked with the NTOP_MUD comment are part of the ntop MUD proposal
--

local mud_utils = {}
local discover = require("discover_utils")

-- ###########################################

-- @brief Possibly extract fingerprint information for host/peers
-- @return a table {fp_id, host_fp, peer_fp} where fp_id is one of {"", "JA3", "HASSH"}
local function getFingerprints(is_client)
   local tls_info = flow.getTLSInfo()
   local ja3_cli_hash = tls_info["protos.tls.ja3.client_hash"]
   local ja3_srv_hash = tls_info["protos.tls.ja3.server_hash"]

   if(ja3_cli_hash or ja3_srv_hash) then
      if(is_client) then
         return {"JA3", ja3_cli_hash or "", ja3_srv_hash or ""}
      else
         return {"JA3", ja3_srv_hash or "", ja3_cli_hash or ""}
      end
   end

   local ssh_info = flow.getSSHInfo()
   local hassh_cli_hash = ssh_info["protos.ssh.hassh.client_hash"]
   local hassh_srv_hash = ssh_info["protos.ssh.hassh.server_hash"]

   if(hassh_cli_hash or hassh_srv_hash) then
      if(is_client) then
         return {"HASSH", hassh_cli_hash or "", hassh_srv_hash or ""}
      else
         return {"HASSH", hassh_srv_hash or "", hassh_cli_hash or ""}
      end
   end

   return {"", "", ""}
end

-- ###########################################

local function local_mud_encode(info, peer_key, peer_port, is_client, peer_key_is_mac, mud_info)
   return(string.format("%s|%s|%u", info["proto.l4"], peer_key, info["srv.port"]))
end

local function local_mud_decode(value)
   local v = string.split(value, "|")

   return({
      l4proto = v[1],
      peer_key = v[2],
      srv_port = tonumber(v[3]),
   })
end

-- ###########################################

local function remote_minimal_mud_encode(info, peer_key, peer_port, is_client, peer_key_is_mac, mud_info)
   local l7proto = info["proto.ndpi_app"]
   local fingerprints = getFingerprints(is_client)

   return(string.format("%s|%s|%s|%s", info["proto.l4"], l7proto,
      fingerprints[1], fingerprints[2]))
end

local function remote_minimal_mud_decode(value)
   local v = string.split(value, "|")

   return({
      l4proto = v[1],
      l7proto = v[2],
      fingerprint_type = v[3],
      host_fingerprint = v[4],
   })
end

-- ###########################################

local function remote_full_mud_encode(info, peer_key, peer_port, is_client, peer_key_is_mac, mud_info)
   local l7proto = info["proto.ndpi_app"]
   local fingerprints = getFingerprints(is_client)

   if(not peer_key_is_mac) then
      local is_symbolic = false

      if(is_client) then
         local peer_name = mud_info["host_server_name"] or mud_info["protos.dns.last_query"]

         if not isEmptyString(peer_name) then
            peer_key = peer_name
            is_symbolic = true
         end
      end

      if(not is_symbolic) then
         -- NOTE: this can take time, maybe postpone?
         peer_key = resolveAddress({host = peer_key})
      end

      -- Name Cleanup
      if(string.find(peer_key, "www.") == 1) then
         peer_key = string.sub(peer_key, 5)
      end
   end

   return(string.format("%s|%s|%s|%s|%s|%s", info["proto.l4"], l7proto,
      fingerprints[1], fingerprints[2], fingerprints[3], peer_key))
end

local function remote_full_mud_decode(value)
   local v = string.split(value, "|")

   return({
      l4proto = v[1],
      l7proto = v[2],
      fingerprint_type = v[3],
      host_fingerprint = v[4],
      peer_fingerprint = v[5],
      peer_key = v[6],
   })
end

-- ###########################################

mud_utils.mud_types = {
   -- A local MUD describe local-local communications
   ["local"] = {
      redis_key = "ntopng.mud.ifid_%d.local._%s_.%s",
      encode = local_mud_encode,
      decode = local_mud_decode,
   },
   -- A remote_minimal MUD describes local-remote communications and
   -- keeps minimal information about remote peers
   ["remote_minimal"] = {
      redis_key = "ntopng.mud.ifid_%d.remote_minimal._%s_.%s",
      encode = remote_minimal_mud_encode,
      decode = remote_minimal_mud_decode,
   },
   -- A remote_full MUD describes local-remote communications and
   -- keeps complete information about remote peers
   ["remote_full"] = {
      redis_key = "ntopng.mud.ifid_%d.remote_full._%s_.%s",
      encode = remote_full_mud_encode,
      decode = remote_full_mud_decode,
   },
}

-- ###########################################

local function getMudRedisKey(mud_type, ifid, host_key, is_client, is_ipv6)
   if(is_ipv6) then
      return(string.format(mud_type.redis_key, ifid, host_key, ternary(is_client, "v6_out", "v6_in")))
   else
      return(string.format(mud_type.redis_key, ifid, host_key, ternary(is_client, "out", "in")))
   end
end

-- ###########################################

local function getFirstMudRecordedKey(ifid, host_key)
   return(string.format("ntopng.mud.ifid_%d.first_recorded_data._%s_", ifid, host_key))
end

-- ###########################################

local function handleHostMUD(ifid, now, max_recording, mud_info, is_general_purpose, is_client)
   local flow_info = flow.getInfo() -- TODO remove
   local l4proto = flow_info["proto.l4"]
   local mud_type
   local peer_key_is_mac
   local is_local_connection = mud_info["is_local"]
   local host_ip, peer_ip, peer_port, peer_key

   -- Only support TCP and UDP
   if((l4proto ~= "TCP") and (l4proto ~= "UDP")) then
      return
   end

   if(is_local_connection) then
      mud_type = mud_utils.mud_types["local"]
   elseif(is_general_purpose) then
      mud_type = mud_utils.mud_types["remote_minimal"]
   else
      mud_type = mud_utils.mud_types["remote_full"]
   end

   if is_client then
      host_ip = flow_info["cli.ip"]
      peer_ip = flow_info["srv.ip"]
      peer_port = flow_info["srv.port"]
      peer_key_is_mac = mud_info["srv.serialize_by_mac"]
      peer_key = ternary(peer_key_is_mac, mud_info["srv.mac"], flow_info["srv.ip"])
   else
      host_ip = flow_info["srv.ip"]
      peer_ip = flow_info["cli.ip"]
      peer_port = flow_info["cli.port"]
      peer_key_is_mac = mud_info["cli.serialize_by_mac"]
      peer_key = ternary(peer_key_is_mac, mud_info["cli.mac"], flow_info["cli.ip"])
   end

   local first_recorded_key = getFirstMudRecordedKey(ifid, host_ip)
   local first_recorded = tonumber(ntop.getCache(first_recorded_key)) or now
   local recording_completed = ((now - first_recorded) >= max_recording)

   if(recording_completed) then
      -- The learning phase for this host has ended
      return
   end

   local is_ipv6 = (not isIPv4(host_ip))
   local mud_key = getMudRedisKey(mud_type, ifid, host_ip, is_client, is_ipv6)
   local conn_key = mud_type.encode(flow_info, peer_key, peer_port, is_client, peer_key_is_mac, mud_info)

   -- Register the connection
   -- TODO handle alerts
   ntop.setMembersCache(mud_key, conn_key)

   if(first_recorded == now) then
      -- First time MUD is recorded for this host
      ntop.setCache(first_recorded_key, string.format("%u", now))
   end
end

-- ###########################################

local function getDefaultMudRecordingPref(enabled_device_types, devtype)
   if(not enabled_device_types[devtype]) then
      return("disabled")
   end

   if(discover.isSpecialPurposeDevice(devtype)) then
      return("special_purpose")
   else
      return("general_purpose")
   end
end

-- ###########################################

-- @brief Possibly generate MUD entries for the flow hosts
-- @param now timestamp
-- @param table containing the device type IDs for MUD enabled devices
-- @param max_recording the maximum time in seconds to record the MUD for a device
-- @notes This function is called with a LuaC flow context set
function mud_utils.handleFlow(now, enabled_device_types, max_recording)
   local ifid = interface.getId()
   local mud_info = flow.getMUDInfo()
   local cli_recording = mud_info["cli.mud_recording"]
   local srv_recording = mud_info["srv.mud_recording"]

   if(cli_recording == "default") then
      cli_recording = getDefaultMudRecordingPref(enabled_device_types, mud_info["cli.devtype"])
   end
   if(srv_recording == "default") then
      srv_recording = getDefaultMudRecordingPref(enabled_device_types, mud_info["srv.devtype"])
   end

   if(cli_recording ~= "disabled") then
      handleHostMUD(ifid, now, max_recording, mud_info, (cli_recording == "general_purpose"), true --[[client]])
   end
   if(srv_recording ~= "disabled") then
      handleHostMUD(ifid, now, max_recording, mud_info, (srv_recording == "general_purpose"), false --[[server]])
   end
end

-- ###########################################

local mud_user_script = nil

-- Cache mud_user_script to avoid repeated loads
local function loadMudUserScriptConf()
   if(mud_user_script == nil) then
      local user_scripts = require("user_scripts")
      local configsets = user_scripts.getConfigsets()
      local configset, confset_id = user_scripts.getTargetConfig(configsets, "flow", ifid)
      mud_user_script = user_scripts.getTargetHookConfig(configset, "mud")
   end

   return(mud_user_script)
end

-- ###########################################

function mud_utils.getCurrentHostMUDRecording(ifid, host_key, device_type)
   local pref = mud_utils.getHostMUDRecordingPref(ifid, host_key)

   if(pref == "default") then
      local mud_user_script = loadMudUserScriptConf()

      if(mud_user_script.enabled) then
         local enabled_device_types = {}

         for _, devtype in pairs(mud_user_script.script_conf.device_types or {}) do
            local id = discover.devtype2id(devtype)

            enabled_device_types[id] = true
         end

         return(getDefaultMudRecordingPref(enabled_device_types, device_type))
      end

      return("disabled")
   end

   return(pref)
end

-- ###########################################

function mud_utils.getMudPrefLabel(pref)
   if pref == "disabled" then
      return(i18n("traffic_recording.disabled"))
   elseif pref == "general_purpose" then
      return(i18n("host_config.mud_general_purpose"))
   elseif pref == "special_purpose" then
      return(i18n("host_config.mud_special_purpose"))
   else
      return(i18n("default"))
   end
end

-- ###########################################

function mud_utils.formatMaxRecording(max_recording_secs)
   if max_recording_secs == 3600 then
      return(i18n("show_alerts.1_hour"))
   elseif max_recording_secs == 86400 then
      return(i18n("show_alerts.1_day"))
   elseif max_recording_secs == 604800 then
      return(i18n("show_alerts.1_week"))
   else
      return(string.format("%u", max_recording_secs))
   end
end

-- ###########################################

function mud_utils.isMudScriptEnabled(ifid)
   local mud_user_script = loadMudUserScriptConf()

   return(mud_user_script.enabled)
end

-- ###########################################

local function getAclMatches(conn, dir)
   local peer_key = conn.peer_key or ""
   local mud_l4proto = string.lower(conn.l4proto)
   local matches = {}

   matches[dir.mud_l3proto] = {
      ["protocol"] = l4_proto_to_id(mud_l4proto),
   }

   if(not isEmptyString(peer_key)) then
      if(isMacAddress(peer_key)) then
         matches["eth"] = {
            [dir.mud_mac_address] = string.lower(peer_key)
         }
      elseif(dir.is_ipv6) then
         if isIPv6(peer_key) then
            matches[dir.mud_l3proto][dir.mud_network] = string.format("%s/128", peer_key)
         else
            matches[dir.mud_l3proto][dir.mud_dnsname] = peer_key
         end
      else
         if isIPv4(peer_key) then
            matches[dir.mud_l3proto][dir.mud_network] = string.format("%s/32", peer_key)
         else
            matches[dir.mud_l3proto][dir.mud_dnsname] = peer_key
         end
      end
   end

   if(conn.srv_port ~= nil) then
      matches[mud_l4proto] = {}

      if(conn.l4proto == "TCP") then
         matches[mud_l4proto]["ietf-mud:direction-initiated"] = dir.mud_direction
      end

      matches[mud_l4proto]["destination-port"] = {
         ["operator"] = "eq",
         ["port"] = conn.srv_port,
      }
   end

   if(conn.l7proto ~= nil) then
      -- NTOP_MUD
      matches["cybersec-mud:ndpi"] = {
         ["application-protocol"] = string.lower(conn.l7proto),
      }
   end

   if(not isEmptyString(conn.fingerprint_type)) then
      if(conn.fingerprint_type == "JA3") then
         if(not isEmptyString(conn.host_fingerprint)) then
            -- NTOP_MUD
            matches["cybersec-mud:ja3"] = matches["cybersec-mud:ja3"] or {}
            matches["cybersec-mud:ja3"]["client-fingerprint"] = conn.host_fingerprint
         end
         if(not isEmptyString(conn.peer_fingerprint)) then
            -- NTOP_MUD
            matches["cybersec-mud:ja3"] = matches["cybersec-mud:ja3"] or {}
            matches["cybersec-mud:ja3"]["server-fingerprint"] = conn.peer_fingerprint
         end
      elseif(conn.fingerprint_type == "HASSH") then
         if(not isEmptyString(conn.host_fingerprint)) then
            -- NTOP_MUD
            matches["cybersec-mud:hassh"] = matches["cybersec-mud:hassh"] or {}
            matches["cybersec-mud:hassh"]["client-fingerprint"] = conn.host_fingerprint
         end
         if(not isEmptyString(conn.peer_fingerprint)) then
            -- NTOP_MUD
            matches["cybersec-mud:hassh"] = matches["cybersec-mud:hassh"] or {}
            matches["cybersec-mud:hassh"]["server-fingerprint"] = conn.peer_fingerprint
         end
      end
   end

   return(matches)
end

-- ###########################################

function mud_utils.getHostMUD(host_key)
   local ifid = interface.getId()
   local is_general_purpose = (mud_utils.getHostMUDRecordingPref(ifid, host_key) == "general_purpose")
   local ifid = interface.getId()
   local mud = {}
   local host_name = hostinfo2label(hostkey2hostinfo(host_key))
   local mud_url = _SERVER["HTTP_HOST"] .. ntop.getHttpPrefix() .. "/lua/rest/v1/get/host/mud.lua?host=" .. host_key

   -- https://tools.ietf.org/html/rfc8520
   mud["ietf-mud:mud"] = {
      ["mud-version"] = 1,
      ["mud-url"] = mud_url,
      ["last-update"] = os.date("%Y-%m-%dT%H:%M:%S"),
      ["cache-validity"] = 48,
      ["is-supported"] = true,
      ["systeminfo"] = "MUD file for host "..host_name,
      ["from-device-policy"] = {
         ["access-lists"] = {
            ["access_list"] = {}
         }
      },
      ["to-device-policy"] = {
         ["access-lists"] = {
            ["access_list"] = {}
         }
      },
      ["ietf-access-control-list:access-lists"] = {
          ["acl"] = {}
      }
   }

   -- Populate ACL
   local mud_acls = mud["ietf-mud:mud"]["ietf-access-control-list:access-lists"]["acl"]
   local local_mud_type = mud_utils.mud_types["local"]
   local remote_mud_type = ternary(is_general_purpose, mud_utils.mud_types["remote_minimal"], mud_utils.mud_types["remote_full"])

   -- From/To device IPv4/IPv6
   local directions = {
      {
         host = "from-ipv4-"..host_name,
         mud_direction = "from-device",
         mud_network = "destination-ipv4-network",
         mud_dnsname = "ietf-acldns:dst-dnsname",
         mud_l3proto = "ipv4",
         mud_mac_address = "destination-mac-address",
         acl_type = "ipv4-acl-type",
         acl_list = mud["ietf-mud:mud"]["from-device-policy"]["access-lists"]["access_list"],
         is_client = true,
         is_ipv6 = false,
      }, {
         host = "to-ipv4-"..host_name,
         mud_direction = "to-device",
         mud_network = "source-ipv4-network",
         mud_dnsname = "ietf-acldns:src-dnsname",
         mud_l3proto = "ipv4",
         mud_mac_address = "source-mac-address",
         acl_type = "ipv4-acl-type",
         acl_list = mud["ietf-mud:mud"]["to-device-policy"]["access-lists"]["access_list"],
         is_client = false,
         is_ipv6 = false,
      }, {
         host = "from-ipv6-"..host_name,
         mud_direction = "from-device",
         mud_network = "destination-ipv6-network",
         mud_dnsname = "ietf-acldns:dst-dnsname",
         mud_l3proto = "ipv6",
         mud_mac_address = "destination-mac-address",
         acl_type = "ipv6-acl-type",
         acl_list = mud["ietf-mud:mud"]["from-device-policy"]["access-lists"]["access_list"],
         is_client = true,
         is_ipv6 = true,
      }, {
         host = "to-ipv6-"..host_name,
         mud_direction = "to-device",
         mud_network = "source-ipv6-network",
         mud_dnsname = "ietf-acldns:src-dnsname",
         mud_l3proto = "ipv6",
         mud_mac_address = "source-mac-address",
         acl_type = "ipv6-acl-type",
         acl_list = mud["ietf-mud:mud"]["to-device-policy"]["access-lists"]["access_list"],
         is_client = false,
         is_ipv6 = true,
      }
   }

   for _, direction in ipairs(directions) do
      local direction_aces = {}
      local acl_id = 0

      local local_remote = {
         {
            mud_type = local_mud_type,
            redis_key = getMudRedisKey(local_mud_type, ifid, host_key, direction.is_client, direction.is_ipv6),
         }, {
            mud_type = remote_mud_type,
            redis_key = getMudRedisKey(remote_mud_type, ifid, host_key, direction.is_client, direction.is_ipv6),
         }
      }

      -- Imposing order to retain acl_id -> rule mapping
      for _, lr in ipairs(local_remote) do
         local mud_type = lr.mud_type

         for _, serialized in pairsByKeys(ntop.getMembersCache(lr.redis_key) or {}) do
            local connection = mud_type.decode(serialized)
            connection.host_key = host_key

            local acl = {
               ["name"] = string.format("%s-%u", direction.host, acl_id),
               ["matches"] = getAclMatches(connection, direction),
               ["actions"] = {
                  ["forwarding"] = "accept",
               }
            }

            acl_id = acl_id + 1
            direction_aces[acl_id] = acl
         end
      end

      if(not table.empty(direction_aces)) then
         direction.acl_list[#direction.acl_list + 1] = {
            ["name"] = direction.host
         }

         mud_acls[#mud_acls + 1] = {
            name = direction.host,
            type = direction.acl_type,
            aces = direction_aces,
         }
      end
   end

   return(mud)
end

-- ###########################################

local function getHostMUDRecordingKey(ifid, host_key)
   return(string.format("ntopng.prefs.iface_%d.mud.recording.%s", ifid, host_key))
end

-- See getCurrentHostMUDRecording to expand the "default"
function mud_utils.getHostMUDRecordingPref(ifid, host_key)
   local rv = ntop.getPref(getHostMUDRecordingKey(ifid, host_key))

   if(not isEmptyString(rv)) then
      return(rv)
   end

   -- Use the MUD user script configuration to determine if the MUD recording
   -- is currently enabled.
   return("default")
end

function mud_utils.setHostMUDRecordingPref(ifid, host_key, val)
   local key = getHostMUDRecordingKey(ifid, host_key)

   if(val == "default") then
      ntop.delCache(key)
   else
      ntop.setPref(key, val)
   end
end

-- ###########################################

function mud_utils.hasRecordedMUD(ifid, host_key)
   return(not isEmptyString(ntop.getCache(getFirstMudRecordedKey(ifid, host_key))))
end

-- ###########################################

function mud_utils.isMUDRecordingInProgress(ifid, host_key)
   local first_recorded = tonumber(ntop.getCache(getFirstMudRecordedKey(ifid, host_key)))

   if(first_recorded == nil) then
      return(false)
   end

   local conf = loadMudUserScriptConf()

   if(not conf.enabled) then
      return(false)
   end

   local max_recording = conf.script_conf.max_recording or 3600

   return((os.time() - first_recorded) < max_recording)
end

-- ###########################################

function mud_utils.deleteHostMUD(ifid, host_key)
  ntop.detCache(getFirstMudRecordedKey(ifid, host_key))

  local pattern = string.format("ntopng.mud.ifid_%d.*._%s_*", ifid, host_key)
  local keys = ntop.getKeysCache(pattern) or {}

  for key in pairs(keys) do
    ntop.delCache(key)
  end
end

-- ###########################################

return mud_utils
