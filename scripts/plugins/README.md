Plugins
-------

This is the root plugins folder. Plugins can be placed directly into this folder or inside sub-folders. Sub-folders can have any name, however, to keep plugins logically organized, the following sub-folders have been defined:

- `alerts`. Contains plugins whose main function is to generate alerts. As alerts can be broadly divided into categories, additional sub-folders have been defined for alerts:

  - `security`: Security behaviors and anomalies (e.g, contacts from or to a blacklisted host, TCP and UDP scans)
  - `system`: Functionalities of the system on top of which ntopng is running (e.g, disk space full, load too high)
  - `network`: Network behaviors and anomalies (e.g., traffic above a certain threshold, TCP not working as expected) 
  - `internals`: Internal functionalitis of ntopng (e.g., memory management and host and flows lifecycles) 
  
- `endpoints`. Contains plugins implementing alert endpoints, that is, plugins in charge of delivering alerts to external endpoints (e.g., to Discord, Slack and Telegram).
  
- `collectors`. Contains plugins for the collection of external data. These are basically input-plugins which receive external data and combine it with ntopng network data. Examples are the Suricata and the Fortinet collectors.

- `monitors`. Contains plugins for the monitoring the system and the network. For this reason, two additional sub-folders have been defined for monitors:

  - `system`: For monitors of the system on top of which ntopng is running (e.g., a Redis monitor, and a Disk space monitor)
  - `network`: For monitors of the network (e.g., an active monitor which implements icmp/http/https pings).
  
 - `examples`. Contains example plugins. 
