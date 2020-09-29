--
-- (C) 2019-20 - ntop.org
--

-- Perform continuous purging operations (i.e., delete) on all idle hash table entries

-- ########################################################

while not ntop.isShutdown() and not ntop.isDeadlineApproaching() do
   interface.purgeQueuedIdleEntries(ntop.getDeadline())
   ntop.msleep(1)
end

-- ########################################################

