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

/* **************************************************** */

ViewInterface::ViewInterface(const char *_endpoint) : NetworkInterface(_endpoint) {
  is_view = true; /* This is a view interface */

  memset(viewed_interfaces, 0, sizeof(viewed_interfaces));
  num_viewed_interfaces = 0;
  char *ifaces = strdup(&_endpoint[5]); /* Skip view: */

  if(ifaces) {
    char *tmp, *iface = strtok_r(ifaces, ",", &tmp);

    while(iface != NULL) {
      bool found = false;

      for(int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
	char *ifName;

	if((ifName = ntop->get_if_name(i)) == NULL)
	  continue;

	if(!strncmp(ifName, iface, MAX_INTERFACE_NAME_LEN)) {
	  found = true;
	  
	  if(num_viewed_interfaces < MAX_NUM_VIEW_INTERFACES) {
	    NetworkInterface *what = ntop->getInterfaceById(i);

	    if(!what)
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal Error: NULL interface [%s][%d]", ifName, i);
	    else if(what->isViewed())
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Interface already belonging to a view [%s][%d]", ifName, i);
	    else {
	      what->setViewed();
	      viewed_interfaces[num_viewed_interfaces++] = what;
	    }
	  }

	  break;
	}
      }

      if(!found) 
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping view sub-interface %s: not found", iface);
      else if(num_viewed_interfaces == MAX_NUM_VIEW_INTERFACES)
	break; /* Upper interface limit reached */
      
      iface = strtok_r(NULL, ",", &tmp);
    }
    
    free(ifaces);
  }
}

/* **************************************************** */

bool ViewInterface::walker(u_int32_t *begin_slot,
			   bool walk_all,
			   WalkerType wtype,
			   bool (*walker)(GenericHashEntry *h, void *user_data, bool *matched),
			   void *user_data,
			   bool walk_idle) {
  bool ret = false;
  u_int32_t flows_begin_slot = 0; /* Always from the beginning, all flows */

  switch(wtype) {
  case walker_flows:
    for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
      flows_begin_slot = 0; /* Always visit all the flows starting from slot 0 */
      ret |= viewed_interfaces[s]->walker(&flows_begin_slot, true /* walk_all == true */, wtype, walker, user_data, walk_idle);
    }
    break;
  default:
    ret = NetworkInterface::walker(begin_slot, walk_all, wtype, walker, user_data, walk_idle);
    break;
  }

  return ret;
}

/* **************************************************** */

u_int64_t ViewInterface::getNumPackets() {  
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumPackets();

  return(tot);
};

/* **************************************************** */

u_int32_t ViewInterface::getNumPacketDrops() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumDroppedPackets();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumFlows() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumFlows();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getNumBytes() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumBytes();

  return(tot);
}

/* **************************************************** */

u_int64_t ViewInterface::getCheckPointNumPackets() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumPackets();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getCheckPointNumBytes() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumBytes();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getCheckPointNumPacketDrops() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumPacketDrops();

  return(tot);
};

/* **************************************************** */

bool ViewInterface::hasSeenVlanTaggedPackets() const {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if(viewed_interfaces[s]->hasSeenVlanTaggedPackets())
      return true;
  }

  return false;
}

/* **************************************************** */

u_int32_t ViewInterface::getFlowsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getFlowsHashSize();

  return(tot);
}

/* **************************************************** */

Flow* ViewInterface::findFlowByKey(u_int32_t key, AddressTree *allowed_hosts) {
  Flow *f = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((f = (Flow*)viewed_interfaces[s]->findFlowByKey(key, allowed_hosts)))
      break;
  }

  return(f);
}

/* **************************************************** */

void ViewInterface::sumStats(TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
			     LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
			     PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats) const {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    viewed_interfaces[s]->sumStats(_tcpFlowStats, _ethStats, _localStats, _ndpiStats, _pktStats, _tcpPacketStats);
}

/* **************************************************** */

Flow* ViewInterface::findFlowByTuple(u_int16_t vlan_id,
				     IpAddress *src_ip,  IpAddress *dst_ip,
				     u_int16_t src_port, u_int16_t dst_port,
				     u_int8_t l4_proto,
				     AddressTree *allowed_hosts) const {
  Flow *f = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((f = (Flow*)viewed_interfaces[s]->findFlowByTuple(vlan_id, src_ip, dst_ip, src_port, dst_port, l4_proto, allowed_hosts)))
      break;
  }

  return(f);
}

/* **************************************************** */

typedef struct {
  struct timeval tv;
  ViewInterface *iface;
} viewed_flows_walker_user_data_t;

/* **************************************************** */

static bool viewed_flows_walker(GenericHashEntry *flow, void *user_data, bool *matched) {
  viewed_flows_walker_user_data_t *viewed_flows_walker_user_data = (viewed_flows_walker_user_data_t*)user_data;
  ViewInterface *iface = viewed_flows_walker_user_data->iface;
  const struct timeval *tv = &viewed_flows_walker_user_data->tv;
  Flow *f = (Flow*)flow;
  bool acked_to_purge;

  acked_to_purge = f->is_acknowledged_to_purge();

  if(acked_to_purge) {
    /* We can set the 'ready to be purged' state on behalf of the underlying viewed interface.
       It is safe as this view is in sync with the viewed interfaces by bean of acked_to_purge */
    f->set_hash_entry_state_ready_to_be_purged();
  }

  f->dumpFlow(tv, iface);

  FlowTrafficStats partials;
  bool first_partial; /* Whether this is the first time the view is visiting this flow */
  const IpAddress *cli_ip = f->get_cli_ip_addr(), *srv_ip = f->get_srv_ip_addr();

  if(f->get_partial_traffic_stats_view(&partials, &first_partial)) {
    if(!cli_ip || !srv_ip)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to get flow hosts. Out of memory? Expect issues.");

    if(cli_ip && srv_ip) {
      Host *cli_host = NULL, *srv_host = NULL;

      iface->findFlowHosts(f->get_vlan_id(),
			   NULL /* no src mac yet */, (IpAddress*)cli_ip, &cli_host,
			   NULL /* no dst mac yet */, (IpAddress*)srv_ip, &srv_host);

      if(cli_host) {
	cli_host->incStats(tv->tv_sec, f->get_protocol(), f->getStatsProtocol(), f->getCustomApp(),
			   partials.cli2srv_packets, partials.cli2srv_bytes, partials.cli2srv_goodput_bytes,
			   partials.srv2cli_packets, partials.srv2cli_bytes, partials.srv2cli_goodput_bytes,
			   cli_ip->isNonEmptyUnicastAddress());

	if(first_partial)
	  cli_host->incNumFlows(f->get_last_seen(), true, srv_host), cli_host->incUses();

	if(acked_to_purge)
	  cli_host->decNumFlows(f->get_last_seen(), true, srv_host), cli_host->decUses();
      }

      if(srv_host) {
	srv_host->incStats(tv->tv_sec, f->get_protocol(), f->getStatsProtocol(), f->getCustomApp(),
			   partials.srv2cli_packets, partials.srv2cli_bytes, partials.srv2cli_goodput_bytes,
			   partials.cli2srv_packets, partials.cli2srv_bytes, partials.cli2srv_goodput_bytes,
			   srv_ip->isNonEmptyUnicastAddress());

	if(first_partial)
	  srv_host->incUses(), srv_host->incNumFlows(f->get_last_seen(), false, cli_host);

	if(acked_to_purge)
	  srv_host->decUses(), srv_host->decNumFlows(f->get_last_seen(), false, cli_host);
      }

      iface->incStats(true /* ingressPacket */,
		      tv->tv_sec, cli_ip && cli_ip->isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
		      f->getStatsProtocol(), f->get_protocol(),
		      partials.srv2cli_bytes + partials.cli2srv_bytes,
		      partials.srv2cli_packets + partials.cli2srv_packets,
		      24 /* 8 Preamble + 4 CRC + 12 IFG */ + 14 /* Ethernet header */);

      Flow::incTcpBadStats(true /* src2dst */, NULL, cli_host, srv_host,
			   partials.tcp_stats_s2d.pktOOO, partials.tcp_stats_s2d.pktRetr,
			   partials.tcp_stats_s2d.pktLost, partials.tcp_stats_s2d.pktKeepAlive);

      Flow::incTcpBadStats(false /* dst2src */, NULL, cli_host, srv_host,
			   partials.tcp_stats_d2s.pktOOO, partials.tcp_stats_d2s.pktRetr,
			   partials.tcp_stats_d2s.pktLost, partials.tcp_stats_d2s.pktKeepAlive);
    }
  }

  return false; /* Move on to the next flow, keep walking */
}

/* **************************************************** */

void ViewInterface::viewedFlowsWalker() {
  u_int32_t begin_slot;
  viewed_flows_walker_user_data_t viewed_flows_walker_user_data;

  viewed_flows_walker_user_data.tv.tv_sec = time(NULL),
    viewed_flows_walker_user_data.tv.tv_usec = 0,
    viewed_flows_walker_user_data.iface = this;      

  begin_slot = 0; /* Always visit all flows starting from the first slot */
  walker(&begin_slot, true /* walk all the flows */, walker_flows, viewed_flows_walker, &viewed_flows_walker_user_data, true /* visit also idle flows (required to acknowledge the purge) */);

#ifdef NTOPNG_PRO
  dumpAggregatedFlows(&viewed_flows_walker_user_data.tv);
#endif
}

/* **************************************************** */

void ViewInterface::flowPollLoop() {
  while(!ntop->getGlobals()->isShutdownRequested()) {
    while(idle()) sleep(1);

    viewedFlowsWalker();

    purgeIdle(time(NULL));
    usleep(500000);
  }
}

/* **************************************************** */

static void* flowPollLoop(void* ptr) {
  ViewInterface *iface = (ViewInterface*)ptr;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  iface->flowPollLoop();

  return NULL;
}

/* **************************************************** */

void ViewInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, ::flowPollLoop, this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}
