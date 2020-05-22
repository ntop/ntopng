Examples v0
===========

Get Interface Data
------------------

*curl*

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/rest/get/interface/data.lua?ifid=3"

Response:

.. code:: json

   {  
      "num_flows":8,
      "num_hosts":4,
      "uptime":"55:23",
      "alerts_stored":true,
      "num_live_captures":0,
      "num_local_hosts":3,
      "flows_pctg":1,
      "tcpPacketStats":{  
         "retransmissions":6,
         "out_of_order":0,
         "lost":0
      },
      "ifname":"enp0s8",
      "bytes_download":536953,
      "packets":8105,
      "remote_pps":0,
      "epoch":1547224514,
      "drops":0,
      "remote2local":0,
      "engaged_alerts":0,
      "system_host_stats":{  
         "cpu_idle":1558117,
         "mem_free":1042400,
         "mem_total":2047768,
         "cpu_load":50383,
         "mem_buffers":46912,
         "mem_sreclaimable":30892,
         "mem_cached":320856,
         "mem_used":612964,
         "mem_shmem":6256
      },
      "is_view":false,
      "local2remote":12685,
      "hosts_pctg":1,
      "remote_bps":0,
      "num_devices":3,
      "bytes_upload":2868766,
      "localtime":"17:35:14 +0100",
      "profiles":[  
   
      ],
      "bytes":3405719,
      "speed":100
   }


Get Host Data
-------------

*curl*

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/rest/get/host/data.lua?ifid=3&host=192.168.1.2"

Response:

.. code:: json
	
   {  
      "num_alerts":0,
      "asn":0,
      "is_blacklisted":false,
      "udp_rcvd":{  
         "packets":0,
         "bytes":0
      },
      "seen.first":1547220422,
      "ndpiStats":{  
         "HTTP":{  
            "bytes":{  
               "sent":2617392,
               "rcvd":323353
            },
            "packets":{  
               "sent":3604,
               "rcvd":3231
            },
            "duration":270
         },
         "categories":{  
            "Network":{  
               "id":14,
               "duration":30,
               "bytes_rcvd":0,
               "bytes_sent":2052
            },
            "RemoteAccess":{  
               "id":12,
               "duration":20,
               "bytes_rcvd":14363,
               "bytes_sent":29835
            },
            "Web":{  
               "id":5,
               "duration":270,
               "bytes_rcvd":323353,
               "bytes_sent":2617392
            },
            "Unspecified":{  
               "id":98,
               "duration":180,
               "bytes_rcvd":42606,
               "bytes_sent":179702
            }
         },
         "DHCP":{  
            "bytes":{  
               "sent":2052,
               "rcvd":0
            },
            "packets":{  
               "sent":347,
               "rcvd":0
            },
            "duration":30
         },
         "Unknown":{  
            "bytes":{  
               "sent":187410,
               "rcvd":57694
            },
            "packets":{  
               "sent":179784,
               "rcvd":42770
            },
            "duration":590
         },
         "SSH":{  
            "bytes":{  
               "sent":29835,
               "rcvd":14363
            },
            "packets":{  
               "sent":20278,
               "rcvd":10960
            },
            "duration":20
         }
      },
      "throughput_trend_bps":"Down",
      "udp_sent":{  
         "packets":6,
         "bytes":2052
      },
      "http":{  
         "virtual_hosts":{  
            "192.168.1.2":{  
               "http.act_num_requests":3,
               "bytes.sent":316592,
               "http.requests_trend":3,
               "bytes.rcvd":2613955,
               "http.requests":203
            }
         },
         "receiver":{  
            "rate":{  
               "query":{  
                  "get":0,
                  "head":0,
                  "other":0,
                  "put":0,
                  "post":0
               },
               "response":{  
                  "3xx":0,
                  "2xx":0,
                  "5xx":0,
                  "4xx":0,
                  "1xx":0
               }
            },
            "query":{  
               "total":207,
               "num_other":1,
               "num_get":205,
               "num_put":0,
               "num_head":0,
               "num_post":1
            },
            "response":{  
               "num_1xx":0,
               "total":0,
               "num_4xx":0,
               "num_3xx":0,
               "num_5xx":0,
               "num_2xx":0
            }
         },
         "sender":{  
            "rate":{  
               "query":{  
                  "get":0,
                  "head":0,
                  "other":0,
                  "put":0,
                  "post":0
               },
               "response":{  
                  "3xx":0,
                  "2xx":0,
                  "5xx":0,
                  "4xx":0,
                  "1xx":0
               }
            },
            "query":{  
               "total":0,
               "num_other":0,
               "num_get":0,
               "num_put":0,
               "num_head":0,
               "num_post":0
            },
            "response":{  
               "num_1xx":0,
               "total":205,
               "num_4xx":0,
               "num_3xx":36,
               "num_5xx":0,
               "num_2xx":169
            }
         }
      },
      "rcvd":{  
         "packets":4121,
         "bytes":395410
      },
      "seen.last":1547223705,
      "dns":{  
         "sent":{  
            "stats":{  
            }
         },
         "rcvd":{  
            "stats":{  
            }
         }
      },
      "throughput_bps":0.0,
      "icmp_sent":{  
         "packets":0,
         "bytes":0
      },
      "ifid":3,
      "flows.as_server":267,
      "pktStats.sent":{  
         "synack":212,
         "finack":197,
         "upTo128":1753,
         "upTo64":6,
         "rst":6,
         "upTo1024":133,
         "upTo1518":1632,
         "upTo256":436,
         "upTo512":317
      },
      "throughput_pps":0.0,
      "total_activity_time":865,
      "pktStats.recv":{  
         "syn":212,
         "upTo1518":1,
         "upTo1024":209,
         "finack":213,
         "upTo128":3924,
         "upTo256":4,
         "upTo512":5
      },
      "tcp_sent":{  
         "packets":4250,
         "bytes":2834637
      },
      "ip":{  
         "ipVersion":4,
         "localHost":false,
         "ip":"192.168.1.2"
      },
      "other_ip_sent":{  
         "packets":0,
         "bytes":0
      },
      "icmp_rcvd":{  
         "packets":0,
         "bytes":0
      },
      "throughput_trend_pps":"Down",
      "mac_address":"08:00:27:80:F4:33",
      "localHost":true,
      "tcp_rcvd":{  
         "packets":4121,
         "bytes":395410
      },
      "sent":{  
         "packets":4256,
         "bytes":2836689
      },
      "flows.as_client":7,
      "symbolic_name":"192.168.1.2",
      "other_ip_rcvd":{  
         "packets":0,
         "bytes":0
      },
      "systemHost":true
   }

Get Flows Data
--------------

*curl*

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/pro/rest/get/db/flows.lua?select_clause=*&where_clause=%28IPV4_SRC_ADDR%3D192.168.1.1+OR+IPV4_DST_ADDR%3D192.168.1.1%29&begin_time_clause=1547223290&end_time_clause=1547225090&flow_clause=flows&maxhits_clause=10"

Response:

.. code:: json

   [  
      {  
         "INTERFACE_ID":"3",
         "IP_SRC_PORT":"53607",
         "IPV4_DST_ADDR":"192.168.1.2",
         "NTOPNG_INSTANCE_NAME":"mastrubuntu16",
         "PACKETS":"6",
         "FLOW_TIME":"1547223326",
         "IP_DST_PORT":"22",
         "FIRST_SEEN":"1547223296",
         "INFO":"",
         "PROFILE":"",
         "IP_PROTOCOL_VERSION":"4",
         "LAST_SEEN":"1547223326",
         "IPV6_DST_ADDR":"::",
         "TOTAL_BYTES":"556",
         "IPV6_SRC_ADDR":"::",
         "PROTOCOL":"6",
         "DST2SRC_BYTES":"188",
         "JSON":"",
         "IPV4_SRC_ADDR":"192.168.1.1",
         "SRC2DST_BYTES":"368",
         "L7_PROTO":"0",
         "VLAN_ID":"0"
      },
      {  
         "INTERFACE_ID":"3",
         "IP_SRC_PORT":"54891",
         "IPV4_DST_ADDR":"192.168.1.2",
         "NTOPNG_INSTANCE_NAME":"mastrubuntu16",
         "PACKETS":"17",
         "FLOW_TIME":"1547223365",
         "IP_DST_PORT":"3000",
         "FIRST_SEEN":"1547223365",
         "INFO":"192.168.1.2/lua/get_host_data.lua?host=192.168.1.2&_=1547221203980",
         "PROFILE":"",
         "IP_PROTOCOL_VERSION":"4",
         "LAST_SEEN":"1547223365",
         "IPV6_DST_ADDR":"::",
         "TOTAL_BYTES":"2467",
         "IPV6_SRC_ADDR":"::",
         "PROTOCOL":"6",
         "DST2SRC_BYTES":"1348",
         "JSON":"",
         "IPV4_SRC_ADDR":"192.168.1.1",
         "SRC2DST_BYTES":"1119",
         "L7_PROTO":"7",
         "VLAN_ID":"0"
      }
   ]

Get Past Alerts Data
--------------------

*curl*

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/rest/get/alert/data.lua?ifid=3&status=historical"

Response:

.. code:: json

   [  
      {  
         "entity":"Device",
         "entity_val":"08:00:27:E8:C2:0A",
         "date":"1546894440",
         "severity":"Info",
         "type":"Device Connection",
         "key":"1",
         "msg":"The device <a href='/lua/mac_details.lua?host=08:00:27:E8:C2:0A'>PcsCompu_E8:C2:0A</a> has connected to the network."
      },
      {  
         "entity":"Device",
         "entity_val":"08:00:27:59:89:BF",
         "date":"1547224620",
         "severity":"Info",
         "type":"Device Connection",
         "key":"262",
         "msg":"The device <a href='/lua/mac_details.lua?host=08:00:27:59:89:BF'>PcsCompu_59:89:BF</a> has connected to the network."
      }
   ]

Get Interface Timeseries
------------------------

*curl*

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/rest/get/timeseries/ts.lua?ts_schema=iface:traffic&ts_query=ifid:1&limit=5&extended=1"

Response:

.. code:: json

   {
      "statistics":{
         "min_val":7039.9555539021,
         "95th_percentile":12547.936666667,
         "min_val_idx":3,
         "average":13917.490277778,
         "max_val":13149.49160108,
         "max_val_idx":1,
         "total":50102965
      },
      "max_points":5,
      "step":720,
      "query":{
         "ifid":"1"
      },
      "schema":"iface:traffic",
      "series":[
         {
            "label":"bytes",
            "tags":{
               "ifid":"1"
            },
            "data":{
               "1551800935":7039.9555539021,
               "1551800215":12547.936666667,
               "1551799495":13149.49160108,
               "1551798775":9617.0195100309
            }
         }
      ],
      "count":4,
      "start":1551798775
   }

Check out the `timeseries page`_ for more details.

.. _`timeseries page`: ../timeseries/intro.html#exporting-data
