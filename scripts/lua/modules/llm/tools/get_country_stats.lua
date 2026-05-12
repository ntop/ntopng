return {
   name = "get_country_stats",
   description = "Return top-N countries ranked by traffic seen on the current interface. " ..
      "Each entry contains the country code, number of hosts, bytes sent, bytes received, " ..
      "reputation score, and first-seen timestamp. " ..
      "Optional args: limit (integer, default 20), sort_by ('bytes'|'hosts'|'score', default 'bytes').",
   handler = function(args)
      local limit   = tonumber(args and args.limit) or 20
      local sort_by = (args and args.sort_by) or "bytes"
      local col_map = { bytes = "column_bytes", hosts = "column_num_hosts", score = "column_score" }
      local sort_col = col_map[sort_by] or "column_bytes"

      local info = interface.getCountriesInfo({
         sortColumn   = sort_col,
         a2zSortOrder = false,
         detailsLevel = "higher",
         maxHits      = limit,
      })

      if not info or not info.Countries then
         return "No country data available.", nil
      end

      local rows = { "country_code,num_hosts,bytes_sent,bytes_rcvd,score,first_seen" }
      for _, c in ipairs(info.Countries) do
         rows[#rows + 1] = string.format("%s,%d,%d,%d,%d,%d",
            c.country or "??", c.num_hosts or 0,
            (c.bytes and c.bytes.sent or 0), (c.bytes and c.bytes.rcvd or 0),
            c.score or 0, c["seen.first"] or 0)
      end
      return table.concat(rows, "\n"), nil
   end,
   opts = { read_only = true }
}
