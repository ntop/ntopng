Examples v1
===========

Get Interface Data
------------------

*curl*

.. code:: bash
	  
   curl -s -u admin:admin "http://192.168.1.1:3000/lua/rest/v1/get/interface/data.lua?ifid=3"

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
     "ifid": "6",
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
