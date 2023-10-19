/*
 *
 * (C) 2013-23 - ntop.org
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

class LocalHostStats : public HostStats {
 protected:
  /* Written by NetworkInterface::processPacket thread */
  DnsStats *dns;
  HTTPstats *http;
  ICMPstats *icmp;
  MostVisitedList *top_sites;

  /* nextPeriodicUpdate done every 5 min */
  time_t nextPeriodicUpdate;
  u_int32_t num_contacts_as_cli, num_contacts_as_srv;

  DESCounter contacted_hosts;

  Cardinality
      num_contacted_hosts_as_client, /* # of hosts contacted by this host   */
      num_host_contacts_as_server,   /* # of hosts that contacted this host */
      num_contacted_services_as_client, /* DNS, TLS, HTTP.... */
      contacts_as_cli, contacts_as_srv, /* Minute reset host contacts */
      num_contacted_countries, /* Estimate the number of contacted countries */
      num_contacted_hosts,     /* Estimate the number of contacted hosts */
      num_contacted_domain_names, /* Estimate of the number of different Domain
                                     Names contacted */
      num_dns_servers, num_smtp_servers, num_ntp_servers, num_imap_servers,
      num_pop_servers; /* Estimate of the number of critical servers used by
                          this host */

  PeerStats *peers;

  void updateHostContacts();
  void removeRedisSitesKey();
  void addRedisSitesKey();
#if defined(NTOPNG_PRO)
  void resetTrafficStats();
#endif

 public:
  LocalHostStats(Host *_host);
  LocalHostStats(LocalHostStats &s);
  virtual ~LocalHostStats();

  inline ICMPstats *getICMPStats() const { return (icmp); }

  virtual void incStats(time_t when, u_int8_t l4_proto, u_int ndpi_proto,
                        ndpi_protocol_category_t ndpi_category,
                        custom_app_t custom_app, u_int64_t sent_packets,
                        u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
                        u_int64_t rcvd_packets, u_int64_t rcvd_bytes,
                        u_int64_t rcvd_goodput_bytes, bool peer_is_unicast);
  virtual void updateStats(const struct timeval *tv);
  virtual void getJSONObject(json_object *my_object,
                             DetailsLevel details_level);
  virtual void lua(lua_State *vm, bool mask_host, DetailsLevel details_level);

  virtual void luaDNS(lua_State *vm, bool verbose) {
    if (dns) dns->lua(vm, verbose);
  }
  virtual void luaHTTP(lua_State *vm) {
    if (http) http->lua(vm);
  }
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose) {
    if (icmp) icmp->lua(isV4, vm, verbose);
  }
  virtual void luaPeers(lua_State *vm);
  virtual void incrVisitedWebSite(char *hostname);
  virtual void lua_get_timeseries(lua_State *vm);
  virtual void luaHostBehaviour(lua_State *vm);
  virtual bool hasAnomalies(time_t when);
  virtual void luaAnomalies(lua_State *vm, time_t when);
  virtual HTTPstats *getHTTPstats() { return (http); };
  virtual DnsStats *getDNSstats() { return (dns); };
  virtual ICMPstats *getICMPstats() { return (icmp); };
  virtual u_int16_t getNumActiveContactsAsClient() {
    return (num_contacts_as_cli);
  }
  virtual u_int16_t getNumActiveContactsAsServer() {
    return (num_contacts_as_srv);
  }

  virtual bool getSlidingWinStatus() { return (peers->getSlidingWinStatus()); };

  virtual u_int32_t getSlidingAvgCliContactedPeers() {
    return (peers->getCliSlidingEstimate());
  };
  virtual u_int32_t getSlidingAvgSrvContactedPeers() {
    return (peers->getSrvSlidingEstimate());
  };
  virtual u_int32_t getTotAvgCliContactedPeers() {
    return (peers->getCliTotEstimate());
  };
  virtual u_int32_t getTotAvgSrvContactedPeers() {
    return (peers->getSrvTotEstimate());
  };

  virtual void incSrvHostContacts(IpAddress *peer) {
    peer->incCardinality(&num_host_contacts_as_server);
    peer->incCardinality(&contacts_as_srv);
  }
  virtual void incCliContactedHosts(IpAddress *peer) {
    peer->incCardinality(&num_contacted_hosts_as_client);
    peer->incCardinality(&contacts_as_cli);
  }

  virtual void incContactedHosts(char *hostname) {
    if (hostname && (hostname[0] != '\0'))
      num_contacted_hosts.addElement(hostname, strlen(hostname));
  } /* Update the hosts contacts */
  virtual void addContactedDomainName(char *domain_name) {
    num_contacted_domain_names.addElement(domain_name, strlen(domain_name));
  }
  virtual void incContactedService(char *name) {
    if (name && (name[0] != '\0'))
      num_contacted_services_as_client.addElement(name, strlen(name));
  }
  virtual void incCountriesContacts(char *country) {
    if (country && (country[0] != '\0'))
      num_contacted_countries.addElement(country, strlen(country));
  } /* Update the countries contacts */
  virtual bool incNTPContactCardinality(Host *h) {
    if (h->get_ip())
      return (num_ntp_servers.addElement(h->get_ip()->key()));
    else
      return (false);
  };
  virtual bool incDNSContactCardinality(Host *h) {
    if (h->get_ip())
      return (num_dns_servers.addElement(h->get_ip()->key()));
    else
      return (false);
  };
  virtual bool incSMTPContactCardinality(Host *h) {
    if (h->get_ip())
      return (num_smtp_servers.addElement(h->get_ip()->key()));
    else
      return (false);
  };
  virtual bool incIMAPContactCardinality(Host *h) {
    if (h->get_ip())
      return (num_imap_servers.addElement(h->get_ip()->key()));
    else
      return (false);
  };
  virtual bool incPOPContactCardinality(Host *h) {
    if (h->get_ip())
      return (num_pop_servers.addElement(h->get_ip()->key()));
    else
      return (false);
  };

  virtual u_int16_t getCountriesContactsCardinality() {
    return ((u_int16_t)num_contacted_countries.getEstimate());
  } /* Get the countries */
  virtual u_int16_t getContactedHostsCardinality() {
    return ((u_int16_t)num_contacted_hosts.getEstimate());
  } /* Get the hosts */
  virtual u_int32_t getNTPContactCardinality() {
    return (num_ntp_servers.getEstimate());
  };
  virtual u_int32_t getDNSContactCardinality() {
    return (num_dns_servers.getEstimate());
  };
  virtual u_int32_t getSMTPContactCardinality() {
    return (num_smtp_servers.getEstimate());
  };
  virtual u_int32_t getIMAPContactCardinality() {
    return (num_imap_servers.getEstimate());
  };
  virtual u_int32_t getPOPContactCardinality() {
    return (num_pop_servers.getEstimate());
  };
  virtual u_int32_t getDomainNamesCardinality() {
    return num_contacted_domain_names.getEstimate();
  }

  virtual void resetCountriesContacts() {
    num_contacted_countries.reset();
  } /* Reset the countries */
  virtual void resetContactedHosts() {
    num_contacted_hosts.reset();
  } /* Reset the hosts */
  virtual void resetDomainNamesCardinality() {
    num_contacted_domain_names.reset();
  }
  inline void resetTopSitesData() { top_sites->clear(); }
};

#endif
