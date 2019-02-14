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

#include "ntop_includes.h"

/* *************************************** */

LocalHostStats::LocalHostStats(Host *_host) : HostStats(_host) {
  top_sites = new FrequentStringItems(HOST_SITES_TOP_NUMBER);
  old_sites = strdup("{}");
  dns  = new DnsStats();
  http = new HTTPstats(iface->get_hosts_hash());
  icmp = NULL;
  nextSitesUpdate = 0;

  if(TimeseriesRing::isRingEnabled(ntop->getPrefs()))
    ts_ring = new TimeseriesRing(iface);
  else
    ts_ring = NULL;
}

/* *************************************** */

LocalHostStats::~LocalHostStats() {
  if(top_sites)       delete top_sites;
  if(old_sites)       free(old_sites);
  if(dns)             delete dns;
  if(http)            delete http;
  if(icmp)            delete icmp;
  if(ts_ring)         delete ts_ring;
}

/* *************************************** */

void LocalHostStats::incrVisitedWebSite(char *hostname) {
  u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
  char *firstdot = NULL, *nextdot = NULL;

  if(top_sites
     && ntop->getPrefs()->are_top_talkers_enabled()
     && (strstr(hostname, "in-addr.arpa") == NULL)
     && (sscanf(hostname, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) != 4)
     ) {
    if(ntop->isATrackerHost(hostname)) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "[TRACKER] %s", hostname);
      return; /* Ignore trackers */
    }

    firstdot = strchr(hostname, '.');

    if(firstdot)
      nextdot = strchr(&firstdot[1], '.');

    top_sites->add(nextdot ? &firstdot[1] : hostname, 1);
  }
}

/* *************************************** */

void LocalHostStats::updateStats(struct timeval *tv) {
  HostStats::updateStats(tv);

  if(http) http->updateStats(tv);

  if(top_sites && ntop->getPrefs()->are_top_talkers_enabled() && (tv->tv_sec >= nextSitesUpdate)) {
    if(nextSitesUpdate > 0) {
      if(old_sites)
	free(old_sites);
      old_sites = top_sites->json();
    }

    nextSitesUpdate = tv->tv_sec + HOST_SITES_REFRESH;
  }

  /* The ring can be enabled at runtime so we need to check for allocation */
  if(!ts_ring && TimeseriesRing::isRingEnabled(ntop->getPrefs()))
    ts_ring = new TimeseriesRing(iface);
  
  if(ts_ring && ts_ring->isTimeToInsert()) {
    HostTimeseriesPoint *pt = new HostTimeseriesPoint();
    
    makeTsPoint(pt);
    /* Ownership of the point is passed to the ring */
    ts_ring->insert(pt, last_update_time.tv_sec);
  }
}

/* *************************************** */

void LocalHostStats::getJSONObject(json_object *my_object, DetailsLevel details_level) {
  HostStats::getJSONObject(my_object, details_level);

  if(dns)  json_object_object_add(my_object, "dns", dns->getJSONObject());
  if(http) json_object_object_add(my_object, "http", http->getJSONObject());
}

/* *************************************** */

void LocalHostStats::lua(lua_State* vm, bool mask_host, bool host_details, bool verbose) {
  HostStats::lua(vm, mask_host, host_details, verbose);

  if((!mask_host) && top_sites && ntop->getPrefs()->are_top_talkers_enabled()) {
    char *cur_sites = top_sites->json();
    lua_push_str_table_entry(vm, "sites", cur_sites ? cur_sites : (char*)"{}");
    lua_push_str_table_entry(vm, "sites.old", old_sites ? old_sites : (char*)"{}");
    if(cur_sites) free(cur_sites);
  }

  if(host_details) {
    if(icmp)
      icmp->lua(host->get_ip()->isIPv4(), vm);
  }

  if(verbose) {
    if(dns)            dns->lua(vm);
    if(http)           http->lua(vm);
  }
}

/* *************************************** */

void LocalHostStats::deserialize(json_object *o) {
  json_object *obj;

  HostStats::deserialize(o);

  if(json_object_object_get_ex(o, "tcp_sent", &obj))  tcp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "tcp_rcvd", &obj))  tcp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "udp_sent", &obj))  udp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "udp_rcvd", &obj))  udp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "icmp_sent", &obj))  icmp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "icmp_rcvd", &obj))  icmp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "other_ip_sent", &obj))  other_ip_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "other_ip_rcvd", &obj))  other_ip_rcvd.deserialize(obj);

  /* packet stats */
  if(json_object_object_get_ex(o, "pktStats.sent", &obj))  sent_stats.deserialize(obj);
  if(json_object_object_get_ex(o, "pktStats.recv", &obj))  recv_stats.deserialize(obj);

  /* TCP packet stats */
  if(json_object_object_get_ex(o, "tcpPacketStats.pktRetr", &obj)) tcpPacketStats.pktRetr = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "tcpPacketStats.pktOOO",  &obj)) tcpPacketStats.pktOOO  = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "tcpPacketStats.pktLost", &obj)) tcpPacketStats.pktLost = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "tcpPacketStats.pktKeepAlive", &obj)) tcpPacketStats.pktKeepAlive = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "sent", &obj))  sent.deserialize(obj);
  if(json_object_object_get_ex(o, "rcvd", &obj))  rcvd.deserialize(obj);
  last_bytes = sent.getNumBytes() + rcvd.getNumBytes();
  last_packets = sent.getNumPkts() + rcvd.getNumPkts();

  if(json_object_object_get_ex(o, "total_activity_time", &obj))  total_activity_time = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "dns", &obj)) {
    if(dns) dns->deserialize(obj);
  }

  if(json_object_object_get_ex(o, "http", &obj)) {
    if(http) http->deserialize(obj);
  }

  if(json_object_object_get_ex(o, "ndpiStats", &obj)) {
    if(ndpiStats) delete ndpiStats;
    ndpiStats = new nDPIStats();
    ndpiStats->deserialize(iface, obj);
  }

  if(json_object_object_get_ex(o, "pktStats.sent", &obj)) sent_stats.deserialize(obj);
  if(json_object_object_get_ex(o, "pktStats.recv", &obj)) recv_stats.deserialize(obj);

  if(json_object_object_get_ex(o, "flows.as_client", &obj))  total_num_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "flows.as_server", &obj))  total_num_flows_as_server = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "anomalous_flows.as_client", &obj))  anomalous_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "anomalous_flows.as_server", &obj))  anomalous_flows_as_server = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "flows.dropped", &obj)) total_num_dropped_flows = json_object_get_int(obj);
}

/* *************************************** */

void LocalHostStats::makeTsPoint(HostTimeseriesPoint *pt) {
  pt->ndpi = ndpiStats ? (new nDPIStats(*ndpiStats)) : NULL;
  pt->sent = sent.getNumBytes();
  pt->rcvd = rcvd.getNumBytes();
  pt->num_flows_as_client = host->getNumOutgoingFlows();
  pt->num_flows_as_server = host->getNumIncomingFlows();
  pt->num_contacts_as_cli = contacts_as_cli.size();
  pt->num_contacts_as_srv = contacts_as_srv.size();

  /* L4 */
  pt->l4_stats[0].sent = tcp_sent.getNumBytes();
  pt->l4_stats[0].rcvd = tcp_rcvd.getNumBytes();
  pt->l4_stats[1].sent = udp_sent.getNumBytes();
  pt->l4_stats[1].rcvd = udp_rcvd.getNumBytes();
  pt->l4_stats[2].sent = icmp_sent.getNumBytes();
  pt->l4_stats[2].rcvd = icmp_rcvd.getNumBytes();
  pt->l4_stats[3].sent = other_ip_sent.getNumBytes();
  pt->l4_stats[3].rcvd = other_ip_sent.getNumBytes();
}

/* *************************************** */

void LocalHostStats::incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {
  if(!icmp) icmp = new ICMPstats();
  if(icmp)  icmp->incStats(icmp_type, icmp_code, sent, peer);
}

/* *************************************** */

void LocalHostStats::incNumFlows(bool as_client, Host *peer) {
  HostStats::incNumFlows(as_client, peer);

  map<Host*, u_int16_t> *contacts_map;

  if(as_client)
    contacts_map = &contacts_as_cli;
  else
    contacts_map = &contacts_as_srv;

  if(peer) {
    (*contacts_map)[peer] += 1;

#if 0
      char buf1[64], buf2[64];
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "INC contacts: %s %s %s, now %u",
	get_string_key(buf1, sizeof(buf1)), as_client ? "->" : "<-",
	peer->get_string_key(buf2, sizeof(buf2)), (*contacts_map)[peer]);
#endif
  }
}

/* *************************************** */

void LocalHostStats::decNumFlows(bool as_client, Host *peer) {
  HostStats::decNumFlows(as_client, peer);

  if(peer) {
    map<Host*, u_int16_t> *contacts_map = as_client ? &contacts_as_cli : &contacts_as_srv;
    map<Host*, u_int16_t>::iterator it;

    if((it = contacts_map->find(peer)) != contacts_map->end()) {
      if(it->second)
	it->second -= 1;

#if 0
      char buf1[64], buf2[64];
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "DEC contacts: %s %s %s, now %u",
	get_string_key(buf1, sizeof(buf1)), as_client ? "->" : "<-",
	peer->get_string_key(buf2, sizeof(buf2)), it->second);
#endif

      if(!it->second)
	contacts_map->erase(it);
    }
  }
}

/* *************************************** */

void LocalHostStats::tsLua(lua_State* vm) {
  if(!ts_ring || !TimeseriesRing::isRingEnabled(ntop->getPrefs())) {
    /* Use real time data */
    HostTimeseriesPoint pt;
    
    makeTsPoint(&pt);
    TimeseriesRing::luaSinglePoint(vm, iface, &pt);
  } else
    ts_ring->lua(vm);
}
