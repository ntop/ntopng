--
-- (C) 2019-20 - ntop.org
--

-- Perform purging operations (i.e., delete) on all idle hash table entries

-- ########################################################

for _, ifname in pairs(interface.getIfNames()) do
   interface.purgeQueuedIdleEntries()
end

-- ########################################################

