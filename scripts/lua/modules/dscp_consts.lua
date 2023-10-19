--
-- (C) 2020-22 - ntop.org
--
-- This file contains DSCP constats

local dscp_consts = {}

local clock_start = os.clock()

-- ################################################################################

local DSCP = {
   [0x00] = "Best Effort [CS0]",
   [0x01] = "LE",
   [0x08] = "Priority [CS1]",
   [0x0A] = "Priority [AF11]",
   [0x0C] = "Priority [AF12]",
   [0x0E] = "Priority [AF13]",
   [0x10] = "Immediate [CS2]",
   [0x12] = "Immediate [AF21]",
   [0x14] = "Immediate [AF22]",
   [0x16] = "Immediate [AF23]",
   [0x18] = "Flash/Voice [CS3]",
   [0x1A] = "Flash/Voice [AF31]",
   [0x1C] = "Flash/Voice [AF32]",
   [0x1E] = "Flash/Voice [AF33]",
   [0x20] = "Flash Override [CS4]",
   [0x22] = "Flash Override [AF41]",
   [0x24] = "Flash Override [AF42]",
   [0x26] = "Flash Override [AF43]",
   [0x28] = "Critical [CS5]",
   [0x2E] = "Critical [EF]",
   [0x30] = "Internetwork Control [CS6]",
   [0x38] = "Network Control [CS7]"
}

local DSCP_class = {
   [0x00] = "cs0",
   [0x08] = "cs1", [0x0A] = "cs1", [0x0C] = "cs1", [0x0E] = "cs1",
   [0x10] = "cs2", [0x12] = "cs2", [0x14] = "cs2", [0x16] = "cs2",
   [0x18] = "cs3", [0x1A] = "cs3", [0x1C] = "cs3", [0x1E] = "cs3",
   [0x20] = "cs4", [0x22] = "cs4", [0x24] = "cs4", [0x26] = "cs4",
   [0x28] = "cs5", [0x2E] = "cs5",
   [0x30] = "cs6",
   [0x38] = "cs7",
   [0x01] = "LE",
}

local ECN = {
   [0x00] = "Disabled (0)",
   [0x01] = "Enabled (1)",
   [0x02] = "Default (2)",
   [0x03] = "CE"
}

local DS_class = {
   ['cs0'] = "Best Effort",          -- DS 0
   ['cs1'] = "Priority",             -- DS 8,10,12,14
   ['cs2'] = "Immediate",            -- DS 16,18,20,22
   ['cs3'] = "Flash",                -- DS 24,26,28,30
   ['cs4'] = "Flash Override",       -- DS 32,34,36,38
   ['cs5'] = "Critical",             -- DS 40,46
   ['cs6'] = "Internetwork Control", -- DS 48
   ['cs7'] = "Network Control",      -- DS 56
   ['le'] = "LE",                    -- LE
   ['unknown'] = "Unknown"
}

function dscp_consts.dscp_descr(id)
   local descr = DSCP[tonumber(id)]
   if descr == nil then
     descr = "Unknown ["..id.."]"
   end
   return descr
end

function dscp_consts.ecn_descr(id)
   local descr = ECN[id]
   if descr == nil then
     descr = "Unknown ("..id..")"
   end
   return descr
end

function dscp_consts.ds_class_descr(id)
   local descr = DS_class[id]
   if descr == nil then
     descr = "Unknown"
   end
   if id:find("^cs") then
     descr = descr.." ("..string.upper(id)..")"
   end
   return descr
end

function dscp_consts.dscp_class_descr(id)
   local class = DSCP_class[tonumber(id)]
   if class == nil then
      class = "unknown"
   end
   return dscp_consts.ds_class_descr(class)
end

function dscp_consts.dscp_class_list()
   local dscp_list = {}

   for k, v in pairs(DSCP) do 
      dscp_list[k] = {}
      dscp_list[k]["id"] = k
      dscp_list[k]["label"] = v
   end

   return dscp_list
end

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

return dscp_consts
