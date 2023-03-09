/*
 *
 * (C) 2019-23 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _FLOWS_STATS_H_
#define _FLOWS_STATS_H_

#include "ntop_includes.h"

/* *************************************** */

class FlowsStats {
private:
  std::set<std::string> clients, servers;
  u_int32_t num_flows, tot_score;
  u_int64_t tot_sent, tot_rcvd;
  u_int8_t l4_proto;
  const IpAddress* cli_ip;
  Host* cli_host;
  const IpAddress* srv_ip;
  Host* srv_host;

  u_int16_t vlan_id;
  char* proto_name;
  u_int64_t key;

public:
  FlowsStats(const IpAddress *c, const IpAddress *s, u_int8_t _l4_proto,
	     u_int64_t bytes_sent, u_int64_t bytes_rcvd, u_int32_t score) {
    num_flows = 0, tot_sent = tot_rcvd = 0, tot_score = 0, l4_proto = _l4_proto, proto_name = NULL;
    incFlowStats(c, s, bytes_sent, bytes_rcvd, score);
  }

  ~FlowsStats() {
    if(proto_name)
      free(proto_name);
  }
  
  inline u_int32_t getNumClients() { return(clients.size()); }
  inline u_int32_t getNumServers() { return(servers.size()); }
  inline u_int8_t  getL4Protocol() { return(l4_proto);       }
  inline u_int32_t getNumFlows()   { return(num_flows);      }
  inline u_int64_t getTotalSent()  { return(tot_sent);       }
  inline u_int64_t getTotalRcvd()  { return(tot_rcvd);       }
  inline u_int32_t getTotalScore() { return(tot_score);      }
  
  inline void setVlanId(u_int16_t _vlan_id)   { vlan_id = _vlan_id; }
  inline u_int16_t getVlanId()                { return vlan_id; }
  inline void setProtoName(char* _proto_name) {
    if(proto_name) free(proto_name);
    proto_name = strdup(_proto_name);
  }
  inline char* getProtoName()                 { return(proto_name ? proto_name : (char*)""); }
  inline void setKey(u_int64_t _key)          { key = _key; }
  inline u_int64_t getKey()                   { return key; }

  inline void setCli(Host* _cli_host)         { cli_host = _cli_host; }
  inline void setSrv(Host* _srv_host)         { srv_host = _srv_host; }  
  
  inline void setCliIP(const IpAddress* _cli_ip) { cli_ip = _cli_ip;   }
  inline void setSrvIP(const IpAddress* _srv_ip) { srv_ip = _srv_ip;  }


  inline void incFlowStats(const IpAddress *c, const IpAddress *s,
			   u_int64_t bytes_sent, u_int64_t bytes_rcvd,
			   u_int32_t score) {
    char buf_c[48], buf_s[48];

    clients.insert(std::string(((IpAddress*)c)->get_ip_hex(buf_c, sizeof(buf_c)))),
      servers.insert(std::string(((IpAddress*)s)->get_ip_hex(buf_s, sizeof(buf_s)))),
      num_flows++, tot_sent += bytes_sent, tot_rcvd += bytes_rcvd, tot_score += score;;
  }

  char* getCliIP(char* buf, u_int len);
  char* getSrvIP(char* buf, u_int len);
  char* getCliName(char* buf, u_int len);
  char* getSrvName(char* buf, u_int len);
  char* getCliIPHex(char* buf, u_int len);
  char* getSrvIPHex(char* buf, u_int len);
};

#endif /* _FLOWS_STATS_H_ */
