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

Flows
-----

Get Flows Data
~~~~~~~~~~~~~~

*curl*

.. code:: bash

   curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "select_clause": "*", "where_clause": "IPV4_SRC_ADDR = 192.168.56.1", "begin_time_clause": 1590480290, "end_time_clause": 1590480590, "flow_clause": "flows", "maxhits_clause": 10}' http://localhost:3000/lua/pro/rest/v1/get/db/flows.lua

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
            "INFO":"",
            "JSON":"{ \"8\": \"192.168.56.1\", \"12\": \"192.168.56.103\", \"7\": 61900, \"11\": 22, \"4\": 6, \"57590\": 92, \"57591\": \"SSH\", \"6\": 24, \"2\": 12, \"1\": 908, \"24\": 10, \"23\": 2968, \"22\": 1590480420, \"21\": 1590480421, \"57595\": 0.000000, \"57596\": 0.000000, \"SRC_IP_COUNTRY\": \"\", \"SRC_IP_LOCATION\": [ 0.000000, 0.000000 ], \"DST_IP_COUNTRY\": \"\", \"DST_IP_LOCATION\": [ 0.000000, 0.000000 ], \"NTOPNG_INSTANCE_NAME\": \"mastrubuntu16\", \"INTERFACE\": \"enp0s8\" }"
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
       "data": {
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
       }
     },
     "rc": 0,
     "rc_str": "OK"
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
     "rsp": {
       "Media": {
         "cat_id": 1
       },
       "Shopping": {
         "cat_id": 27
       },
       "Database": {
         "cat_id": 11
       },
       "Web": {
         "cat_id": 5
       },
       "Media": {
         "cat_id": 1
       },
       "SoftwareUpdate": {
         "cat_id": 19
       },
       "Cloud": {
         "cat_id": 13
       },
       "Productivity": {
         "cat_id": 28
       },
       "VPN": {
         "cat_id": 2
       },
       "RemoteAccess": {
         "cat_id": 12
       },
       "Unspecified": {
         "cat_id": 0
       },
       "System": {
         "cat_id": 18
       }
     },
     "rc_str": "OK",
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
     "rsp": {
       "Other IP": {
         "proto_id": -1
       },
       "ICMPv6": {
         "proto_id": 58
       },
       "HIP": {
         "proto_id": 139
       },
       "VRRP": {
         "proto_id": 112
       },
       "GRE": {
         "proto_id": 47
       },
       "RSVP": {
         "proto_id": 46
       },
       "ICMP": {
         "proto_id": 1
       },
       "TCP": {
         "proto_id": 6
       },
       "IPv6-ICMP": {
         "proto_id": 58
       },
       "UDP": {
         "proto_id": 17
       },
       "ESP": {
         "proto_id": 50
       },
       "PIM": {
         "proto_id": 103
       },
       "IP": {
         "proto_id": 0
       },
       "IGMP": {
         "proto_id": 2
       },
       "OSPF": {
         "proto_id": 89
       },
       "IPv6": {
         "proto_id": 41
       }
     },
     "rc_str": "OK"
   }


