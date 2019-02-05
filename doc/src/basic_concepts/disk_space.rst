Disk Space Requirements
#######################

ntopng uses disk space to store:
- Timeseries
- Flows

Timeseries storage can be controlled, to a great extent, using the
Preferences page. For example, one can choose to store only the
traffic timeseries of every host, or can also enable the generation of
Layer-7 application protocol timeseries.

Timeseries are generated for interfaces, local networks, traffic
profiles, and local hosts, just to name a few. As local hosts are
always orders of magnitude greater than other timeseries, the space
used by ntopng is expressed as a function of the number of local hosts
in the system.

Updated space requiremens can be found at the following page:
https://www.ntop.org/ntopng/ntopng-disk-requirements-for-timeseries-and-flows/

The same page can also be used to estimate the space required to store
flows. Note that also the storage of flows is optional and is off by default.
