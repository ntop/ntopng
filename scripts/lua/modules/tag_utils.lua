--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local tag_utils = {}

-- Operator Separator in query strings
tag_utils.SEPARATOR = ';'

-- #####################################

-- Supported operators
tag_utils.tag_operators = {
    ["eq"]  = "=",
    ["neq"] = "!=",
    ["lt"]  = "<",
    ["gt"]  = ">",
    ["gte"] = ">=",
    ["lte"] = "<=",
    ["in"]  = i18n("has"),
    ["nin"] = i18n("does_not_have"),
}

-- #####################################

tag_utils.defined_tags = {
   l7proto = {
      value_type = 'l7_proto',
      i18n_label = i18n('db_search.tags.l7_proto'),
      operators = {'eq', 'neq'}
   },
   l7proto_master = {
      value_type = 'l7_proto',
      i18n_label = i18n('db_search.tags.l7_proto'),
      operators = {'eq', 'neq'}
   },
   l7cat = {
      value_type = 'l7_category',
      i18n_label = i18n('db_search.tags.l7cat'),
      operators = {'eq', 'neq'}
   },
   flow_risk = {
      value_type = 'flow_risk',
      i18n_label = i18n('db_search.tags.flow_risk'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   status = {
      value_type = 'alert_type',
      i18n_label = i18n('db_search.tags.status'),
      operators = {'eq', 'neq'}
   },
   l4proto = {
      value_type = 'l4_proto',
      i18n_label = i18n('db_search.tags.l4proto'),
      operators = {'eq', 'neq'}
   },
   ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.ip'),
      operators = {'eq', 'neq'}
   },
   cli_ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.cli_ip'),
      operators = {'eq', 'neq'}
   },
   srv_ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.srv_ip'),
      operators = {'eq', 'neq'}
   },
   src2dst_dscp = {
      value_type = 'dscp_type',
      i18n_label = i18n('db_search.tags.src2dst_dscp'),
      operators = {'eq', 'neq'}
   },
   dst2src_dscp = {
      value_type = 'dscp_type',
      i18n_label = i18n('db_search.tags.dst2src_dscp'),
      operators = {'eq', 'neq'}
   },
   cli_port = {
      value_type = 'port',
      i18n_label = i18n('db_search.tags.cli_port'),
      operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'}
   },
   srv_port = {
      value_type = 'port',
      i18n_label = i18n('db_search.tags.srv_port'),
      operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'}
   },
   cli_asn = {
      value_type = 'asn',
      i18n_label = i18n('db_search.tags.cli_asn'),
      operators = {'eq', 'neq'}
   },
   srv_asn = {
      value_type = 'asn',
      i18n_label = i18n('db_search.tags.srv_asn'),
      operators = {'eq', 'neq'}
   },
   observation_point_id = {
      value_type = 'id',
      i18n_label = i18n('db_search.tags.observation_point_id'),
      operators = {'eq', 'neq'}
   },
   probe_ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.probe_ip'),
      operators = {'eq', 'neq'}
   },
   vlan_id = {
      value_type = 'id',
      i18n_label = i18n('db_search.tags.vlan_id'),
      operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'}
   },
   src2dst_tcp_flags = {
      value_type = 'flags',
      i18n_label = i18n('db_search.src2dst_tcp_flags'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   dst2src_tcp_flags = {
      value_type = 'flags',
      i18n_label = i18n('db_search.dst2src_tcp_flags'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   score = {
      value_type = 'score',
      i18n_label = i18n('db_search.tags.score'),
      operators = {'eq', 'neq','lt', 'gt', 'gte', 'lte'}
   },
}

-- ##############################################

--@brief Evaluate operator
function tag_utils.eval_op(v1, op, v2)
   local default_verdict = true

   -- Convert boolean for compatibility
   if type(v1) == 'boolean' then
      if v1 then v1 = 1 else v1 = 0 end
   end

   if not v1 or not v2 then
      return default_verdict
   end

   if op == 'eq' then
      return v1 == v2
   elseif op == 'neq' then
      return v1 ~= v2
   elseif op == 'lt' then
      return v1 < v2
   elseif op == 'gt' then
      return v1 > v2
   elseif op == 'gte' then
      return v1 >= v2
   elseif op == 'lte' then
      return v1 <= v2
   elseif op == 'in' then
      v_and = v1 & v2
      return v1 == v_and
   elseif op == 'nin' then
      v_and = v1 & v2
      return v1 ~= v_and
   end 

   return default_verdict
end

-- #####################################

-- This table is done to convert tags to their where 
tag_utils.nindex_tags_to_where_v4 = {
   ["srv_ip"]   = {[4] = "IPV4_DST_ADDR", [6] = "IPV6_DST_ADDR"},
   ["cli_ip"]   = {[4] = "IPV4_SRC_ADDR", [6] = "IPV6_SRC_ADDR"},
   ["cli_port"] = "IP_SRC_PORT",
   ["srv_port"] = "IP_DST_PORT",
   ["vlan_id"]  = "VLAN_ID",
   ["status"]   = "STATUS",
   ["l7proto"]  = "L7_PROTO",
   ["l4proto"]  = "PROTOCOL",
   ["l7cat"]    = "L7_CATEGORY",
   ["flow_risk"]   = "FLOW_RISK",
   ["packets"]     = "PACKETS",
   ["traffic"]     = "TOTAL_BYTES",
   ["first_seen"]  = "FIRST_SEEN",
   ["last_seen"]   = "LAST_SEEN",
   ["src2dst_dscp"] = "SRC2DST_DSCP",
   ["dst2src_dscp"] = "DST2SRC_DSCP",
   ["info"]         = "INFO",
   ["srv_label"]    = "DST_LABEL",
   ["cli_label"]    = "SRC_LABEL",
   ["cli_asn"]      = "SRC_ASN",
   ["cli_asname"]   = "SRC_ASNAME",
   ["srv_asn"]      = "DST_ASN",
   ["srv_asname"]   = "DST_ASNAME",
   ["observation_point_id"] = "OBSERVATION_POINT_ID",
   ["probe_ip"]     = "PROBE_IP",
   --["throughput"]   = "THROUGHPUT",
   ["src2dst_tcp_flags"] = "SRC2DST_TCP_FLAGS",
   ["dst2src_tcp_flags"] = "DST2SRC_TCP_FLAGS",
   ["l7proto_master"]  = "L7_PROTO_MASTER",
   ["score"] = "SCORE",
}

-- #####################################

tag_utils.db_columns_to_tags = {
   ["IPV4_DST_ADDR"] = "srv_ip",
   ["IPV6_DST_ADDR"] = "srv_ip", 
   ["IPV4_SRC_ADDR"] = "cli_ip", 
   ["IPV6_SRC_ADDR"] = "cli_ip", 
   ["IP_SRC_PORT"] = "cli_port", 
   ["IP_DST_PORT"] = "srv_port", 
   ["STATUS"] = "status",   
   ["L7_PROTO"] = "l7proto",  
   ["L7_PROTO_MASTER"] = "l7proto_master",  
   ["PROTOCOL"] = "l4proto",  
   ["L7_CATEGORY"] = "l7cat",    
   ["FLOW_RISK"] = "flow_risk",   
   ["PACKETS"] = "packets",     
   ["TOTAL_BYTES"] = "traffic",     
   ["FIRST_SEEN"] = "first_seen",  
   ["LAST_SEEN"] = "last_seen",   
   ["SRC2DST_DSCP"] = "src2dst_dscp", 
   ["DST2SRC_DSCP"] = "dst2src_dscp", 
   ["INFO"] = "info",         
   ["DST_LABEL"] = "srv_label",    
   ["SRC_LABEL"] = "cli_label",    
   ["SRC_ASN"] = "cli_asn",      
   ["SRC_ASNAME"] = "cli_asname",   
   ["DST_ASN"] = "srv_asn",      
   ["DST_ASNAME"] = "srv_asname",   
   ["OBSERVATION_POINT_ID"] = "observation_point_id", 
   ["PROBE_IP"] = "probe_ip",     
   ["SRC2DST_TCP_FLAGS"] = "src2dst_tcp_flags", 
   ["DST2SRC_TCP_FLAGS"] = "dst2src_tcp_flags", 
   ["SCORE"] = "score", 
   ["VLAN_ID"] = "vlan_id", 

   --[[ Not defined:
   ["INTERFACE_ID"] = "", 
   ["IP_PROTOCOL_VERSION"] = "", 
   ["FLOW_TIME"] = "", 
   ["SRC2DST_BYTES"] = "", 
   ["DST2SRC_BYTES"] = "", 
   ["PROFILE"] = "", 
   ["SRC_COUNTRY_CODE"] = "", 
   ["DST_COUNTRY_CODE"] = "", 
   ["SRC_MAC"] = "", 
   ["DST_MAC"] = "", 
   ["COMMUNITY_ID"] = "", 
   --]]
}

-- Return a table with a list of DB columns for each tag
-- Example:
-- { ["srv_ip"] = ["IPV4_DST_ADDR"], ["IPV6_DST_ADDR"], .. }
function tag_utils.get_db_tags_to_columns()
   local t2c = {}

    for c, t in pairs(tag_utils.db_columns_to_tags) do
       if not t2c[t] then
          t2c[t] = {}
       end
       t2c[t][#t2c[t] + 1] = c
    end

    return t2c
end

-- Return DB select by tag
-- Example: 'srv_ip' -> "IPV4_DST_ADDR, IPV6_DST_ADDR"
function tag_utils.get_db_select_by_tag(tag)
   local tags_to_columns = tag_utils.get_db_tags_to_columns()
   local s = ''

   ::next::
   if tags_to_columns[tag] then
      for _, column in ipairs(tags_to_columns[tag]) do
         if isEmptyString(s) then
            s = column
         else
            s = s .. ', ' .. column
         end
      end

      -- l7proto also includes l7proto_master
      if tag == 'l7proto' then
         tag = 'l7proto_master'
         goto next
      end
   end

   return s
end

-- Return DB column by tag
-- First or ip_version-based in case of multiple
-- nil in case of undefined tag
function tag_utils.get_db_column_by_tag(tag, ip_version)
   local tags_to_columns = tag_utils.get_db_tags_to_columns()

   if tags_to_columns[tag] then
      if tag:ends('ip') and ip_version and ip_version == 6 then
         return tags_to_columns[tag][2]
      end

      return tags_to_columns[tag][1]
   end

   return nil
end

tag_utils.extra_db_columns = {
   ["throughput"] = "(LAST_SEEN - FIRST_SEEN) as TIME_DELTA, (TOTAL_BYTES / (TIME_DELTA + 1)) * 8 as THROUGHPUT",
   ["ip_version"] = "IP_PROTOCOL_VERSION",
   ["vlan_id"]    = "VLAN_ID",
   ["src_label"]  = "SRC_LABEL",
   ["dst_label"]  = "DST_LABEL",
}

tag_utils.ordering_special_columns = {
   ["srv_ip"]   = {[4] = "IPv4StringToNum(IPV4_DST_ADDR)", [6] = "IPv6StringToNum(IPV6_DST_ADDR)"},
   ["cli_ip"]   = {[4] = "IPv4StringToNum(IPV4_SRC_ADDR)", [6] = "IPv6StringToNum(IPV6_SRC_ADDR)"},
   ["l7proto"]  = "L7_PROTO_MASTER",
   ["throughput"] = "THROUGHPUT"
}

tag_utils.extra_where_tags = {
   ["ip"]       = { [4] = { "IPV4_DST_ADDR", "IPV4_SRC_ADDR" } , [6] = { "IPV6_DST_ADDR", "IPV6_SRC_ADDR" } },
   ["srv_ip"]   = {[4] = "IPV4_DST_ADDR", [6] = "IPV6_DST_ADDR"},
   ["cli_ip"]   = {[4] = "IPV4_SRC_ADDR", [6] = "IPV6_SRC_ADDR"},
   ["l7proto"] = { "L7_PROTO_MASTER", "L7_PROTO" },
   ["src_label"]  = "SRC_LABEL",
   ["dst_label"]  = "DST_LABEL",
}

-- #####################################

tag_utils.orders = {
   ["asc"]  = "ASC",
   ["desc"] = "DESC",
}

-- #####################################

tag_utils.topk_tags_v4 = {
   ["host"]   = {
      "IPV4_DST_ADDR",
      "IPV4_SRC_ADDR",
   },
   ["protocol"] = {
      "L7_PROTO",
   }
}

-- #####################################

tag_utils.topk_tags_v6 = {
   ["host"]   = {
      "IPV6_DST_ADDR",
      "IPV6_SRC_ADDR",
   },
   ["protocol"] = {
      "L7_PROTO",
   }
}

-- #####################################

function tag_utils.add_tag_if_valid(tags, tag_key, operators, formatters, i18n_prefix)
    
   if isEmptyString(_GET[tag_key]) then
      return
   end

   local get_value = _GET[tag_key]
   local list = split(get_value, ',')

   for _,item in ipairs(list) do
      local selected_operator = 'eq'

      local splitted = split(item, tag_utils.SEPARATOR)

      local realValue
      if #splitted == 2 then
         realValue = splitted[1]
         selected_operator = splitted[2]
      end

      local value = realValue
      if formatters[tag_key] ~= nil then
         value = formatters[tag_key](value)
      end

      tag = {
         realValue = realValue,
         value = value,
         label = i18n(i18n_prefix .. "." .. tag_key),
         key = tag_key,
         operators = operators,
         selectedOperator = selected_operator
      }

      table.insert(tags, tag)
   end
end

-- #####################################

local function build_datatable_js_column_ip(name, data_name, label, order)
   return {
      i18n = label,
      order = order,
      js = [[
      {name: ']] .. name .. [[', data: ']] .. data_name .. [[', width: '12%', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        let html_ref = '';
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined) {
            if (]] .. name .. [[.reference !== undefined)
                html_ref = ]] .. name .. [[.reference;
            return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a> ${html_ref}`;
        }}}]] }
end

-- #####################################

local function build_datatable_js_column_port(name, data_name, label, order)
   return {
      i18n = label,
      order = order,
      js = [[
      {name: ']] .. name .. [[', data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
          if (type !== 'display') return ]] .. name .. [[;
          if (]] .. name .. [[ !== undefined)
             return `<a class='tag-filter' data-tag-value='${]] .. name .. [[}' href='#'>${]] .. name .. [[}</a>`;
      }}]] 
   }
end

-- #####################################

local function build_datatable_js_column_asn(name, data_name, label, order)
   return {
      i18n = label,
      order = order,
      js = [[
      {name: ']] .. name .. [[', data: ']] .. data_name .. [[', width: '5%', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined) {
          return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
      }}}]] }
end

-- #####################################

local function build_datatable_js_column_packets(name, data_name, label, order)
   return {
      i18n = label,
      order = order,
      js = [[
      {name: ']] .. name .. [[', data: ']] .. data_name .. [[', width: '5%', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined)
          return NtopUtils.formatPackets(]] .. name .. [[);
      }}]]
   }
end

-- #####################################

local function build_datatable_js_column_bytes(name, data_name, label, order)
   return {
      i18n = label,
      order = order,
      js = [[
      {name: ']] .. name .. [[', data: ']] .. data_name .. [[', width: '7%', className: 'no-wrap'}]] 
   }
end

-- #####################################

local function build_datatable_js_column_tcp_flags(name, data_name, label, order)
   return {
      i18n = label,
      order = order,
      js = [[
        {name: ']] .. name .. [[', data: ']] .. data_name .. [[', width: '5%', className: 'no-wrap', render: (]] .. name .. [[, type) => {
          if (type !== 'display') return ]] .. name .. [[;
          if (]] .. name .. [[ !== undefined)
            return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
        }}]] }
end

-- #####################################

local function build_datatable_js_column_dscp(name, data_name, label, order)
   return {
      i18n = label,
      order = order,
      js = [[
        {name: ']] .. name .. [[', data: ']] .. data_name .. [[', width: '5%', className: 'no-wrap', render: (]] .. name .. [[, type) => {
            if (type !== 'display') return ]] .. name .. [[;
            if (]] .. name .. [[ !== undefined)
               return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
        }}]] }
end

-- #####################################

tag_utils.datatable_js_columns = {
   ['vlan_id'] = {
      i18n = i18n("db_search.vlan_id"),
      order = 1,
      js = [[
        {name: 'vlan_id', data: 'vlan_id', visible: ]] ..ternary(interface.hasVLANs(), "true", "false").. [[, className: 'no-wrap', render: (vlan_id, type) => {
            if (type !== 'display') 
                return vlan_id;
            if (vlan_id !== undefined)
                return `<a class='tag-filter' data-tag-value='${vlan_id.value}' title='${vlan_id.title}' href='#'>${vlan_id.label}</a>`;
        }}]] },
   ['cli_ip'] = build_datatable_js_column_ip('cli_ip', 'client', i18n("db_search.client"), 2),
   ['srv_ip'] = build_datatable_js_column_ip('srv_ip', 'server', i18n("db_search.server"), 3),
   ['cli_port'] = build_datatable_js_column_port('cli_port', 'cli_port', i18n("db_search.cli_port"), 4),
   ['srv_port'] = build_datatable_js_column_port('srv_port', 'srv_port', i18n("db_search.srv_port"), 5),
   ['l4proto'] = {
      i18n = i18n("db_search.l4proto"),
      order = 6,
      js = [[
      {name: 'l4proto', data: 'proto', className: 'no-wrap', render: (l4proto, type) => {
        if (type !== 'display') return l4proto;
        if (l4proto !== undefined)
           return `<a class='tag-filter' data-tag-value='${l4proto.label}' data-tag-realvalue='${l4proto.value}' title='${l4proto.title}' href='#'>${l4proto.label}</a>`;
      }}]] },
   ['l7proto'] = {
      i18n = i18n("db_search.l7proto"),
      order = 7,
      js = [[
      {name: 'l7proto', data: 'l7proto', width: '5%', className: 'no-wrap', render: (proto, type, row) => {
        if (type !== 'display') return proto;
        if (proto !== undefined) {
           let label = '';
           if (row.l7proto_master !== undefined 
               && row.l7proto_master.value !== undefined
               && row.l7proto_master.value !== 0
               && row.l7proto_master.value != proto.value) {
             label += row.l7proto_master.label + ".";
           }
           label += proto.label;
           return `<a class='tag-filter' data-tag-value='${proto}' title='${proto.title}' href='#'>${label}</a>`;
        }
      }}]] },
   ['score'] = {
      i18n = i18n("score"),
      order = 8,
      js = [[
      {name: 'score', data: 'score', className: 'text-right', render: (score, type) => {
        if (type !== 'display') return score;
        if (score !== undefined)
          return `<a class='tag-filter' data-tag-value='${score.value}' href='#'><span style='color: ${score.color}'>` + NtopUtils.fint(score.value) + `</span></a>`;
      }}]] },
   ['packets'] = build_datatable_js_column_packets('packets', 'packets', i18n("db_search.packets"), 9),
   ['traffic'] = build_datatable_js_column_bytes('traffic', 'traffic', i18n("db_search.bytes"), 10),
   ['throughput'] = {
      i18n = i18n("db_search.throughput"),
      order = 11,
      js = [[
      {name: 'throughput', data: 'throughput', width: '7%', className: 'no-wrap'}]] },
   ['first_seen'] = {
      i18n = i18n("db_search.first_seen"),
      order = 12,
      js = [[
      {name: 'first_seen', data: 'first_seen', width: '7% no-wrap', className: 'no-wrap'}]] },
   ['last_seen'] = {
      i18n = i18n("db_search.last_seen"),
      order = 13,
      js = [[
      {name: 'last_seen', data: 'last_seen', width: '7%', className: 'no-wrap'}]] },
   ['cli_asn'] = build_datatable_js_column_asn('cli_asn', 'cli_asn', i18n("db_search.cli_asn"), 14),
   ['srv_asn'] = build_datatable_js_column_asn('srv_asn', 'srv_asn', i18n("db_search.srv_asn"), 15),
   ['l7cat'] = {
      i18n = i18n("db_search.l7cat"),
      order = 16,
      js = [[
      {name: 'l7cat', data: 'l7cat', className: 'no-wrap', render: (l7cat, type) => {
        if (type !== 'display') return l7cat;
        if (l7cat !== undefined) {
           const label = (l7cat.label || l7cat.value);
           const value = l7cat.value;
           return `<a class='tag-filter' data-tag-value='${value}' title='${l7cat.title}' href='#'>${label}</a>`;
        }
      }}]] },
   ['status'] = {
      i18n = i18n("db_search.status"),
      order = 17,
      js = [[
      {name: 'status', data: 'status', width: '5%', className: 'no-wrap', render: (status, type) => {
        if (type !== 'display') return status;
        if (status !== undefined)
           return `<a class='tag-filter' data-tag-value='${status.value}' title='${status.title}' href='#'>${status.label}</a>`;
      }}]] },
   ['flow_risk'] = {
      i18n = i18n("db_search.flow_risk"),
      order = 18,
      js = [[
      {name: 'flow_risk', data: 'flow_risk', className: 'no-wrap', render: (flow_risks, type) => {
        if (type !== 'display') return flow_risks;
        if (flow_risks !== undefined) {
           let res = [];

           for (let i = 0; i < flow_risks.length; i++) {
             const flow_risk = flow_risks[i];
             const flow_risk_label = (flow_risk.label || flow_risk.value);
             const flow_risk_help = (flow_risk.help);
             // res.push(`<a class='tag-filter' data-tag-value='${flow_risk.value}' title='${flow_risk.title}' href='#'>${flow_risk_label}</a>`);
             res.push(`${flow_risk_label} ${flow_risk_help}`);
           }
           return res.join(', ');
        }
      }}]] },
   ['src2dst_tcp_flags'] = build_datatable_js_column_tcp_flags('src2dst_tcp_flags', 'src2dst_tcp_flags', i18n("db_search.src2dst_tcp_flags"), 19),
   ['dst2src_tcp_flags'] = build_datatable_js_column_tcp_flags('dst2src_tcp_flags', 'dst2src_tcp_flags', i18n("db_search.dst2src_tcp_flags"), 20),
   ['src2dst_dscp'] = build_datatable_js_column_dscp('src2dst_dscp', 'src2dst_dscp', i18n("db_search.src2dst_dscp"), 21),
   ['dst2src_dscp'] = build_datatable_js_column_dscp('dst2src_dscp', 'dst2src_dscp', i18n("db_search.dst2src_dscp"), 22),
   ['info'] = {
      i18n = i18n("db_search.info"),
      order = 23,
      js = [[
        {name: 'info', data: 'info', orderable: false, width: '20%', render: (info, type) => {
            if (type !== 'display') return info;
            if (info !== undefined)
                return `<span title='${info.title}'>${info.label}</span>`
        }}]] },
   ['observation_point_id'] = {
      i18n = i18n("db_search.observation_point_id"),
      order = 24,
      js = [[
        {name: 'observation_point_id', data: 'observation_point_id', visible: ]] ..ternary(not interface.isPacketInterface(), "true", "false").. [[, width: '5%', className: 'no-wrap', render: (observation_point_id, type) => {
            if (type !== 'display') return observation_point_id;
            if (observation_point_id !== undefined)
               return `<a class='tag-filter' data-tag-value='${observation_point_id.value}' title='${observation_point_id.title}' href='#'>${observation_point_id.label}</a>`;
        }}]] },
   ['probe_ip'] = {
      i18n = i18n("db_search.probe_ip"),
      order = 25,
      js = [[
        {name: 'probe_ip', data: 'probe_ip', visible: ]] ..ternary(not interface.isPacketInterface(), "true", "false").. [[, width: '5%', className: 'no-wrap', render: (probe_ip, type) => {
            if (type !== 'display') return probe_ip;
            if (probe_ip !== undefined)
               //return `<span title='${probe_ip.title}'>${probe_ip.label}</span>`;
                return `<a class='tag-filter' data-tag-value='${probe_ip.value}' title='${probe_ip.title}' href='#'>${probe_ip.label}</a>`;
        }}]] },
}

-- #####################################

local function order_asc(a, b)
   return asc(a.order, b.order)
end

function tag_utils.get_datatable_js_columns() 
   local str = "["
   for _, column in pairsByValues(tag_utils.datatable_js_columns, order_asc) do
      str = str .. column.js .. ","
   end
   str = str .. "]"

   return str
end

function tag_utils.get_datatable_i18n_columns() 
   local columns = {}

   for _, column in pairsByValues(tag_utils.datatable_js_columns, order_asc) do
      columns[#columns + 1] = column.i18n
   end

   return columns
end

-- #####################################

return tag_utils
