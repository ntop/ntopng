--
-- (C) 2013-26 - ntop.org
--

return {
   name = "get_live_flows_summary",
   description = "Return an aggregated summary of active flows on the current interface. " ..
      "Optional arguments: ip (string, filter by host), " ..
      "role ('any'|'client'|'server', default 'any'), " ..
      "group_by ('country'|'destination'|'application'|'protocol'|'source', default 'country'), " ..
      "alerted_only (boolean, default false), max_flows (integer, default 500).",
   handler = function(args)
      local host_ip     = args and args.ip
      local role        = ((args and args.role) or "any"):lower()
      local group_by    = ((args and args.group_by) or "country"):lower()
      local alerted_only = args and args.alerted_only and true or false
      local max_hits    = (args and tonumber(args.max_flows)) or 500

      local host_key = host_ip
      if host_ip and args and args.vlan and tonumber(args.vlan) > 0 then
         host_key = host_ip .. "@" .. tostring(args.vlan)
      end

      local pag = { maxHits = max_hits, sortColumn = "column_bytes", a2zSortOrder = false }
      if alerted_only then pag.alertedFlows = true end

      local flows_data
      if host_key then
         if role == "client" then
            flows_data = interface.getFlowsInfo(nil, pag, nil, host_key)
         elseif role == "server" then
            flows_data = interface.getFlowsInfo(nil, pag, nil, nil, host_key)
         else
            flows_data = interface.getFlowsInfo(host_key, pag)
         end
      else
         flows_data = interface.getFlowsInfo(nil, pag)
      end

      if not flows_data or not flows_data.flows then
         return "No active flows found.", nil
      end

      local groups = {}
      local total = { flows = 0, alerted = 0, bytes = 0, score = 0 }

      for _, f in ipairs(flows_data.flows) do
         local bytes      = (f["cli2srv.bytes"] or 0) + (f["srv2cli.bytes"] or 0)
         local pkts       = f["packets"] or 0
         local score      = f["flow_score"] or (f.score and f.score.flow_score) or 0
         local is_alerted = f["flow.alerted"] and 1 or 0

         total.flows   = total.flows   + 1
         total.alerted = total.alerted + is_alerted
         total.bytes   = total.bytes   + bytes
         total.score   = total.score   + score

         local srv_country = f["srv.country"] or "??"
         local cli_country = f["cli.country"] or "??"
         local l7          = f["proto.ndpi"]  or f["application"] or "Unknown"
         local l4          = f["proto.l4"]    or "Unknown"
         local srv_ip      = f["srv.ip"]      or ""
         local cli_ip      = f["cli.ip"]      or ""

         local key
         if group_by == "country" then
            key = srv_country
         elseif group_by == "destination" then
            key = srv_ip
         elseif group_by == "application" then
            key = l7
         elseif group_by == "protocol" then
            key = l4
         elseif group_by == "source" then
            key = cli_country
         else
            key = srv_country
         end

         if not groups[key] then
            groups[key] = { bytes = 0, packets = 0, num_flows = 0, num_alerted = 0, score = 0 }
         end
         local g = groups[key]
         g.bytes       = g.bytes       + bytes
         g.packets     = g.packets     + pkts
         g.num_flows   = g.num_flows   + 1
         g.num_alerted = g.num_alerted + is_alerted
         g.score       = g.score       + score
      end

      local sorted = {}
      for k, v in pairs(groups) do
         sorted[#sorted + 1] = { key = k, bytes = v.bytes, packets = v.packets,
				 num_flows = v.num_flows, num_alerted = v.num_alerted, score = v.score }
      end
      table.sort(sorted, function(a, b) return a.bytes > b.bytes end)

      local ctx = host_ip and ("host=" .. host_ip .. " role=" .. role) or "all hosts"
      local filter_str = alerted_only and " [alerted only]" or ""
      local hdr_line = string.format(
         "Summary for %s%s | group_by=%s | total_flows=%d total_alerted=%d total_bytes=%d total_score=%d",
         ctx, filter_str, group_by, total.flows, total.alerted, total.bytes, total.score)

      local rows = { group_by .. ",num_flows,num_alerted,bytes,packets,score" }
      for _, r in ipairs(sorted) do
         rows[#rows + 1] = string.format("%s,%d,%d,%d,%d,%d",
					 r.key, r.num_flows, r.num_alerted, r.bytes, r.packets, r.score)
      end

      return hdr_line .. "\n" .. table.concat(rows, "\n"), nil
   end,
   opts = { read_only = true }
}
