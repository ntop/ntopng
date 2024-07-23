--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Read information about the nprobes connected to an interface
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/interfacenprobes/data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"] or interface.getId()

if isEmptyString(ifid) then
    rc = rest_utils.consts.err.invalid_interface
    rest_utils.answer(rc)
    return
end

interface.select(ifid)
local if_names = interface.getIfNames()
local ifstats = interface.getStats()
local probes_stats = ifstats.probes or {}
local timeseries_enabled = areFlowdevTimeseriesEnabled()

for interface_id, probes_list in pairs(ifstats.probes or {}) do
    for source_id, probe_info in pairs(probes_list or {}) do
        local flow_drops = 0
        local exported_flows = 0
        local flow_exporters_num = table.len(probe_info.exporters)
        if table.len(probe_info.exporters) == 0 then
            flow_exporters_num = 1 -- Packet exporter
            flow_drops = probe_info["drops.elk_flow_drops"] + probe_info["drops.flow_collection_udp_socket_drops"] +
                            probe_info["drops.export_queue_full"] + probe_info["drops.too_many_flows"] + probe_info["drops.flow_collection_drops"] +
                            probe_info["drops.sflow_pkt_sample_drops"] + probe_info["drops.elk_flow_drops"]
            exported_flows = probe_info["zmq.num_flow_exports"]
        else
            for _, values in pairs(probe_info.exporters) do
                flow_drops = flow_drops + values.num_drops
                exported_flows = exported_flows + values.num_netflow_flows + values.num_sflow_flows
            end
        end

        res[#res + 1] = {
            probe_interface = ternary((probe_info["remote.name"] ~= "none"), probe_info["remote.name"],
                i18n("if_stats_overview.remote_probe_collector_mode")),
            probe_version = probe_info["probe.probe_version"],
            probe_ip = probe_info["probe.ip"],
            probe_uuid = probe_info["probe.uuid"],
            probe_uuid_num = probe_info["probe.uuid_num"],
            probe_public_ip = probe_info["probe.public_ip"],
            probe_edition = probe_info["probe.probe_edition"],
            probe_license = probe_info["probe.probe_license"] or i18n("if_stats_overview.no_license"),
            probe_maintenance = probe_info["probe.probe_maintenance"] or i18n("if_stats_overview.expired_maintenance"),
            flow_exporters = flow_exporters_num,
            dropped_flows = flow_drops,
            exported_flows = exported_flows,
            ntopng_interface = if_names[tostring(interface_id)],
            timeseries_enabled = timeseries_enabled,
            ifid = interface_id
        }
    end
end

rest_utils.answer(rc, res)
