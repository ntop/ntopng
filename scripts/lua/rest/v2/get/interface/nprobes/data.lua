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
local ifstats = interface.getStats()
local probes_stats = ifstats.probes or {}
local timeseries_enabled = areFlowdevTimeseriesEnabled()
if table.len(probes_stats) > 0 then
    for k, v in pairs(ifstats.probes or {}) do
        v.exporters = ifstats.exporters or {}
        v.ifid = ifid
        probes_stats[k] = v
    end
    ifstats.probes = probes_stats
end
if interface.isView() then
    local zmq_stats = {}
    local exporters_stats = {}
    for interface_id, _ in pairsByKeys(interface.getIfNames() or {}) do
        interface.select(interface_id)
        if interface.isViewed() then
            local tmp = interface.getStats()
            for k, v in pairs(tmp.probes or {}) do
                v.exporters = tmp.exporters or {}
                v.ifid = interface_id
                probes_stats[k] = v
            end
        end
    end
    ifstats.probes = probes_stats
    interface.select(ifstats.id)
end

for k, v in pairs(ifstats.probes or {}) do
    local flow_drops = 0
    local exported_flows = 0
    local probe_active = false
    local flow_exporters_num = table.len(v.exporters or {})
    if interface.getHostInfo(v["probe.ip"]) then
        probe_active = true
    end
    if table.len(v.exporters) == 0 then
        flow_exporters_num = 1
        flow_drops = v["drops.elk_flow_drops"] + v["drops.flow_collection_udp_socket_drops"] +
                         v["drops.export_queue_full"] + v["drops.too_many_flows"] + v["drops.flow_collection_drops"] +
                         v["drops.sflow_pkt_sample_drops"] + v["drops.elk_flow_drops"]
        exported_flows = v["zmq.num_flow_exports"]
    else
        for _, values in pairs(v.exporters) do
            flow_drops = flow_drops + values.num_drops
            exported_flows = exported_flows + values.num_netflow_flows + values.num_sflow_flows
        end
    end

    res[#res + 1] = {
        probe_interface = ternary((v["remote.name"] ~= "none"), v["remote.name"],
            i18n("if_stats_overview.remote_probe_collector_mode")),
        probe_version = v["probe.probe_version"],
        probe_ip = v["probe.ip"],
        probe_uuid = v["probe.uuid"],
        probe_public_ip = v["probe.public_ip"],
        probe_edition = v["probe.probe_edition"],
        probe_license = v["probe.probe_license"] or i18n("if_stats_overview.no_license"),
        probe_maintenance = v["probe.probe_maintenance"] or i18n("if_stats_overview.expired_maintenance"),
        flow_exporters = flow_exporters_num,
        dropped_flows = flow_drops,
        exported_flows = exported_flows,
        timeseries_enabled = timeseries_enabled,
        ifid = v.ifid,
        is_probe_active = probe_active
    }
end

rest_utils.answer(rc, res)
