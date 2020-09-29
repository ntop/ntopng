--
-- (C) 2019-20 - ntop.org
--

-- ########################################################

-- Dequeue flows for the execution of periodic scripts

while not ntop.isShutdown() and not ntop.isDeadlineApproaching() do
   interface.dequeueFlowsForHooks(131072 --[[ protocolDetected --]], 16384 --[[ periodicUpdate --]], 131072 --[[ flowEnd --]])
   ntop.msleep(1)
end

-- ########################################################

