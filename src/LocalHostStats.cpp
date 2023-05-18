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

#include "ntop_includes.h"

/* *************************************** */

LocalHostStats::LocalHostStats(Host *_host) : HostStats(_host) {
  top_sites = new (std::nothrow) MostVisitedList(HOST_SITES_TOP_NUMBER);

  dns = new (std::nothrow) DnsStats();
  http = new (std::nothrow) HTTPstats(_host);
  icmp = new (std::nothrow) ICMPstats();
  peers = new (std::nothrow)
      PeerStats(MAX_DYNAMIC_STATS_VALUES /* 10 as default */);

  nextPeriodicUpdate = 0;
  num_contacts_as_cli = num_contacts_as_srv = 0;

  num_contacted_hosts_as_client.init(8);    /* 128 bytes */
  num_host_contacts_as_server.init(8);      /* 128 bytes */
  num_contacted_services_as_client.init(8); /* 128 bytes */
  num_contacted_hosts.init(4);              /* 16 bytes  */
  num_contacted_countries.init(4);          /* 16 bytes  */
  contacts_as_cli.init(4);                  /* 16 bytes  */
  contacts_as_srv.init(4);                  /* 16 bytes  */

  num_dns_servers.init(5);
  num_smtp_servers.init(5);
  num_ntp_servers.init(5);
  num_imap_servers.init(5);
  num_pop_servers.init(5);
  num_contacted_domain_names.init(4);
}

/* *************************************** */

LocalHostStats::LocalHostStats(LocalHostStats &s) : HostStats(s) {
  top_sites = new (std::nothrow) MostVisitedList(HOST_SITES_TOP_NUMBER);
  peers = new (std::nothrow)
      PeerStats(MAX_DYNAMIC_STATS_VALUES /* 10 as default */);
  dns = s.getDNSstats() ? new (std::nothrow) DnsStats(*s.getDNSstats()) : NULL;
  http = NULL;
  icmp = NULL;
  nextPeriodicUpdate = 0;
  num_contacts_as_cli = num_contacts_as_srv = 0;

  num_contacted_hosts_as_client.init(8);    /* 128 bytes */
  num_host_contacts_as_server.init(8);      /* 128 bytes */
  num_contacted_services_as_client.init(8); /* 128 bytes */
  num_contacted_hosts.init(4);              /* 16 bytes  */
  num_contacted_countries.init(4);          /* 16 bytes  */
  contacts_as_cli.init(4);                  /* 16 bytes  */
  contacts_as_srv.init(4);                  /* 16 bytes  */

  num_dns_servers.init(5);
  num_smtp_servers.init(5);
  num_ntp_servers.init(5);
  num_imap_servers.init(5);
  num_pop_servers.init(5);
  num_contacted_domain_names.init(4);
}

/* *************************************** */

LocalHostStats::~LocalHostStats() {
  if (top_sites) delete top_sites;
  if (dns) delete dns;
  if (http) delete http;
  if (icmp) delete icmp;
  if (peers) delete (peers);
}

/* *************************************** */

void LocalHostStats::incrVisitedWebSite(char *hostname) {
  u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
  char *firstdot = NULL, *nextdot = NULL;

  if ((strstr(hostname, "in-addr.arpa") == NULL) &&
      (sscanf(hostname, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) != 4)) {
    incContactedHosts(hostname);

    /* Top Sites update, done only if the preference is enabled */
    if (top_sites && ntop->getPrefs()->are_top_talkers_enabled()) {
      if (ntop->isATrackerHost(hostname)) {
        ntop->getTrace()->traceEvent(TRACE_INFO, "[TRACKER] %s", hostname);
        return; /* Ignore trackers */
      }

      firstdot = strchr(hostname, '.');

      if (firstdot) nextdot = strchr(&firstdot[1], '.');

      top_sites->incrVisitedData(nextdot ? &firstdot[1] : hostname, 1);
      host->getInterface()->incrVisitedWebSite(nextdot ? &firstdot[1]
                                                       : hostname);
    }
  }
}

/* *************************************** */

void LocalHostStats::updateStats(const struct timeval *tv) {
  HostStats::updateStats(tv);

  if (dns) dns->updateStats(tv);
  if (icmp) icmp->updateStats(tv);
  if (http) http->updateStats(tv);

  /* 5 Min Update */
  if (tv->tv_sec >= nextPeriodicUpdate) {
    /* visited sites update */
    contacted_hosts.addObservation(getContactedHostsCardinality());
    resetContactedHosts();

    /* countries contacts update */
    resetCountriesContacts();

    /* Contacted peers update */
    updateHostContacts();

    if (ntop->getPrefs()->are_top_talkers_enabled()) {
      if (top_sites && host) {
        char additional_key_info[128];
        if (!host->get_mac() && !host->get_ip()) return;

        /* String like `_1.1.1.1@2` */
        snprintf(
            additional_key_info, sizeof(additional_key_info), "_%s",
            host->get_tskey(additional_key_info, sizeof(additional_key_info)));
        top_sites->saveOldData(
            host->getInterface()->get_id(), additional_key_info,
            (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED);
      }
    }

    nextPeriodicUpdate = tv->tv_sec + HOST_SITES_REFRESH;
  }
}

/* *************************************** */

void LocalHostStats::updateHostContacts() {
  num_contacts_as_cli = contacts_as_cli.getEstimate(),
  num_contacts_as_srv = contacts_as_srv.getEstimate();
  if (peers) {
    peers->addElement(num_contacts_as_cli, true);
    peers->addElement(num_contacts_as_srv, false);
  }
  contacts_as_cli.reset(), contacts_as_srv.reset();
}

/* *************************************** */

void LocalHostStats::getJSONObject(json_object *my_object,
                                   DetailsLevel details_level) {
  HostStats::getJSONObject(my_object, details_level);

  if (dns) json_object_object_add(my_object, "dns", dns->getJSONObject());
  if (http) json_object_object_add(my_object, "http", http->getJSONObject());

  /* UDP stats */
  if (udp_sent_unicast)
    json_object_object_add(my_object, "udpBytesSent.unicast",
                           json_object_new_int64(udp_sent_unicast));
  if (udp_sent_non_unicast)
    json_object_object_add(my_object, "udpBytesSent.non_unicast",
                           json_object_new_int64(udp_sent_non_unicast));

  addRedisSitesKey();
}

/* *************************************** */

void LocalHostStats::luaHostBehaviour(lua_State *vm) {
  HostStats::luaHostBehaviour(vm);

  lua_newtable(vm);

  lua_push_uint32_table_entry(vm, "value", getContactedHostsCardinality());
  lua_push_bool_table_entry(vm, "anomaly", contacted_hosts.anomalyFound());
  lua_push_uint64_table_entry(vm, "lower_bound",
                              contacted_hosts.getLastLowerBound());
  lua_push_uint64_table_entry(vm, "upper_bound",
                              contacted_hosts.getLastUpperBound());

  lua_pushstring(vm, "contacted_hosts_behaviour");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHostStats::lua(lua_State *vm, bool mask_host,
                         DetailsLevel details_level) {
  HostStats::lua(vm, mask_host, details_level);

  if ((!mask_host) && top_sites &&
      ntop->getPrefs()->are_top_talkers_enabled()) {
    top_sites->lua(vm, (char *)"sites", (char *)"sites.old");
  }

  luaHostBehaviour(vm);

  if (details_level >= details_high) {
    luaICMP(vm, host->get_ip()->isIPv4(), true);
    luaDNS(vm, true);
    luaHTTP(vm);

    /* Contacts */
    lua_newtable(vm);

    lua_push_int32_table_entry(vm, "num_contacted_hosts_as_client",
                               num_contacted_hosts_as_client.getEstimate());
    lua_push_int32_table_entry(vm, "num_host_contacts_as_server",
                               num_host_contacts_as_server.getEstimate());
    lua_push_int32_table_entry(vm, "num_contacted_services_as_client",
                               num_contacted_services_as_client.getEstimate());

    lua_pushstring(vm, "cardinality");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void LocalHostStats::luaPeers(lua_State *vm) {
  if (peers) {
    if (peers->getSlidingWinStatus()) {
      lua_newtable(vm);

      lua_push_int32_table_entry(vm, "contacted_peers_in_last_5mins_as_cli",
                                 num_contacts_as_cli);
      lua_push_int32_table_entry(vm, "contacted_peers_in_last_5mins_as_srv",
                                 num_contacts_as_srv);
      lua_push_int32_table_entry(vm, "sliding_avg_peers_as_client",
                                 peers->getCliSlidingEstimate());
      lua_push_int32_table_entry(vm, "sliding_avg_peers_as_server",
                                 peers->getSrvSlidingEstimate());
      lua_push_int32_table_entry(vm, "tot_avg_peers_as_client",
                                 peers->getCliTotEstimate());
      lua_push_int32_table_entry(vm, "tot_avg_peers_as_server",
                                 peers->getSrvTotEstimate());

      lua_pushstring(vm, "peers");
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      return;
    }
  }

  lua_pushnil(vm);
}

/* *************************************** */

void LocalHostStats::lua_get_timeseries(lua_State *vm) {
  luaStats(vm, host->getInterface(), true /* host details */,
           true /* verbose */, true /* tsLua */);

  tcp_packet_stats_sent.lua(vm, "tcpPacketStats.sent");
  tcp_packet_stats_rcvd.lua(vm, "tcpPacketStats.rcvd");

  if (dns) dns->lua(vm, false /* NOT verbose */);

  if (icmp) {
    struct ts_icmp_stats icmp_s;
    icmp->getTsStats(&icmp_s);

    lua_push_uint64_table_entry(vm, "icmp.echo_pkts_sent",
                                icmp_s.echo_packets_sent);
    lua_push_uint64_table_entry(vm, "icmp.echo_pkts_rcvd",
                                icmp_s.echo_packets_rcvd);
    lua_push_uint64_table_entry(vm, "icmp.echo_reply_pkts_sent",
                                icmp_s.echo_reply_packets_sent);
    lua_push_uint64_table_entry(vm, "icmp.echo_reply_pkts_rcvd",
                                icmp_s.echo_reply_packets_rcvd);
  }

  luaHostBehaviour(vm);
}

/* *************************************** */

bool LocalHostStats::hasAnomalies(time_t when) {
  bool ret = false;

  if (dns) ret |= dns->hasAnomalies(when);
  if (icmp) ret |= icmp->hasAnomalies(when);

  return ret;
}

/* *************************************** */

void LocalHostStats::luaAnomalies(lua_State *vm, time_t when) {
  if (dns) dns->luaAnomalies(vm, when);
  if (icmp) icmp->luaAnomalies(vm, when);
}

/* *************************************** */

void LocalHostStats::incStats(time_t when, u_int8_t l4_proto, u_int ndpi_proto,
                              ndpi_protocol_category_t ndpi_category,
                              custom_app_t custom_app, u_int64_t sent_packets,
                              u_int64_t sent_bytes,
                              u_int64_t sent_goodput_bytes,
                              u_int64_t rcvd_packets, u_int64_t rcvd_bytes,
                              u_int64_t rcvd_goodput_bytes,
                              bool peer_is_unicast) {
  HostStats::incStats(when, l4_proto, ndpi_proto, ndpi_category, custom_app,
                      sent_packets, sent_bytes, sent_goodput_bytes,
                      rcvd_packets, rcvd_bytes, rcvd_goodput_bytes,
                      peer_is_unicast);

  if (l4_proto == IPPROTO_UDP) {
    if (peer_is_unicast)
      udp_sent_unicast += sent_bytes;
    else
      udp_sent_non_unicast += sent_bytes;
  }
}

/* *************************************** */

void LocalHostStats::removeRedisSitesKey() {
  char additional_key_info[128];

  if (!host->get_mac() && !host->get_ip()) return;

  /* String like `_1.1.1.1@2` */
  snprintf(additional_key_info, sizeof(additional_key_info), "%s_",
           host->get_tskey(additional_key_info, sizeof(additional_key_info)));
  /* Deserializing the info */
  top_sites->serializeDeserialize(
      host->getInterface()->get_id(), false, additional_key_info,
      (char *)HASHKEY_TOP_SITES_SERIALIZATION_KEY,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_DAY_KEYS_PUSHED);
}

/* *************************************** */

void LocalHostStats::addRedisSitesKey() {
  char additional_key_info[128];

  if (!host->get_mac() && !host->get_ip()) return;

  /* String like `_1.1.1.1@2` */
  snprintf(additional_key_info, sizeof(additional_key_info), "%s_",
           host->get_tskey(additional_key_info, sizeof(additional_key_info)));
  /* Serializing the info */
  top_sites->serializeDeserialize(
      host->getInterface()->get_id(), true, additional_key_info,
      (char *)HASHKEY_TOP_SITES_SERIALIZATION_KEY,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_DAY_KEYS_PUSHED);
}
