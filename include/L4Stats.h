#ifndef _L4_STATS_H_
#define _L4_STATS_H_

class L4Stats {
 private:
  TrafficStats tcp_sent, tcp_rcvd;
  TrafficStats udp_sent, udp_rcvd;
  TrafficStats icmp_sent, icmp_rcvd;
  TrafficStats other_ip_sent, other_ip_rcvd;

 public:
  void luaStats(lua_State* vm);
  void luaAnomalies(lua_State* vm);
  void serialize(json_object *obj);
  void deserialize(json_object *obj);
  void incStats(time_t when, u_int8_t l4_proto,
        u_int64_t rcvd_packets, u_int64_t rcvd_bytes,
        u_int64_t sent_packets, u_int64_t sent_bytes);

  inline TrafficStats* getTCPSent()     { return(&tcp_sent);      }
  inline TrafficStats* getTCPRcvd()     { return(&tcp_rcvd);      }
  inline TrafficStats* getUDPSent()     { return(&udp_sent);      }
  inline TrafficStats* getUDPRcvd()     { return(&udp_rcvd);      }
  inline TrafficStats* getICMPSent()    { return(&icmp_sent);     }
  inline TrafficStats* getICMPRcvd(  )  { return(&icmp_rcvd);     }
  inline TrafficStats* getOtherIPSent() { return(&other_ip_sent); }
  inline TrafficStats* getOtherIPRcvd() { return(&other_ip_rcvd); }
};

#endif
