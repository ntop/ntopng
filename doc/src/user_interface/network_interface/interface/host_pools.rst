.. _HostPools:

Host Pools
----------

Host Pools are logical groups of hosts that are described in detail in the “Network Interfaces" section of
this document. This page show the list of defined and currently active Host Pools.

.. figure:: ../../../img/web_gui_hosts_pools_list.png
  :align: center
  :alt: Host Pools List

  The Host Pools List Hosts Page

Each row of the table shows, for each pool, the following information:

- The Pool Name as defined by the user during Host Pool creation
- A Chart icon to access historical pool traffic timeseries. Historical pool traffic charts must be enabled
  from the preferences page and are a feature that is only supported in the Professional version.
- The number of active hosts in the pool
- The number of alerts detected as the sum of host alerts for each host in the pool
- Seen Since, with the amount of time it has lapsed since the first packet sent/received by any of the
  hosts in the pool has been observed
- Breakdown, showing a bar that gives visual insights in the use of both pool traffic directions
- Throughput, with the overall actual throughput of the pool
- Traffic, with the total traffic exchanged by the pool

Pools can be created or managed from the *System* interface, 
*Pools* menu. It is possible to add new pools using the “plus” button in the same page.

.. figure:: ../../../img/web_gui_interfaces_edit_pools.png
  :align: center
  :alt: Edit Pools

  The Pools Page

Once an Host Pool is created, it is possible to add members to it. Host Pool members can be added 
from the *Pools* > *Host Pool Members* page, using the “plus” button.

.. figure:: ../../../img/web_gui_interfaces_edit_host_pool.png
  :align: center
  :alt: Edit Host Pool

  The Host Pool Page

The Host Pools configuration, which includes the definition of host pools along with
the pools members, can be easily exported to JSON and imported into another ntopng instance
from the *Settings* > *Manage Configuration* page. Imported host pools will replace the existing ones.

An “Alias” can be associated to each pool member to ease the its identification. Typically, one would
assign a mnemonic label as member alias (e.g., “John’s iPhone” or “Smart TV”).

A view of host pool statistics is accessible from the actual interface, *Hosts* > *Host Pools* menu. The view shows live pool information (e.g., overall pool throughput)
and provides access to the historical pool traffic timeseries (Professional version) as well as to the 
currently active pool members.

.. _`relevant section`: hosts.html#host-pools
.. _HostPools:
.. _`network interface page`: interfaces.html#host-pools

Traffic Policies
^^^^^^^^^^^^^^^^

Host pools can also be used to enforce traffic policies (e.g, block YouTube traffic for the “John” pool and
limit Facebook traffic at 1 Mbps for the “Guests” pool). This feature is available in nEdge (when ntopng is
used inline as described in the “Advanced Features” section of this document), or when ntopng is used in 
combination with `nProbe in IPS mode <https://www.ntop.org/guides/nprobe/ips_mode.html>`_ (see :ref:`UsingNtopngWithNprobeIPS`).

