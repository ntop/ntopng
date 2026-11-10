--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Required modules for API functionality
require "lua_utils"
local json = require("dkjson")
local tracker = require("tracker")
local rest_utils = require("rest_utils")

--- @module host_data_api
-- @description REST API endpoint for retrieving detailed host information
-- @version 2.0
-- @author ntop.org
-- @license Proprietary

--- @swagger
-- /lua/rest/v2/get/host/data.lua:
--   get:
--     tags:
--       - Host Management
--       - Monitoring
--     summary: Retrieve comprehensive information about a network host
--     description: |
--       ## Overview
--       This endpoint provides detailed information about a specific host on a monitored network interface.
--       It can return basic host statistics, active flows, and protocol-level throughput analysis.
--       
--       ## Authentication
--       - HTTP Basic Authentication with administrator credentials required
--       - Invalid credentials result in redirection to login page (HTTP 302)
--       
--       ## Rate Limiting
--       - Standard API rate limits apply (100 requests/minute per IP)
--       
--       ## Data Sources
--       - Real-time interface data via ntopng engine
--       - Flow data from packet processing pipeline
--       - Protocol classification via nDPI
--       
--     parameters:
--       - name: ifid
--         in: query
--         schema:
--           type: integer
--           minimum: 1
--           maximum: 255
--         required: true
--         description: |
--           Network Interface Identifier.
--           Corresponds to interface index in ntopng.
--           Use 0 for all interfaces (if supported).
--         example: 1
--       
--       - name: host
--         in: query
--         schema:
--           type: string
--           pattern: '^([0-9]{1,3}\.){3}[0-9]{1,3}(@[0-9]{1,4})?$|^([0-9a-fA-F:]+)(@[0-9]{1,4})?$'
--         required: true
--         description: |
--           Host IP address with optional VLAN tag.
--           Formats:
--           - IPv4: "192.168.1.1"
--           - IPv4 with VLAN: "192.168.1.1@100"
--           - IPv6: "2001:db8::1"
--           - IPv6 with VLAN: "2001:db8::1@200"
--         example: "192.168.1.1"
--       
--       - name: host_stats
--         in: query
--         schema:
--           type: string
--           enum: ["true", "false", "1", "0"]
--           default: "true"
--         required: false
--         description: |
--           Control inclusion of host statistics in response.
--           - "true" or "1": Include host metrics (default)
--           - "false" or "0": Exclude host metrics
--           
--           Host statistics include:
--           - Traffic volumes (bytes sent/received)
--           - Packet counts
--           - Hostname (if resolved)
--           - ASN information
--           - Geographic location
--         example: "true"
--       
--       - name: host_stats_flows
--         in: query
--         schema:
--           type: string
--           enum: ["true", "false", "1", "0"]
--           default: "false"
--         required: false
--         description: |
--           Control inclusion of flow statistics in response.
--           When enabled, returns active flows for the host.
--           
--           Flow statistics include:
--           - Active connections
--           - Protocol distribution
--           - Throughput per flow
--           - TCP state information
--         example: "false"
--       
--       - name: limit
--         in: query
--         schema:
--           type: integer
--           minimum: 1
--           maximum: 100000
--           default: 99999
--         required: false
--         description: |
--           Maximum number of flows to return when host_stats_flows is enabled.
--           Use for performance optimization with hosts having many active connections.
--           
--           Note: Actual limit may be lower based on system resources.
--         example: 100
--     
--     produces:
--       - application/json
--     
--     responses:
--       200:
--         description: |
--           Successful response containing host information.
--           Structure varies based on requested parameters.
--         content:
--           application/json:
--             schema:
--               oneOf:
--                 - $ref: '#/components/schemas/HostBasicInfo'
--                 - $ref: '#/components/schemas/HostWithFlowsInfo'
--             examples:
--               basic_response:
--                 summary: Basic host information (host_stats=true, host_stats_flows=false)
--                 value:
--                   ip: "192.168.1.1"
--                   name: "workstation-01.local"
--                   localhost: true
--                   bytes:
--                     sent: 1524789321
--                     rcvd: 984532147
--                   packets:
--                     sent: 1254789
--                     rcvd: 985632
--               flows_response:
--                 summary: Host information with flows (host_stats_flows=true)
--                 value:
--                   ip: "192.168.1.1"
--                   bytes:
--                     sent: 1524789321
--                     rcvd: 984532147
--                   flows:
--                     - srv.ip: "192.168.1.1"
--                       cli.ip: "8.8.8.8"
--                       proto.ndpi: "DNS"
--                       bytes: 1250
--                   ndpiThroughputStats:
--                     DNS:
--                       cli2srv:
--                         throughput_bps: 1250
--                         throughput_pps: 2
--       400:
--         description: |
--           Invalid request parameters.
--           Common causes:
--           - Missing required parameters
--           - Invalid interface ID
--           - Malformed host IP address
--         content:
--           application/json:
--             schema:
--               $ref: '#/components/schemas/ErrorResponse'
--       401:
--         description: |
--           Authentication required or invalid credentials.
--           Note: Browser clients are redirected to login page.
--         headers:
--           Location:
--             description: Redirect to login page
--             schema:
--               type: string
--       404:
--         description: |
--           Host not found on specified interface.
--           Possible reasons:
--           - Host is not active
--           - Interface monitoring is disabled
--           - Host IP is incorrect
--         content:
--           application/json:
--             schema:
--               $ref: '#/components/schemas/ErrorResponse'
--       500:
--         description: Internal server error
--         content:
--           application/json:
--             schema:
--               $ref: '#/components/schemas/ErrorResponse'
--     
--     components:
--       schemas:
--         HostBasicInfo:
--           type: object
--           properties:
--             ip:
--               type: string
--               description: Host IP address
--             name:
--               type: string
--               description: Resolved hostname (if available)
--             localhost:
--               type: boolean
--               description: True if host is local to the monitored network
--             bytes:
--               type: object
--               properties:
--                 sent:
--                   type: integer
--                   format: int64
--                 rcvd:
--                   type: integer
--                   format: int64
--             packets:
--               type: object
--               properties:
--                 sent:
--                   type: integer
--                 rcvd:
--                   type: integer
--         HostWithFlowsInfo:
--           allOf:
--             - $ref: '#/components/schemas/HostBasicInfo'
--             - type: object
--               properties:
--                 flows:
--                   type: array
--                   items:
--                     $ref: '#/components/schemas/FlowInfo'
--                 ndpiThroughputStats:
--                   type: object
--                   additionalProperties:
--                     $ref: '#/components/schemas/ProtocolThroughput'
--                 flows_count:
--                   type: integer
--                   description: Total number of flows (may be limited by 'limit' parameter)
--         FlowInfo:
--           type: object
--           properties:
--             srv.ip:
--               type: string
--             cli.ip:
--               type: string
--             srv.port:
--               type: integer
--             cli.port:
--               type: integer
--             proto.ndpi_id:
--               type: integer
--             proto.ndpi:
--               type: string
--             bytes:
--               type: integer
--             cli2srv.throughput_bps:
--               type: number
--               format: float
--             srv2cli.throughput_bps:
--               type: number
--               format: float
--             cli2srv.throughput_pps:
--               type: number
--               format: float
--             srv2cli.throughput_pps:
--               type: number
--               format: float
--             cli2srv.tcp_flags:
--               type: object
--               description: TCP flags for client-to-server direction (TCP only)
--             srv2cli.tcp_flags:
--               type: object
--               description: TCP flags for server-to-client direction (TCP only)
--             tcp_established:
--               type: boolean
--               description: TCP connection established state (TCP only)
--         ProtocolThroughput:
--           type: object
--           properties:
--             cli2srv:
--               type: object
--               properties:
--                 throughput_bps:
--                   type: number
--                   format: float
--                 throughput_pps:
--                   type: number
--                   format: float
--             srv2cli:
--               type: object
--               properties:
--                 throughput_bps:
--                   type: number
--                   format: float
--                 throughput_pps:
--                   type: number
--                   format: float
--         ErrorResponse:
--           type: object
--           properties:
--             error:
--               type: object
--               properties:
--                 code:
--                   type: integer
--                 message:
--                   type: string
--                 details:
--                   type: string
--                 timestamp:
--                   type: integer
--                   format: int64

-- Initialize response variables
local rc = rest_utils.consts.success.ok -- HTTP 200 OK response code
local res = {} -- Response data container

-- Parse input parameters from HTTP GET request
local ifid = _GET["ifid"] -- Interface ID (required)
local host_info = url2hostinfo(_GET) -- Parse host IP and optional VLAN from request

-- Parse optional parameters with their default behaviors
local host_stats = _GET["host_stats"] -- Control inclusion of host statistics (default: include)
local host_stats_flows = _GET["host_stats_flows"] -- Control inclusion of flow statistics (default: exclude)
local host_stats_flows_num = _GET["limit"] -- Maximum number of flows to return (when flows enabled)

-- ============================================================================
-- Input Validation Section
-- ============================================================================

-- Validate interface ID parameter
if isEmptyString(ifid) then
   -- Return HTTP 400 Bad Request: Missing or empty interface ID
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

-- Validate host IP address parameter
if isEmptyString(host_info["host"]) then
   -- Return HTTP 400 Bad Request: Missing or empty host address
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- ============================================================================
-- Host Data Retrieval Section
-- ============================================================================

-- Select the specified network interface for subsequent operations
interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   -- interface.select falls back to the interface the user is allowed to see
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

-- Retrieve host information from ntopng monitoring engine
-- Parameters: host IP address, VLAN ID (optional, defaults to 0)
local host = interface.getHostInfo(host_info["host"], host_info["vlan"])

-- Verify host exists on the selected interface
if not host then
   -- Return HTTP 404 Not Found: Host not present on interface
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- ============================================================================
-- Helper Function: Protocol Throughput Aggregation
-- ============================================================================

--- Aggregates flow throughput data by protocol for analysis
-- This function processes an array of flow records and calculates total
-- throughput (bps and pps) for each detected protocol, separated by
-- traffic direction (client-to-server and server-to-client).
--
-- @function flows2protocolthpt
-- @local
-- @param flows table - Array of flow objects containing throughput data
-- @return table - Nested table structure with protocol throughput statistics
-- 
-- @usage
-- local throughput_stats = flows2protocolthpt(flows)
-- print(throughput_stats["HTTP"]["cli2srv"]["throughput_bps"])
--
-- @note
-- - Only flows with valid nDPI protocol classification are processed
-- - Throughput values are summed across all matching flows
-- - Structure supports easy charting and protocol analysis
local function flows2protocolthpt(flows)
   local protocol_thpt = {} -- Initialize empty throughput statistics table

   -- Iterate through all provided flows
   for _, flow in pairs(flows) do
      local proto_ndpi = ""

      -- Skip flows without valid nDPI protocol classification
      if flow["proto.ndpi"] == nil or flow["proto.ndpi"] == "" then
         goto continue -- Use Lua goto for early loop continuation
      else
         proto_ndpi = flow["proto.ndpi"]
      end

      -- Initialize protocol entry if this is the first flow for this protocol
      if protocol_thpt[proto_ndpi] == nil then
         protocol_thpt[proto_ndpi] = {
            ["cli2srv"] = {
               ["throughput_bps"] = 0, -- Bits per second (client → server)
               ["throughput_pps"] = 0 -- Packets per second (client → server)
            },
            ["srv2cli"] = {
               ["throughput_bps"] = 0, -- Bits per second (server → client)
               ["throughput_pps"] = 0 -- Packets per second (server → client)
            }
         }
      end

      -- Aggregate throughput for both traffic directions
      for _, dir in pairs({"cli2srv", "srv2cli"}) do
         for _, dim in pairs({"bps", "pps"}) do
            -- Calculate aggregated throughput by summing individual flow values
            protocol_thpt[proto_ndpi][dir]["throughput_" .. dim] = protocol_thpt[proto_ndpi][dir]["throughput_" .. dim] +
                                                                      flow[dir .. ".throughput_" .. dim]
         end
      end

      ::continue:: -- Label for goto statement (flow skipping)
   end

   return protocol_thpt
end

-- ============================================================================
-- Host Statistics Processing (Conditional)
-- ============================================================================

-- Process host statistics based on request parameter
-- Default behavior: Include statistics unless explicitly disabled
if not (host_stats == nil or host_stats == "" or host_stats == "true" or host_stats == "1") then
   -- Client requested NO host statistics - return empty host object
   host = {}
end

-- ============================================================================
-- Flow Statistics Processing (Conditional)
-- ============================================================================

-- Process flow statistics if explicitly requested by client
if host_stats_flows ~= nil and host_stats_flows ~= "" then
   -- Determine maximum number of flows to retrieve
   if host_stats_flows_num == nil or tonumber(host_stats_flows_num) == nil then
      -- Default: Retrieve up to 99999 flows (effectively all flows)
      host_stats_flows_num = 99999
   else
      -- Use client-specified limit, converted to number
      host_stats_flows_num = tonumber(host_stats_flows_num)
   end

   -- Initialize total flow count (note: currently not populated in this implementation)
   local total = 0

   -- Configure flow retrieval parameters for pagination and sorting
   local pageinfo = {
      ["sortColumn"] = "column_bytes", -- Sort by total bytes transferred
      ["a2zSortOrder"] = false, -- Descending order (largest flows first)
      ["maxHits"] = host_stats_flows_num, -- Maximum number of flows to retrieve
      ["toSkip"] = 0, -- Start from first flow (no skipping)
      ["detailedResults"] = true -- Include detailed flow information
   }

   -- Retrieve flows involving the specified host from ntopng engine
   -- Uses pagination configuration for efficient data retrieval
   local flows = interface.getFlowsInfo(host_info["host"], pageinfo)
   flows = flows["flows"] -- Extract flow array from API response

   -- Transform raw flow data into API response format
   for i, fl in ipairs(flows) do
      -- Create simplified flow object with essential information
      flows[i] = {
         -- Network endpoints
         ["srv.ip"] = fl["srv.ip"], -- Server IP address
         ["cli.ip"] = fl["cli.ip"], -- Client IP address
         ["srv.port"] = fl["srv.port"], -- Server port number
         ["cli.port"] = fl["cli.port"], -- Client port number

         -- Protocol information
         ["proto.ndpi_id"] = fl["proto.ndpi_id"], -- nDPI protocol numeric ID
         ["proto.ndpi"] = fl["proto.ndpi"], -- nDPI protocol human-readable name

         -- Volume metrics
         ["bytes"] = fl["bytes"], -- Total bytes transferred in this flow

         -- Throughput metrics (rounded to 2 decimal places for readability)
         ["cli2srv.throughput_bps"] = round(fl["throughput_cli2srv_bps"], 2), -- Client→server bits/sec
         ["srv2cli.throughput_bps"] = round(fl["throughput_srv2cli_bps"], 2), -- Server→client bits/sec
         ["cli2srv.throughput_pps"] = round(fl["throughput_cli2srv_pps"], 2), -- Client→server packets/sec
         ["srv2cli.throughput_pps"] = round(fl["throughput_srv2cli_pps"], 2) -- Server→client packets/sec
      }

      -- Add TCP-specific information for TCP protocol flows
      if fl["proto.l4"] == "TCP" then
         -- Convert TCP flags bitmask to human-readable table
         flows[i]["cli2srv.tcp_flags"] = TCPFlags2table(fl["cli2srv.tcp_flags"])
         flows[i]["srv2cli.tcp_flags"] = TCPFlags2table(fl["srv2cli.tcp_flags"])

         -- TCP connection state
         flows[i]["tcp_established"] = fl["tcp_established"] -- Boolean: connection fully established
      end
   end

   -- Add aggregated protocol throughput statistics to host data
   host["ndpiThroughputStats"] = flows2protocolthpt(flows)

   -- Add processed flow data to response
   host["flows"] = flows
   host["flows_count"] = total -- Note: Currently not populated, could be enhanced
end

-- ============================================================================
-- Response Preparation and Logging
-- ============================================================================

-- Set final response data
res = host

-- Log API call for auditing and analytics
-- Parameters: event type, array of relevant identifiers
tracker.log("host_get_json", {host_info["host"], host_info["vlan"]})

-- Send HTTP response with appropriate status code and JSON body
rest_utils.answer(rc, res)

-- ============================================================================
-- End of API Implementation
-- ============================================================================
