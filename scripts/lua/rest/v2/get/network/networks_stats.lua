--
-- (C) 2013-25 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local network_formatter = require "network_formatter"
local rest_utils = require "rest_utils"
local json = require("dkjson")

local res = {}
local networks_stats = interface.getNetworksStats()


for network_name, data in pairs(networks_stats) do
    local networkId = tonumber(data["network_id"])
    
    -- compute score
    local score_as_client = tonumber(data["score.as_client"]) or 0
    local score_as_server = tonumber(data["score.as_server"]) or 0
    
    -- score, alerted flows and hosts
    local network_score = (score_as_client + score_as_server) or 0
    local alerted_flows = data["alerted_flows"] or 0
    local num_alerted_flows = tonumber(alerted_flows["total"]) or 0
    local num_hosts = tonumber(data.num_hosts) or 0
    local hosts_score_ratio = network_score / num_hosts

    -- traffic breakdown
    local bytes_sent = tonumber(data["bytes.sent"]) or 0
    local bytes_rcvd = tonumber(data["bytes.rcvd"]) or 0
    local total_bytes = bytes_sent + bytes_rcvd

    local network_data = {
        networkId = networkId,
        networkName = network_name,
        hosts = num_hosts,
        score = network_score,
        hostsScoreRatio = hosts_score_ratio,
        alertedFlows = num_alerted_flows,

        breakdown = {
            percentage_bytes_sent = (bytes_sent * 100) / total_bytes,
            percentage_bytes_rcvd = (bytes_rcvd * 100) / total_bytes
        },

        bytes_sent = bytes_sent,
        bytes_rcvd = bytes_rcvd,
        throughput = tonumber(data.throughput_bps),
        traffic = total_bytes
    }

    res[#res+1] = network_data
end

rest_utils.answer(rest_utils.consts.success.ok, res)