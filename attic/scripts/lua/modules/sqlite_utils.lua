--
-- (C) 2014-15 - ntop.org
--

-- This file contains the description of all functions
-- used to interact with sqlite

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "template"
local j = require ("dkjson")

local SqliteClass = {} -- the table representing the class, which will double as the metatable for the instances
SqliteClass.__index = SqliteClass -- failed table lookups on the instances should fallback to the class table, to get methods

-- syntax equivalent to "SqliteClass.new = function..."
function SqliteClass.new(init)
  local self = setmetatable({}, SqliteClass)

  self.debug = false
  self.class_benchmark = os.clock()
  self.query_benchmark = os.clock()
  self.flows_benchmark = os.clock()

  -- Template
  self.flow_template = {
  ["IPV4_SRC_ADDR"]   = function (table,val) table["cli.ip"]          = val           end,
  ["L4_SRC_PORT"]     = function (table,val) table["cli.port"]        = tonumber(val) end,
  ["IPV4_DST_ADDR"]   = function (table,val) table["srv.ip"]          = val           end,
  ["L4_DST_PORT"]     = function (table,val) table["srv.port"]        = tonumber(val) end,
  ["PROTOCOL"]        = function (table,val)
  if (l4_template[tonumber(val)] ~= nil ) then
    table["proto.l4"]        = l4_template[tonumber(val)]
  else
    table["proto.l4"]        = val
  end
  end,
    -- ["SRC_VLAN"]        = function (table,val) table["vlan"]            = tonumber(val) end,
    -- ["DST_VLAN"]        = function (table,val) table["vlan"]            = tonumber(val) end,
    ["L7_PROTO_NAME"]   = function (table,val) table["proto.ndpi"]      = val           end,
    ["TCP_FLAGS"]       = function (table,val) table["tcp_flags"]       = tonumber(val) end,
    ["OUT_PKTS"]        = function (table,val) table["cli2srv.packets"] = tonumber(val) end,
    ["OUT_BYTES"]       = function (table,val) table["cli2srv.bytes"]   = tonumber(val) end,
    ["IN_PKTS"]         = function (table,val) table["srv2cli.packets"] = tonumber(val) end,
    ["IN_BYTES"]        = function (table,val) table["srv2cli.bytes"]   = tonumber(val) end,
  }

  -- Query
  self.response = nil
  self.db = nil;
  self.query = nil;
  self.number_rows = 0;

  -- Flows
  self.flows = nil
  self.flows_num = 0


  return self
end

-- ###################################
-- Getter and setter

function SqliteClass.setDebug(self, bool)
  if (bool == nil) then bool = false end
  self.debug = bool
  return self.debug
end

function SqliteClass.getDebug(self)     return self.debug end
function SqliteClass.getFlows(self)     return self.flows end
function SqliteClass.getFlowsNum(self)  return self.flows_num end
function SqliteClass.getResponse(self)  return self.response end
function SqliteClass.getDB(self)        return self.db end
function SqliteClass.getQuery(self)     return self.query end


-- ###################################

function SqliteClass.execQuery(self, db ,query)
  if (db == nil) then return -1 end
  if (query == nil) then return -2 end

  self.db = db;
  self.query = query;

  self.query_benchmark = os.clock()
  -- io.write(dirs.workingdir ..db..'\n')
  self.response = ntop.execQuery(dirs.workingdir ..db , query)
  n_rows = ntop.execQuery(dirs.workingdir ..db , "SELECT COUNT (*) as rows_number FROM flows")

  if (n_rows ~= nil) then
    self.number_rows = n_rows[1]["rows_number"]
  end

  Sqlite:benchmark("query",os.clock())

  return self.response
end

-- ###################################

function SqliteClass.getFlows(self)
  if (self.response == nil) then return nil end
  -- Init some parameters
  self.flows_benchmark = os.clock()
  self.flows = {}
  num = 0

  for _k,_v in pairs(self.response) do

       -- init table of table
       self.flows[num] = {}
       self.flows[num]["ID"] = tonumber(self.response[_k]["ID"])
       self.flows[num]["vlan"] = tonumber(self.response[_k]["vlan_id"])
       self.flows[num]["bytes"] = tonumber(self.response[_k]["bytes"])
       self.flows[num]["duration"] = tonumber(self.response[_k]["duration"])

       -- Throughput
       -- io.write((self.flows[num]["bytes"] / self.flows[num]["duration"])..'\n')
       self.flows[num]["throughput_bps"] = (self.flows[num]["bytes"] / 8 ) / (self.flows[num]["duration"])
       self.flows[num]["throughput_trend_bps"] = 3


       local info, pos, err = j.decode(self.response[_k]["json"], 1, nil)

       if (info == nil) then
        traceError(TRACE_ERROR,TRACE_CONSOLE,"Impossible read json form sqlite: ".. err)
      else
        for key,val in pairs(info) do
          label_key = nil

          -- Check if the option --jsonlabes is active
          if (rtemplate[tonumber(key)] ~= nil) then label_key = rtemplate[tonumber(key)] end
          if (template[key] ~= nil) then label_key = key end

          -- Convert template id into template name
          if (label_key ~= nil) then

            if (self.flow_template[label_key] ~= nil) then
              -- Call conversion function in order to convert some value to number if it is necessary
              self.flow_template[label_key](self.flows[num],val)
            else
              -- Leave the default key and value
              self.flows[num][key] = val
            end

          end
        end -- info loop

        -- Custom parameters
        if (self.flows[num]["proto.ndpi"] == nil) then
          self.flows[num]["proto.ndpi"] = "Unknown"
        end
      end -- info == nil

      num = num + 1
    end -- for


    -- self.writeFlows(self)
    self.flows_num = num
    Sqlite:benchmark("flows",os.clock())

    return self.flows
  end


-- ###################################

function SqliteClass.getRowsNumber(self)
  return (self.number_rows);
end

-- ###################################
-- Utils

function SqliteClass.benchmark(self,type,time)
  if ((time ~= nil) and (self.debug))then
    bk_text = "class"
    bk = self.class_benchmark

    if (type == "query") then
     bk = self.query_benchmark
     bk_text = type
     elseif (type == "flows") then
      bk = self.flows_benchmark
      bk_text = type
    end

    traceError(TRACE_DEBUG,TRACE_CONSOLE,string.format(bk_text .. ": elapsed time: %.4f", time - bk))
  end
end

---------------------------------------

function SqliteClass.writeFlows(self)
  if (self.flows ~= nil) then
    for key,val in pairs(self.flows) do
      traceError(TRACE_DEBUG,TRACE_CONSOLE,'Flow: '..key)
      for k,v in pairs(self.flows[key]) do
        traceError(TRACE_DEBUG,TRACE_CONSOLE,'\t'..k..' - '..v)
      end
    end
  end
end


function getParameters(datetime,action)

  datetime_tbl = cleanDateTime(datetime, action)

  datetime_tbl["displayed"] = os.date("%m/%d/%Y %I:%M %p",datetime_tbl["epoch"])
  traceError(TRACE_DEBUG,TRACE_CONSOLE,'Displayed: ['..datetime_tbl["displayed"] .. ']')
  datetime_tbl["query"] = os.date("/%Y/%m/%d/%H/%M",datetime_tbl["epoch"])
  traceError(TRACE_DEBUG,TRACE_CONSOLE,'query: ['..datetime_tbl["query"] .. ']')

  return datetime_tbl
end



function cleanDateTime(datetime,action)

  if (datetime == nil) then return {} end
  traceError(TRACE_DEBUG,TRACE_CONSOLE,'Initial date and time: '..datetime)

  tbl = split(datetime," ")
  q_date = tbl[1]
  q_time = tbl[2]
  q_type = tbl[3]

  traceError(TRACE_DEBUG,TRACE_CONSOLE,'Default value: ['..q_date..']['..q_time .. '][' .. q_type..']')

  date_tbl  = split(q_date,"/")
  q_month    = tonumber(date_tbl[1])
  q_day      = tonumber(date_tbl[2])
  q_year     = tonumber(date_tbl[3])

  traceError(TRACE_DEBUG,TRACE_CONSOLE,'Default value: ['..q_day..']['..q_month .. '][' .. q_year..']')

  time_tbl = split(q_time,":")
  q_hour   = tonumber(time_tbl[1])
  q_min  = tonumber(time_tbl[2])

  if (q_type == "PM") then q_hour = q_hour + 12 end

  traceError(TRACE_DEBUG,TRACE_CONSOLE,'Default value: ['..q_hour..']['..q_min .. ']')

  q_epoch = os.time({year=q_year, month=q_month, day=q_day, hour=q_hour, min=q_min})

  traceError(TRACE_DEBUG,TRACE_CONSOLE,'epoch: ['.. q_epoch ..']')

  if (action ~= nil) then
    if (action == "newer") then
      q_epoch = q_epoch + 300 -- plus 5 min
    else
      q_epoch = q_epoch - 300 -- min 5 min
    end
  end

  mktime = os.date("%m/%d/%Y %I:%M %p", q_epoch)

  traceError(TRACE_DEBUG,TRACE_CONSOLE,'time: ['.. mktime ..']')

  ret_tbl = {}
  ret_tbl["year"] = q_year
  ret_tbl["month"] = month
  ret_tbl["day"] = q_day

  ret_tbl["q_hour"] = q_q_hour
  ret_tbl["q_min"] = q_q_min

  ret_tbl["epoch"] = q_epoch

  return ret_tbl

end

-- ###################################

-- Don't remove below line
Sqlite = SqliteClass.new()
-- Sqlite:benchmark(os.clock())
Sqlite:setDebug(false)
