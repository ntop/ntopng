--
-- (C) 2013-26 - ntop.org
--

return {
   name = "get_live_flows_for_host",
   description = "Return active (live) flows involving a specific IP address on the current interface. " ..
      "Each row contains client IP:port, server IP:port, L4 protocol, application protocol, " ..
      "bytes, packets, duration, score, and whether the flow is alerted. " ..
      "Required argument: ip (string). " ..
      "Optional: vlan (integer, default 0), max_flows (integer, default 25), " ..
      "role ('any'|'client'|'server', default 'any'), alerted_only (boolean, default false).",
   handler = function(args)
      if not args or not args.ip then
         return nil, "Missing required argument: ip"
      end
      local host_ip     = tostring(args.ip)
      local vlan_id     = tonumber(args.vlan) or 0
      local max_hits    = tonumber(args.max_flows) or 25
      local role        = (args.role or "any"):lower()
      local alerted_only = args.alerted_only and true or false

      local host_key = host_ip
      if vlan_id > 0 then host_key = host_ip .. "@" .. tostring(vlan_id) end

      local pag = { maxHits = max_hits, sortColumn = "column_bytes", a2zSortOrder = false }
      if alerted_only then pag.alertedFlows = true end

      local flows_data
      if role == "client" then
         flows_data = interface.getFlowsInfo(nil, pag, nil, host_key)
      elseif role == "server" then
         flows_data = interface.getFlowsInfo(nil, pag, nil, nil, host_key)
      else
         flows_data = interface.getFlowsInfo(host_key, pag)
      end

      if not flows_data or not flows_data.flows then
         return "No active flows found for " .. host_ip, nil
      end

      local rows = { "cli_ip,cli_port,cli_country,srv_ip,srv_port,srv_country,l4_proto,app_proto,bytes_cli2srv,bytes_srv2cli,packets,duration_sec,score,alerted" }
      for _, f in ipairs(flows_data.flows) do
         rows[#rows + 1] = string.format("%s,%d,%s,%s,%d,%s,%s,%s,%d,%d,%d,%d,%d,%s",
					 f["cli.ip"] or "", f["cli.port"] or 0, f["cli.country"] or "",
					 f["srv.ip"] or "", f["srv.port"] or 0, f["srv.country"] or "",
					 f["proto.l4"] or "", f["proto.ndpi"] or f["application"] or "",
					 f["cli2srv.bytes"] or 0, f["srv2cli.bytes"] or 0,
					 f["packets"] or 0, f["duration"] or 0,
					 (f["flow_score"] or (f.score and f.score.flow_score) or 0),
					 (f["flow.alerted"] and "yes" or "no"))
      end

      local hdr = string.format("Active flows for %s role=%s alerted_only=%s (showing %d of %d total)\n",
				host_ip, role, tostring(alerted_only), #flows_data.flows, flows_data.numFlows or #flows_data.flows)
      return hdr .. table.concat(rows, "\n"), nil
   end,
   opts = { read_only = true }
}
