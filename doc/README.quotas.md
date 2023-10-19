Traffic Quotas
==============

Technical Notes
---------------

Stats Update
~~~~~~~~~~~~

ntopng keeps traffic quotas (total and per nDPI protocol) for each Host and Host Pool.
Both Host and Host Pools use the HostPoolStats class to store traffic information about quotas.

Quotas statistics for Hosts are updates in the HostStats class through the incQuotaEnforcementStats()
method which updates the stats object.

Quotas statistics for Host Pools are updated in the HostPools class through the incPoolStats()
method which updates the quota_enforcement_stats object.

Both Host and Host Pools statistics are incremented from the Flow class which is calling
HostPools::incPoolStats() and Host::incQuotaEnforcementStats() in Flow::update_pools_stats()
called by Flow::hosts_periodic_stats_update() which is called by Flow::periodic_stats_update()

Stats Retrieval
~~~~~~~~~~~~~~~

The GUI can access Hosts and Host Pools quotas statistics through two Lua APIs implemented
in C++:

 - interface.getHostUsedQuotasStats()
 - interface.getHostPoolsStats()

See pro/scripts/lua/pool_details_ndpi.lua used by pool_details.lua for an example.
