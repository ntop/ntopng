/*
 *
 * (C) 2013-19 - ntop.org
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
/*** BEGIN Host data ****/
  /* Written by NetworkInterface::processPacket thread */
  DnsStats *dns;
  HTTPstats *http;
  ICMPstats *icmp;
  FrequentStringItems *top_sites;
  char *os;
  map<Host*, u_int16_t> contacts_as_cli, contacts_as_srv;

  /* Written by NetworkInterface::periodicStatsUpdate thread */
  char *old_sites;
  TimeseriesRing *ts_ring;

  /* Written by multiple threads */
  bool dhcpUpdated;
  bool drop_all_host_traffic;
/*** END Host data ***/

  int16_t local_network_id;
  NetworkStats *networkStats;
  time_t nextSitesUpdate;
  bool systemHost;

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

  virtual json_object* getJSONObject(DetailsLevel details_level);
  virtual NetworkStats* getNetworkStats(int16_t networkId){ return(iface->getNetworkStats(networkId));   };
  virtual u_int32_t getActiveHTTPHosts()             { return(http ? http->get_num_virtual_hosts() : 0); };
  virtual HTTPstats* getHTTPstats()                  { return(http);                  };
  virtual char* get_os()                             { return(os ? os : (char*)"");                    };

  virtual bool dropAllTraffic()  { return(drop_all_host_traffic); };

  virtual void incNumFlows(bool as_client, Host *peer);
  virtual void decNumFlows(bool as_client, Host *peer);
  void incrVisitedWebSite(char *hostname);
  virtual void setOS(char *_os);
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
  virtual void tsLua(lua_State* vm);
  void makeTsPoint(HostTimeseriesPoint *pt);
};

#endif /* _LOCAL_HOST_H_ */
