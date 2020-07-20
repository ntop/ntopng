--
-- (C) 2020 - ntop.org
--
-- This file contains the alert constats

local dscp_consts = {}

-- ################################################################################

local DSCP = {
   [0x00] = "Best Effort (CS0)",
   [0x01] = "LE",
   [0x08] = "Priority (CS1)",
   [0x0A] = "Priority (AF11)",
   [0x0C] = "Priority (AF12)",
   [0x0E] = "Priority (AF13)",
   [0x10] = "Immediate (CS2)",
   [0x12] = "Immediate (AF21)",
   [0x14] = "Immediate (AF22)",
   [0x16] = "Immediate (AF23)",
   [0x18] = "Flash/Voice (CS3)",
   [0x1A] = "Flash/Voice (AF31)",
   [0x1C] = "Flash/Voice (AF32)",
   [0x1E] = "Flash/Voice (AF33)",
   [0x20] = "Flash Override (CS4)",
   [0x22] = "Flash Override (AF41)",
   [0x24] = "Flash Override (AF42)",
   [0x26] = "Flash Override (AF43)",
   [0x28] = "Critical (CS5)",
   [0x2E] = "Critical(EF)",
   [0x30] = "Internetwork Control (CS6)",
   [0x38] = " Network Control (CS7)"
}

local ECN = {
   [0x00] = "Disabled (0)",
   [0x01] = "Enabled (1)",
   [0x02] = "Default (2)",
   [0x03] = "CE"
}

local DS_precedence = {
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
   local descr = DSCP[id]
   if descr == nil then
     descr = "Unknown ("..id..")"
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

function dscp_consts.ds_precedence_descr(id)
   local descr = DS_precedence[id]
   if descr == nil then
     descr = "Unknown ("..id..")"
   end
   return descr
end

return dscp_consts
