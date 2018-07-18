/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _LOCAL_HOST_H_
#define _LOCAL_HOST_H_

#include "ntop_includes.h"

class LocalHost : public Host {
 private:
  int16_t local_network_id;
  NetworkStats *networkStats;
  DnsStats *dns;
  HTTPstats *http;
  ICMPstats *icmp;
  FrequentStringItems *top_sites;
  char *old_sites;
  char os[16];
  time_t nextSitesUpdate;
  bool systemHost;
  bool dhcpUpdated;
  bool trigger_host_alerts;
  bool drop_all_host_traffic, dump_host_traffic;
  u_int32_t num_alerts_detected;
  u_int32_t attacker_max_num_flows_per_sec, victim_max_num_flows_per_sec;
  u_int32_t attacker_max_num_syn_per_sec, victim_max_num_syn_per_sec;
  AlertCounter *syn_flood_attacker_alert, *syn_flood_victim_alert;
  AlertCounter *flow_flood_attacker_alert, *flow_flood_victim_alert;

  void initialize();
  virtual bool readDHCPCache();
 public:
  LocalHost(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip);
  LocalHost(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  virtual ~LocalHost();

  virtual int16_t get_local_network_id() { return(local_network_id);  };
  virtual bool isLocalHost()             { return(true);              };
  virtual bool isSystemHost()            { return(systemHost);        };

  virtual void  serialize2redis();
  bool deserialize(char *json_str, char *key);

  virtual json_object* getJSONObject();
  virtual NetworkStats* getNetworkStats(int16_t networkId){ return(iface->getNetworkStats(networkId));   };
  virtual u_int32_t getActiveHTTPHosts()             { return(http ? http->get_num_virtual_hosts() : 0); };
  virtual HTTPstats* getHTTPstats()                  { return(http);                  };
  virtual char* get_os()                             { return(os);                    };

  virtual bool dropAllTraffic()  { return(drop_all_host_traffic); };
  virtual bool dumpHostTraffic() { return(dump_host_traffic);     };

  bool hasAnomalies();
  void luaAnomalies(lua_State* vm);
  virtual void loadAlertsCounter();

  virtual void incNumFlows(bool as_client);
  virtual void refreshHostAlertPrefs();
  void incrVisitedWebSite(char *hostname);
  virtual bool triggerAlerts()                            { return(trigger_host_alerts); };
  virtual u_int32_t getNumAlerts(bool from_alertsmanager = false);
  virtual void setNumAlerts(u_int32_t num) { num_alerts_detected = num; };
  virtual void setDumpTrafficPolicy(bool new_policy);
  virtual void setOS(char *_os);
  virtual void updateSynFlags(time_t when, u_int8_t flags, Flow *f, bool syn_sent);
  virtual void updateStats(struct timeval *tv);
  virtual void updateHostTrafficPolicy(char *key);
  virtual void updateHTTPHostRequest(char *virtual_host_name, u_int32_t num_req, u_int32_t bytes_sent, u_int32_t bytes_rcvd);

  virtual void incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer);
  virtual void incNumDNSQueriesSent(u_int16_t query_type) { if(dns) dns->incNumDNSQueriesSent(query_type); };
  virtual void incNumDNSQueriesRcvd(u_int16_t query_type) { if(dns) dns->incNumDNSQueriesRcvd(query_type); };
  virtual void incNumDNSResponsesSent(u_int32_t ret_code) { if(dns) dns->incNumDNSResponsesSent(ret_code); };
  virtual void incNumDNSResponsesRcvd(u_int32_t ret_code) { if(dns) dns->incNumDNSResponsesRcvd(ret_code); };

  virtual void lua(lua_State* vm, AddressTree * ptree, bool host_details,
		   bool verbose, bool returnHost, bool asListElement);
};

#endif /* _LOCAL_HOST_H_ */
