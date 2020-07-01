## Introduction

To simplify the ntopng architecture, a rework of host pools has been necessary. Host pools, which were kept on a per-interface basis, are now global. This means that it is only necessary to define them once to have them applied automatically to all ntopng interfaces. Host pool statistics continue to be stay separated and independent on each interface.

## Migration

Starting from the July 1st 2020 4.1 dev build, to avoid losing current host pools configuration, an automatic migration is performed when certain conditions are met. When the automatic migration is not possible, old host pools configurations are saved to possibly re-import them manually.

### Automatic migration

Automatic migration is performed when host pools there is one and only one active interface with host pools defined. ntopng, upon startup, automatically migrates these pools. In this case, there is no need to intervene with any kind of manual migration.

When the automatic migration is performed, the following message is logged:

```
[startup.lua:37] [host_pools_utils.lua:722] WARNING: Host pools configuration migrated.
```

### Manual migration

When host pools are configured for multiple interfaces, there could be host pool id and historical data clashes. For this reason, ntopng does not perform any kind of automatic migration. In this case, ntopng backs up host pool configuration for each interface and then delete current host pool configuration to prevent dangling data to remain on the system.

When the back up is performed, the following messages such as the following are logged:

```
30/Jun/2020 22:10:42 [startup.lua:37] [host_pools_utils.lua:752] WARNING: [enp5s0] host pools configuration backed up to file /var/lib/ntopng/7/migration/host_pools/pools_configuration.json due to major changes. It is possible to take the file and re-import it manually.
30/Jun/2020 22:10:42 [startup.lua:37] [host_pools_utils.lua:752] WARNING: [lo] host pools configuration backed up to file /var/lib/ntopng/1/migration/host_pools/pools_configuration.json due to major changes. It is possible to take the file and re-import it manually.
```

For each interface, host pools configuration is saved under `/var/lib/ntopng/<interface id>/migration/host_pools/pools_configuration.json`. It's up the the user to take `pools_configuration.json` and possibly re-import it directly inside the ntopng host pools 'Import Configuration'.

## nEdge

In case of nEdge, automatic migration of users and assigned devices is performed automatically.
