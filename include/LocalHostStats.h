/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _LOCAL_HOST_STATS_H_
#define _LOCAL_HOST_STATS_H_

class LocalHostStats: public HostStats {
 protected:
  /* Written by NetworkInterface::processPacket thread */
  DnsStats *dns;
  HTTPstats *http;
  ICMPstats *icmp;
  FrequentStringItems *top_sites;
  time_t nextSitesUpdate, nextContactsUpdate;
  u_int32_t num_contacts_as_cli, num_contacts_as_srv;
  
  /* Written by NetworkInterface::periodicStatsUpdate thread */
  char *old_sites;
  u_int8_t current_cycle;

  Cardinality num_contacted_hosts_as_client, /* # of hosts contacted by this host   */
    num_host_contacts_as_server,             /* # of hosts that contacted this host */
    num_contacted_services_as_client,        /* DNS, TLS, HTTP....                  */
    num_contacted_ports_as_client,           /* # of different ports this host has contacted          */
    num_host_contacted_ports_as_server,      /* # of different server ports contacted by remote peers */
    contacts_as_cli, contacts_as_srv;        /* Minute reset host contacts          */

  void updateHostContacts();
  void saveOldSites();
  void removeRedisSitesKey();
  void addRedisSitesKey();
  void getCurrentTime(struct tm *t_now);
  void addRemoveRedisKey(char *host_buf, struct tm *t_now, bool push);
  
 public:
  LocalHostStats(Host *_host);
  LocalHostStats(LocalHostStats &s);
  virtual ~LocalHostStats();

  inline ICMPstats* getICMPStats()  const  { return(icmp); }

  virtual void incStats(time_t when, u_int8_t l4_proto,
			u_int ndpi_proto, ndpi_protocol_category_t ndpi_category,
			custom_app_t custom_app,
			u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
			u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
			bool peer_is_unicast);
  virtual void updateStats(const struct timeval *tv);
  virtual void getJSONObject(json_object *my_object, DetailsLevel details_level);
  virtual void deserialize(json_object *obj);
  virtual void lua(lua_State* vm, bool mask_host, DetailsLevel details_level);
  virtual void resetTopSitesData();

  virtual void luaDNS(lua_State *vm, bool verbose)  { if(dns) dns->lua(vm, verbose); }
  virtual void luaHTTP(lua_State *vm)  { if(http) http->lua(vm); }
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose)    { if (icmp) icmp->lua(isV4, vm, verbose); }
  virtual void incrVisitedWebSite(char *hostname);
  virtual void lua_get_timeseries(lua_State* vm);
  virtual bool hasAnomalies(time_t when);
  virtual void luaAnomalies(lua_State* vm, time_t when);
  virtual HTTPstats* getHTTPstats() { return(http); };
  virtual DnsStats*  getDNSstats()  { return(dns);  };
  virtual ICMPstats* getICMPstats() { return(icmp); };
  virtual u_int16_t getNumActiveContactsAsClient() { return(num_contacts_as_cli); }
  virtual u_int16_t getNumActiveContactsAsServer() { return(num_contacts_as_srv); }

  virtual void incCliContactedPorts(u_int16_t port)  { num_contacted_ports_as_client.addElement(port);      }
  virtual void incSrvPortsContacts(u_int16_t port)   { num_host_contacted_ports_as_server.addElement(port); }

  virtual void incCliContactedHosts(IpAddress *peer) {
    peer->incCardinality(&num_contacted_hosts_as_client);
    peer->incCardinality(&contacts_as_cli);
  }
  virtual void incSrvHostContacts(IpAddress *peer)   {
    peer->incCardinality(&num_host_contacts_as_server);
    peer->incCardinality(&contacts_as_srv);
  }

  virtual void incContactedService(char *name)       {
    if(name && (name[0] != '\0'))
      num_contacted_services_as_client.addElement(name, strlen(name));
  }
};

#endif
