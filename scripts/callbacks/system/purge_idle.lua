--
-- (C) 2019-20 - ntop.org
--

-- Perform purging operations (i.e., delete) on all idle hash table entries

-- ########################################################

for ifid, ifname in pairs(interface.getIfNames()) do
   interface.select(ifid)
   interface.purgeQueuedIdleEntries()
end

-- ########################################################

