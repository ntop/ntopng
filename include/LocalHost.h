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

class LocalHost : public Host, public SerializableElement {
 protected:
  int16_t local_network_id;
  bool systemHost;
  time_t initialization_time;
  HostTimeseriesPoint *initial_ts_point;
  std::map<u_int16_t,PortContactStats> udp_client_ports, tcp_client_ports, udp_server_ports, tcp_server_ports;
  
  /* LocalHost data: update LocalHost::deleteHostData when adding new fields */
  OperatingSystem os;
  char *os_detail;
  bool drop_all_host_traffic; 
  /* END Host data: */

  void initialize();
  void freeLocalHostData();
  virtual void deleteHostData();

  char* getMacBasedSerializationKey(char *redis_key, size_t size, char *mac_key);
  char* getIpBasedSerializationKey(char *redis_key, size_t size);
  void  ports2Lua(lua_State* vm, bool proto_udp, bool as_client);
  void  updateFlowPort(std::map<u_int16_t,PortContactStats> *c, Host *peer,
		       u_int16_t port, u_int16_t l7_proto,
		       const char *info, time_t when);

 public:
  LocalHost(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip);
  LocalHost(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  virtual ~LocalHost();

  virtual void set_hash_entry_state_idle();
  virtual int16_t get_local_network_id() const { return(local_network_id);  };
  virtual bool isLocalHost()  const            { return(true);              };
  virtual bool isSystemHost() const            { return(systemHost);        };

  virtual NetworkStats* getNetworkStats(int16_t networkId) {
    return(iface->getNetworkStats(networkId));
  };
  virtual u_int32_t getActiveHTTPHosts()             { return(getHTTPstats() ? getHTTPstats()->get_num_virtual_hosts() : 0); };
  virtual HostStats* allocateStats()                 { return(new LocalHostStats(this));               };

  virtual bool dropAllTraffic() const { return(drop_all_host_traffic); };
  virtual void inlineSetOSDetail(const char *_os_detail);
  virtual const char* getOSDetail(char * const buf, ssize_t buf_len);
  virtual void updateHostTrafficPolicy(char *key);

  virtual void incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) { stats->incICMP(icmp_type, icmp_code, sent, peer); };
  virtual void incNumDNSQueriesSent(u_int16_t query_type) { stats->incNumDNSQueriesSent(query_type); };
  virtual void incNumDNSQueriesRcvd(u_int16_t query_type) { stats->incNumDNSQueriesRcvd(query_type); };
  virtual void incNumDNSResponsesSent(u_int32_t ret_code) { stats->incNumDNSResponsesSent(ret_code); };
  virtual void incNumDNSResponsesRcvd(u_int32_t ret_code) { stats->incNumDNSResponsesRcvd(ret_code); };
  virtual void luaDNS(lua_State *vm) const                { stats->luaDNS(vm,false); };
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose) const  { stats->luaICMP(vm,isV4,verbose); };
  virtual void incrVisitedWebSite(char *hostname)         { stats->incrVisitedWebSite(hostname); };
  virtual HTTPstats* getHTTPstats()                       { return(stats->getHTTPstats());  };
  virtual void luaTCP(lua_State *vm) const                { stats->lua(vm,false,details_normal); };
  virtual u_int16_t getNumActiveContactsAsClient() const  { return stats->getNumActiveContactsAsClient(); };
  virtual u_int16_t getNumActiveContactsAsServer() const  { return stats->getNumActiveContactsAsServer(); };
  virtual void reloadPrefs();

  virtual void deserialize(json_object *obj);
  virtual void serialize(json_object *obj, DetailsLevel details_level) { return Host::serialize(obj, details_level); };
  virtual char* getSerializationKey(char *buf, uint bufsize);

  virtual void lua(lua_State* vm, AddressTree * ptree, bool host_details,
		   bool verbose, bool returnHost, bool asListElement);
  virtual void tsLua(lua_State* vm);
  void luaPortsDump(lua_State* vm);  
  void setFlowPort(bool as_server, Host *peer, u_int8_t proto, u_int16_t port,
		   u_int16_t l7_proto, const char *info, time_t when);
};

#endif /* _LOCAL_HOST_H_ */
