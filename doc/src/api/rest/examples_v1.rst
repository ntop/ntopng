Examples v1
===========

This section contains examples of API requests and responses. Please note that the 
JSON response in some case does not contain the full response (e.g. in case of long
lists).

Interfaces
----------

Get Interface Data
~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -s -u admin:admin "http://localhost:3000/lua/rest/v1/get/interface/data.lua?ifid=0"

Response:

.. code:: json

   {
    "rc": 0
    "rc_str": "OK",
    "rsp": {
     "profiles": {
      "SampleProfile": 0
     },
     "ifname": "enp0s8",
     "uptime": "00:42",
     "num_local_hosts": 3,
     "remote_bps": 0,
     "localtime": "17:14:42 +0200",
     "flow_export_rate": 0.0,
     "throughput": {
      "download": {
       "pps": 0.79980963468552002,
       "bps": 86.379440307617003
      },
      "upload": {
       "pps": 0.39990481734276001,
       "bps": 63.184963226317997
      }
     },
     "bytes": 141035,
     "has_alerts": true,
     "num_flows": 4,
     "throughput_bps": 149.56440734863,
     "flow_export_drops": 0,
     "drops": 0,
     "bytes_upload": 103734,
     "alerted_flows": 0,
     "remote2local": 0,
     "is_view": false,
     "packets_download": 361,
     "packets_upload": 251,
     "bytes_download": 37301,
     "system_host_stats": {
      "mem_total": 4046248,
      "dropped_alerts": 0,
      "mem_ntopng_resident": 187756,
      "mem_ntopng_virtual": 1732120,
      "cpu_load": 3.6400001049042001,
      "mem_sreclaimable": 81460,
      "mem_shmem": 30200,
      "mem_used": 590148,
      "alerts_queries": 3,
      "mem_cached": 1052396,
      "written_alerts": 9,
      "mem_free": 2186336,
      "mem_buffers": 166108,
      "cpu_states": {
       "nice": 0.0,
       "softirq": 0.11173184357542,
       "steal": 0.0,
       "idle": 96.201117318436005,
       "system": 2.0111731843574998,
       "guest_nice": 0.0,
       "iowait": 0.11173184357542,
       "guest": 0.0,
       "user": 1.5642458100559,
       "irq": 0.0
      }
     },
     "tcpPacketStats": {
      "retransmissions": 0,
      "lost": 0,
      "out_of_order": 0
     },
     "num_live_captures": 0,
     "local2remote": 0,
     "periodic_stats_update_frequency_secs": 5,
     "throughput_pps": 1.1997145414352,
     "dropped_alerts": 0,
     "ts_alerts": [],
     "epoch": 1590160482,
     "ifid": "0",
     "hosts_pctg": 1,
     "speed": 1000,
     "num_hosts": 3,
     "macs_pctg": 1,
     "flows_pctg": 1,
     "flow_export_count": 0,
     "packets": 612,
     "engaged_alerts": 0,
     "remote_pps": 0,
     "num_devices": 2
    },
   }

Get interface IP addresses
~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/interface/address.lua?ifid=0"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rsp": {
       "addresses": [
         "192.168.1.1/32",
         "fe80::a00:27ff:fe80:f433/128"
       ]
     },
     "rc": 0
   }

Get L7 statistics for an interface
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/interface/l7/stats.lua?ifid=0&ndpistats_mode=count"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rsp": [
       {
         "value": 62,
         "label": "TLS"
       },
       {
         "value": 36,
         "label": "DNS"
       },
       {
         "value": 34,
         "label": "HTTP"
       },
       {
         "value": 20,
         "label": "Google"
       },
       {
         "value": 11,
         "label": "Facebook"
       },
       {
         "value": 15,
         "label": "Other"
       }
     ],
     "rc": 0
   }

Get actively monitored interfaces
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/ntopng/interfaces.lua"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rsp": [
       {
         "ifid": 0,
         "ifname": "test_01.pcap"
       },
       {
         "ifid": 1,
         "ifname": "test_02.pcap"
       }
     ],
     "rc": 0
   }


Hosts
-----

Get active hosts
~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/host/active.lua?ifid=0"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rc": 0,
     "rsp": {
       "data": [
         {
           "is_localhost": false,
           "last_seen": 1589741869,
           "thpt": {
             "bps": 0,
             "pps": 0
           },
           "is_broadcast": false,
           "country": "US",
           "num_alerts": 0,
           "is_multicast": false,
           "num_flows": {
             "total": 1,
             "as_client": 0,
             "as_server": 1
           },
           "key": "8__241__92__250",
           "bytes": {
             "total": 2356772,
             "recvd": 34148,
             "sent": 2322624
           },
           "vlan": 0,
           "is_broadcast_domain": false,
           "name": 0,
           "ip": "8.241.92.250",
           "is_blacklisted": false,
           "os": 0,
           "first_seen": 1589741868
         },
         {
           "is_localhost": false,
           "last_seen": 1589741869,
           "thpt": {
             "bps": 0,
             "pps": 0
           },
           "is_broadcast": false,
           "country": "",
           "num_alerts": 0,
           "is_multicast": false,
           "num_flows": {
             "total": 34,
             "as_client": 0,
             "as_server": 34
           },
           "key": "2__23__155__233",
           "bytes": {
             "total": 41945,
             "recvd": 23013,
             "sent": 18932
           },
           "vlan": 0,
           "is_broadcast_domain": false,
           "name": 0,
           "ip": "2.23.155.233",
           "is_blacklisted": false,
           "os": 0,
           "first_seen": 1589741865
         }
       ],
       "currentPage": 1,
       "perPage": 10,
       "sort": [
         []
       ]
     }
   }  

Get host data
~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/host/data.lua?ifid=0&host=8.241.92.250"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rc": 0,
     "rsp": {
       "icmp.bytes.rcvd.anomaly_index": 0,
       "tcp.bytes.sent.anomaly_index": 0,
       "packets.rcvd": 494,
       "childSafe": false,
       "os": 0,
       "tcpPacketStats.rcvd": {
         "retransmissions": 0,
         "keep_alive": 0,
         "lost": 0,
         "out_of_order": 0
       },
       "throughput_bps": 0,
       "icmp.packets.rcvd": 0,
       "other_ip.bytes.sent.anomaly_index": 0,
       "tcp.packets.seq_problems": false,
       "systemhost": false,
       "active_alerted_flows": 0,
       "udp.bytes.rcvd": 0,
       "flows.as_client": 0,
       "icmp.bytes.rcvd": 0,
       "num_triggered_alerts": {
         "hour": 0,
         "5mins": 0,
         "day": 0,
         "min": 0
       },
       "privatehost": false,
       "packets.rcvd.anomaly_index": 0,
       "udp.bytes.sent.anomaly_index": 0,
       "ip": "8.241.92.250",
       "has_blocking_shaper": false,
       "num_alerts": 0,
       "tcp.packets.sent": 1556,
       "active_http_hosts": 0,
       "asn": 3356,
       "hassh_fingerprint": [],
       "ja3_fingerprint": {
         "5d79edf64e03689ff559a54e9d9487bc": {
           "num_uses": 1,
           "app_name": ""
         }
       },
       "is_blacklisted": false,
       "flows.as_server": 1,
       "asname": "LEVEL3",
       "udp.bytes.sent": 0,
       "seen.last": 1589741869,
       "seen.first": 1589741868,
       "tcp.bytes.rcvd.anomaly_index": 0,
       "throughput_pps": 0,
       "bins": {
         "server": {
           "frequency": {
             "> 300": 0,
             "<= 300": 0,
             "<= 60": 0,
             "<= 3": 0,
             "<= 30": 0,
             "<= 5": 0,
             "<= 1": 0,
             "<= 10": 0
           },
           "duration": {
             "> 300": 0,
             "<= 300": 0,
             "<= 60": 0,
             "<= 3": 0,
             "<= 30": 0,
             "<= 5": 0,
             "<= 1": 0,
             "<= 10": 0
           }
         },
         "client": {
           "frequency": {
             "> 300": 0,
             "<= 300": 0,
             "<= 60": 0,
             "<= 3": 0,
             "<= 30": 0,
             "<= 5": 0,
             "<= 1": 0,
             "<= 10": 0
           },
           "duration": {
             "> 300": 0,
             "<= 300": 0,
             "<= 60": 0,
             "<= 3": 0,
             "<= 30": 0,
             "<= 5": 0,
             "<= 1": 0,
             "<= 10": 0
           }
         }
       },
       "host_unreachable_flows.as_client": 0,
       "total_flows.as_server": 1,
       "bytes.ndpi.unknown": 0,
       "vlan": 0,
       "other_ip.bytes.sent": 0,
       "tskey": "8.241.92.250",
       "broadcast_domain_host": false,
       "mac": "10:13:31:F1:39:76",
       "city": "",
       "icmp.bytes.sent.anomaly_index": 0,
       "packets.sent.anomaly_index": 0,
       "latitude": 37.750999450684,
       "udp.packets.sent": 0,
       "pktStats.recv": {
         "size": {
           "upTo128": 487,
           "upTo256": 5,
           "above9000": 0,
           "upTo2500": 0,
           "upTo64": 0,
           "upTo9000": 0,
           "upTo512": 2,
           "upTo1024": 0,
           "upTo6500": 0,
           "upTo1518": 0
         },
         "tcp_flags": {
           "finack": 0,
           "syn": 1,
           "rst": 0,
           "synack": 0
         }
       },
       "drop_all_host_traffic": false,
       "localhost": false,
       "bytes.sent.anomaly_index": 0,
       "misbehaving_flows.as_server": 0,
       "continent": "NA",
       "names": [],
       "num_flow_alerts": 0,
       "os_detail": "",
       "host_pool_id": 0,
       "ifid": 0,
       "icmp.bytes.sent": 0,
       "other_ip.packets.rcvd": 0,
       "throughput_trend_pps": 0,
       "name": "",
       "contacts.as_server": 0,
       "tcpPacketStats.sent": {
         "retransmissions": 0,
         "keep_alive": 0,
         "lost": 0,
         "out_of_order": 0
       },
       "contacts.as_client": 0,
       "is_broadcast": false,
       "total_activity_time": 5,
       "misbehaving_flows_status_map.as_server": 0,
       "active_flows.as_server": 1,
       "active_flows.as_client": 0,
       "udpBytesSent.non_unicast": 0,
       "udpBytesSent.unicast": 0,
       "score": 0,
       "longitude": -97.821998596191,
       "bytes.sent": 2322624,
       "hiddenFromTop": false,
       "other_ip.packets.sent": 0,
       "icmp.packets.sent": 0,
       "udp.packets.rcvd": 0,
       "misbehaving_flows_status_map.as_client": 0,
       "tcp.bytes.sent": 2322624,
       "total_alerts": 0,
       "other_ip.bytes.rcvd.anomaly_index": 0,
       "ndpi_categories": {
         "Web": {
           "bytes.sent": 2322624,
           "bytes": 2356772,
           "bytes.rcvd": 34148,
           "category": 5,
           "duration": 5
         }
       },
       "tcp.packets.rcvd": 494,
       "packets.sent": 1556,
       "host_unreachable_flows.as_server": 0,
       "unreachable_flows.as_server": 0,
       "dhcpHost": false,
       "ndpi": {
         "TLS": {
           "bytes.sent": 2322624,
           "num_flows": 0,
           "packets.sent": 1556,
           "bytes.rcvd": 34148,
           "packets.rcvd": 494,
           "duration": 5,
           "breed": "Safe"
         }
       },
       "unreachable_flows.as_client": 0,
       "misbehaving_flows.as_client": 0,
       "ipkey": 150035706,
       "throughput_trend_bps": 0,
       "bytes.rcvd": 34148,
       "other_ip.bytes.rcvd": 0,
       "total_flows.as_client": 0,
       "udp.bytes.rcvd.anomaly_index": 0,
       "tcp.bytes.rcvd": 34148,
       "has_blocking_quota": false,
       "bytes.rcvd.anomaly_index": 0,
       "pktStats.sent": {
         "size": {
           "upTo128": 8,
           "upTo256": 2,
           "above9000": 0,
           "upTo2500": 0,
           "upTo64": 0,
           "upTo9000": 0,
           "upTo512": 0,
           "upTo1024": 7,
           "upTo6500": 0,
           "upTo1518": 1539
         },
         "tcp_flags": {
           "finack": 0,
           "syn": 0,
           "rst": 0,
           "synack": 1
         }
       },
       "country": "US",
       "is_multicast": false,
       "devtype": 0,
       "duration": 2
     }
   }

Get host custom data
~~~~~~~~~~~~~~~~~~~~

Get custom host data: "ip,bytes.sent=tdb,packets.sent" for host: "10.222.222.119" on
monitoring interface (ifid): 0. Available fields can be found from the output
of "Get host data" above. Each field can have an optional alias name. Use
the "field=alias" syntax to define a field alias. Separate each
field / field alias with a comma.

*curl*

.. code:: bash

   curl --silent --insecure -u "admin:admin" \
     -H "Content-Type: application/json" -d '{"ifid": 0, "host": "10.222.222.119", "field_alias": "ip,bytes.sent=tdb,packets.sent"}' \
     "https://localhost:3001/lua/rest/v1/get/host/custom_data.lua"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rc": 0,
     "rsp": {
       "tdb": 71787960,
       "ip": "10.222.222.119",
       "packets.sent": 243977
     }
   }

Get custom host data: "ip,bytes.sent=tdb,packets.sent=tdp" for all hosts on
monitoring interface (ifid): 0.

*curl*

.. code:: bash

   curl --silent --insecure -u "admin:admin" \
     -H "Content-Type: application/json" -d '{"ifid": 0, "field_alias": "ip,bytes.sent=tdb,packets.sent=tdp"}' \
     "https://localhost:3001/lua/rest/v1/get/host/custom_data.lua"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rc": 0,
     "rsp": [
       {
         "ip": "ff02::1:ff00:1",
         "tdb": 0,
         "tdp": 0
       },
       {
         "ip": "10.222.222.96",
         "tdb": 106980522,
         "tdp": 452276
       },
       {
         "ip": "ff02::1:ffb7:97bf",
         "tdb": 0,
         "tdp": 0
       },
       {
         "ip": "10.222.222.119",
         "tdb": 76788610,
         "tdp": 264447
       }
     ]
   }

Get all host data for all hosts on monitoring interface (ifid): 0.

*curl*

.. code:: bash

   curl --silent --insecure -u "admin:admin" \
     -H "Content-Type: application/json" -d '{"ifid": 0"}' \
     "https://localhost:3001/lua/rest/v1/get/host/custom_data.lua"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rc": 0,
     "rsp": [
       {
         All host data for "ip": "ff02::1:ff00:1"
       },
       {
         All host data for "ip": "10.222.222.96"
       },
       {
         All host data for "ip": "ff02::1:ffb7:97bf"
       },
       {
         "All host data for "ip": "10.222.222.119",
       }
     ]
   }

Get L7 statistics for a host
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/host/l7/stats.lua?ifid=0&host=8.241.92.250"

Response:

.. code:: json

   {
     "rsp": [
       {
         "duration": 5,
         "value": 2356772,
         "label": "TLS"
       }
     ],
     "rc_str": "OK",
     "rc": 0
   }
   
Get host interfaces
~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/host/interfaces.lua?host=8.241.92.250"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rsp": {
       "8.241.92.250": [
         {
           "ifid": 1
         },
         {
           "ifid": 0
         }
       ]
     },
     "rc": 0
   }

Flows
-----

Get flow counters for L4 protocols
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/flow/l4/counters.lua?ifid=0"

Response:

.. code:: json

   {
     "rc": 0,
     "rc_str": "OK",
     "rsp": [
       {
         "id": 6,
         "count": 132
       },
       {
         "id": 17,
         "count": 46
       }
     ]
   }

Get flow counters for L7 protocols
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/flow/l7/counters.lua?ifid=0"

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rsp": [
       {
         "count": 1,
         "name": "Cloudflare"
       },
       {
         "count": 45,
         "name": "DNS"
       },
       {
         "count": 11,
         "name": "Facebook"
       },
       {
         "count": 20,
         "name": "Google"
       },
       {
         "count": 96,
         "name": "TLS"
       },
       {
         "count": 82,
         "name": "Unknown"
       }
     ],
     "rc": 0
   }

Get active flows
~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/flow/active.lua?ifid=0" 

Response:

.. code:: json

   {
     "rc": 0,
     "rsp": {
       "data": [
         {
           "thpt": {
             "pps": 0,
             "bps": 0
           },
           "hash_id": "163",
           "client": {
             "name": "192.168.1.93",
             "port": 61683,
             "is_blacklisted": false,
             "is_dhcp": false,
             "ip": "192.168.1.93",
             "is_broadcast_domain": false
           },
           "first_seen": 1589741868,
           "score": "0",
           "vlan": 0,
           "server": {
             "name": "8.241.92.250",
             "port": 443,
             "is_blacklisted": false,
             "is_dhcp": false,
             "ip": "8.241.92.250",
             "is_broadcast": false
           },
           "last_seen": 1589741869,
           "bytes": 2356772,
           "key": "3382381902",
           "protocol": {
             "l4": "TCP",
             "l7": "TLS"
           },
           "duration": 1,
           "breakdown": {
             "srv2cli": 99,
             "cli2srv": 1
           }
         },
         {
           "thpt": {
             "pps": 0,
             "bps": 0
           },
           "hash_id": "23",
           "client": {
             "name": "192.168.1.93",
             "port": 61567,
             "is_blacklisted": false,
             "is_dhcp": false,
             "ip": "192.168.1.93",
             "is_broadcast_domain": false
           },
           "first_seen": 1589741865,
           "score": "0",
           "vlan": 0,
           "server": {
             "name": "31.13.86.4",
             "port": 443,
             "is_blacklisted": false,
             "is_dhcp": false,
             "ip": "31.13.86.4",
             "is_broadcast": false
           },
           "last_seen": 1589741865,
           "bytes": 188958,
           "key": "3753284184",
           "protocol": {
             "l4": "TCP",
             "l7": "TLS.Facebook"
           },
           "duration": 0,
           "breakdown": {
             "srv2cli": 96,
             "cli2srv": 4
           }
         }
       ],
       "currentPage": 1,
       "perPage": 10,
       "totalRows": 178,
       "sort": [
         [
           "column_",
           "desc"
         ]
       ]
     },
     "rc_str": "OK"
   }

Get historical flows
~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "select_clause": "*", "where_clause": "IPV4_SRC_ADDR = 192.168.56.1", "begin_time_clause": 1590480290, "end_time_clause": 1590480590, "maxhits_clause": 10}' http://localhost:3000/lua/pro/rest/v1/get/db/flows.lua

Response:

.. code:: json

   {
      "rc":0,
      "rc_str":"OK",
      "rsp":[
         {
            "FLOW_TIME":"1590480421",
            "FIRST_SEEN":"1590480420",
            "LAST_SEEN":"1590480421",
            "VLAN_ID":"0",
            "IP_PROTOCOL_VERSION":"4",
            "IPV4_SRC_ADDR":"192.168.56.1",
            "IPV4_DST_ADDR":"192.168.56.103",
            "IPV6_SRC_ADDR":"::",
            "IPV6_DST_ADDR":"::",
            "PROTOCOL":"6",
            "IP_SRC_PORT":"61900",
            "IP_DST_PORT":"22",
            "L7_PROTO":"92",
            "SRC2DST_BYTES":"908",
            "DST2SRC_BYTES":"2968",
            "PACKETS":"22",
            "TOTAL_BYTES":"3876",
            "SRC_COUNTRY_CODE":"0",
            "DST_COUNTRY_CODE":"0",
            "SRC_LABEL":"",
            "DST_LABEL":"",
            "NTOPNG_INSTANCE_NAME":"ubuntuvm",
            "INTERFACE_ID":"6",
            "PROFILE":"",
            "STATUS":"0",
            "INFO":""
         }
      ]
   }

Alerts
------

Get alerts timeseries
~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0", "status": "historical-flows", "epoch_begin": 1590710400, "epoch_end": 1590796800}' http://localhost:3000/lua/rest/v1/get/alert/ts.lua

Response:

.. code:: json

   {
     "rsp": {
         "1590710400": [
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           37,
           3,
           4,
           6,
           13,
           9,
           0,
           15,
           0,
           3,
           0,
           0,
           0,
           0,
           0,
           0,
           0
         ],
         "1590796800": [
           0,
           0,
           1,
           0,
           0,
           2,
           0,
           0,
           0,
           1,
           0,
           0,
           0,
           16,
           0,
           0,
           3,
           34,
           48,
           13,
           0,
           0,
           2,
           0
         ]
     },
     "rc": 0,
     "rc_str": "OK"
   }

Get alerts data
~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0", "status": "historical-flows"}' http://localhost:3000/lua/rest/v1/get/alert/data.lua

Response:

.. code:: json

   {
     "rsp": [
       {
         "entity": "flow",
         "type": "alert_potentially_dangerous_protocol",
         "score": 100,
         "date": "1590742735",
         "severity": "error",
         "count": 1,
         "entity_val": "",
         "msg": "TLS Certificate Expired [24/08/2019 18:04:13 - 22/11/2019 18:04:13] [Flow: <A HREF='/lua/flow_details.lua?flow_key=2169606404&flow_hash_id=131'><span class='badge badge-info'>Info</span></A> <a href='/lua/host_details.lua?host=192.168.1.93' data-toggle='tooltip' title=''>192.168.1.93</a>:<A HREF=\"/lua/port_details.lua?port=61650\">61650</A> [ <A HREF=\"/lua/hosts_stats.lua?mac=28:37:37:00:6D:C8\">28:37:37:00:6D:C8</A> ] <i class=\"fas fa-exchange-alt fa-lg\"  aria-hidden=\"true\"></i> <a href='/lua/host_details.lua?host=192.168.1.176' data-toggle='tooltip' title=''>192.168.1.176</a>:<A HREF=\"/lua/port_details.lua?port=443\">443</A> [ <A HREF=\"/lua/hosts_stats.lua?mac=00:80:8F:9A:AE:BD\">00:80:8F:9A:AE:BD</A> ]] <a href=\"/lua/admin/edit_configset.lua?confset_id=0&subdir=flow&check=tls_certificate_expired#all\"><i class=\"fas fa-cog\" title=\"Edit Configuration\"></i></a>"
       },
       {
         "entity": "flow",
         "type": "alert_potentially_dangerous_protocol",
         "score": 50,
         "date": "1590742735",
         "severity": "error",
         "count": 1,
         "entity_val": "",
         "msg": "TLS Certificate Mismatch [Client Requested: cdn.gigya.com] [Server Names: a248.e.akamai.net,*.akamaized-staging.net,*.akamaized.net,*.akamaihd-staging.net,*.akamaihd.net] [Flow: <A HREF='/lua/flow_details.lua?flow_key=2027748492&flow_hash_id=118'><span class='badge badge-info'>Info</span></A> <a href='/lua/host_details.lua?host=192.168.1.93' data-toggle='tooltip' title=''>192.168.1.93</a>:<A HREF=\"/lua/port_details.lua?port=61632\">61632</A> [ <A HREF=\"/lua/hosts_stats.lua?mac=28:37:37:00:6D:C8\">28:37:37:00:6D:C8</A> ] <i class=\"fas fa-exchange-alt fa-lg\"  aria-hidden=\"true\"></i> <a href='/lua/host_details.lua?host=184.51.127.56' data-toggle='tooltip' title=''>184.51.127.56</a>:<A HREF=\"/lua/port_details.lua?port=443\">443</A> [ <A HREF=\"/lua/hosts_stats.lua?mac=10:13:31:F1:39:76\">10:13:31:F1:39:76</A> ]] <a href=\"/lua/admin/edit_configset.lua?confset_id=0&subdir=flow&check=tls_certificate_mismatch#all\"><i class=\"fas fa-cog\" title=\"Edit Configuration\"></i></a>"
       }
     ],
     "rc": 0,
     "rc_str": "OK"
   }

Get alert severity constants
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin http://localhost:3000/lua/rest/v1/get/alert/severity/consts.lua

Response:

.. code:: json

   {
     "rsp": [
       {
         "severity": "info",
         "id": 0
       },
       {
         "severity": "error",
         "id": 2
       },
       {
         "severity": "warning",
         "id": 1
       }
     ],
     "rc": 0,
     "rc_str": "OK"
   }

Get alert type constants
~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin http://localhost:3000/lua/rest/v1/get/alert/type/consts.lua

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rc": 0,
     "rsp": [
       {
         "key": 9,
         "type": "alert_flow_blocked"
       },
       {
         "key": 40,
         "type": "alert_request_reply_ratio"
       },
       {
         "key": 18,
         "type": "alert_internals"
       },
       {
         "key": 38,
         "type": "alert_quota_exceeded"
       },
       {
         "key": 21,
         "type": "alert_login_failed"
       },
       {
         "key": 53,
         "type": "alert_user_activity"
       },
       {
         "key": 47,
         "type": "alert_tcp_syn_scan"
       }
     ]
   }

Get counters per severity
~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/alert/severity/counters.lua?ifid=0"

Response:

.. code:: json

   {
     "rc": 0,
     "rc_str": "OK",
     "rsp": {
       "historical-flows": [
         {
           "count": "37",
           "severity": "error"
         }
       ],
       "historical": []
     }
   }

Get counters per type
~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/alert/type/counters.lua?ifid=0"

Response:

.. code:: json

   {
     "rsp": {
       "historical-flows": [
         {
           "count": "37",
           "type": "alert_potentially_dangerous_protocol"
         }
       ],
       "historical": []
     },
     "rc": 0,
     "rc_str": "OK"
   }

L7 Application Protocols
------------------------

Get L7 application protocol constants
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin http://localhost:3000/lua/rest/v1/get/l7/application/consts.lua

Response:

.. code:: json

  {
     "rc_str": "OK",
     "rsp": [
       {
         "name": "PS_VUE",
         "cat_id": 26,
         "appl_id": 64
       },
       {
         "name": "Lando",
         "cat_id": 0,
         "appl_id": 254
       },
       {
         "name": "MapleStory",
         "cat_id": 8,
         "appl_id": 113
       },
       {
         "name": "Spotify",
         "cat_id": 25,
         "appl_id": 156
       },
       {
         "name": "DNS",
         "cat_id": 14,
         "appl_id": 5
       },
       {
         "name": "SMTP",
         "cat_id": 3,
         "appl_id": 3
       }
     ],
     "rc": 0
   } 

L7 Application Categories
-------------------------

Get L7 application category constants
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin http://localhost:3000/lua/rest/v1/get/l7/category/consts.lua

Response:

.. code:: json

   {
     "rc_str": "OK",
     "rsp": [
       {
         "name": "Web",
         "cat_id": 5
       },
       {
         "name": "Database",
         "cat_id": 11
       },
       {
         "name": "Malware",
         "cat_id": 100
       },
       {
         "name": "User custom category 3",
         "cat_id": 22
       },
       {
         "name": "DataTransfer",
         "cat_id": 4
       },
       {
         "name": "SocialNetwork",
         "cat_id": 6
       },
       {
         "name": "Cloud",
         "cat_id": 13
       }
     ],
     "rc": 0
   }

L4 Protocols
------------

Get L4 protocol constants
~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin http://localhost:3000/lua/rest/v1/get/l4/protocol/consts.lua

Response:

.. code:: json

   {
     "rc": 0,
     "rsp": [
       {
         "name": "IP",
         "id": 0
       },
       {
         "name": "ICMP",
         "id": 1
       },
       {
         "name": "IGMP",
         "id": 2
       },
       {
         "name": "TCP",
         "id": 6
       },
       {
         "name": "UDP",
         "id": 17
       },
       {
         "name": "IPv6",
         "id": 41
       },
       {
         "name": "RSVP",
         "id": 46
       },
       {
         "name": "GRE",
         "id": 47
       },
       {
         "name": "ESP",
         "id": 50
       },
       {
         "name": "IPv6-ICMP",
         "id": 58
       },
       {
         "name": "OSPF",
         "id": 89
       },
       {
         "name": "PIM",
         "id": 103
       },
       {
         "name": "VRRP",
         "id": 112
       },
       {
         "name": "HIP",
         "id": 139
       },
       {
         "name": "ICMPv6",
         "id": 58
       },
       {
         "name": "IGMP",
         "id": 2
       },
       {
         "name": "Other IP",
         "id": -1
       }
     ],
     "rc_str": "OK"
   }

Pools
-----

Add an Host Pool
~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool_name": "themaina", "pool_members": "192.168.2.0/24@0", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/add/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool_name": "themainamac", "pool_members": "AA:BB:CC:DD:EE:FF", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/add/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool_name": "themainaip", "pool_members": "8.8.8.8/32@2", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/add/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool_name": "themainaempty", "pool_members": "", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/add/host/pool.lua

Edit an Host Pool
~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 1, "pool_name": "themaina", "pool_members": "192.168.3.0/24@0", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/edit/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 2, "pool_name": "themainamac", "pool_members": "AA:BB:CC:DD:EE:AA", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/edit/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 3, "pool_name": "themainaip", "pool_members": "1.1.1.1/32@2", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/edit/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 4, "pool_name": "themainaempty", "pool_members": "", "confset_id" : 0}' http://localhost:3000/lua/rest/v1/edit/host/pool.lua

Delete an Host Pool
~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 1}' http://localhost:3000/lua/rest/v1/delete/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 2}' http://localhost:3000/lua/rest/v1/delete/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 3}' http://localhost:3000/lua/rest/v1/delete/host/pool.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 4}' http://localhost:3000/lua/rest/v1/delete/host/pool.lua


Get an Host Pool
~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 1}' http://localhost:3000/lua/rest/v1/get/host/pools.lua
    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{}' http://localhost:3000/lua/rest/v1/get/host/pools.lua


Get Members of an Host Pool
~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

    curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"pool": 2}' http://localhost:3000/lua/rest/v1/get/host/pool/members.lua

Get All Pools of Any type
~~~~~~~~~~~~~~~~~~~~~~~~~

.. code:: bash

   curl -s -u admin:admin  -H "Content-Type: application/json" curl http://devel:3000/lua/rest/v1/get/pools.lua


SNMP
----

Add an SNMP Device
~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"snmp_host":"ubnt", "snmp_read_community":"public", "snmp_version": "1"}' http://localhost:3000/lua/pro/rest/v1/add/snmp/device.lua

Response:

.. code:: json

   {
	  "rc": 0,
	  "rc_str": "OK",
	  "rsp": {
		  "added_devices": [
			  {"ip": "192.168.2.1", "name": "ubnt"}
		  ]
	  }
   }


*curl*

.. code:: bash

   curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"snmp_host":"192.168.2.169", "snmp_read_community":"public", "snmp_version": "1", "cidr":"32"}' http://localhost:3000/lua/pro/rest/v1/add/snmp/device.lua

Response:

.. code:: json

   {
	  "rc": 0,
	  "rc_str": "OK",
	  "rsp": {
		  "added_devices": [
			  {"ip": "192.168.2.169"}
		  ]
	  }
   }

*curl*

.. code:: bash

   curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"snmp_host":"192.168.2.0", "snmp_read_community":"public", "snmp_version": "1", "cidr":"24"}' http://localhost:3000/lua/pro/rest/v1/add/snmp/device.lua

Response:

.. code:: json

   {
	  "rc": 0,
	  "rc_str": "OK",
	  "rsp": {
		  "added_devices": [
			  {"ip": "192.168.2.169"},
			  {"ip": "192.168.2.1"}
		  ]
	  }
   }

Change the Status of an SNMP Device Interface
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -s -u admin:admin  -H "Content-Type: application/json" -u admin:admin -d '{"host": "192.168.2.169", "snmp_admin_status": "up", "snmp_port_idx": 26}' http://127.0.0.1:3000/lua/pro/rest/v1/change/snmp/device/interface/status.lua

Response:

.. code:: json

   {"rc":0,
   "rc_str_hr":"Success",
   "rsp":[],
   "rc_str":"OK"
   }


*curl*

.. code:: bash

   curl -s -u admin:admin  -H "Content-Type: application/json" -u admin:admin -d '{"host": "192.168.2.169", "snmp_admin_status": "down", "snmp_port_idx": 26}' http://127.0.0.1:3000/lua/pro/rest/v1/change/snmp/device/interface/status.lua

Response:

.. code:: json

   {
     "rc":0,
     "rc_str_hr":"Success",
     "rsp":[],
     "rc_str":"OK"
   }

Misc
----

Create a Session Cookie
~~~~~~~~~~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"username": "admin"}' "http://192.168.1.1:3000/lua/rest/v1/create/ntopng/session.lua"

Response:

.. code:: json

   {
   	"rc":0,
   	"rc_str":"OK",
   	"rc_str_hr":"Success",
   	"rsp":{
   		"session":"3ff5cf2aba7168e9ef955c20291a9ad4"
   	}
   }

Using the session:

.. code:: bash

   curl --cookie "user=admin; session=3ff5cf2aba7168e9ef955c20291a9ad4" "http://192.168.1.1:3000/lua/rest/get/interface/data.lua?ifid=1"

