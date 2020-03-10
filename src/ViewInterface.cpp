/*
 *
 * (C) 2013-20 - ntop.org
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
  is_packet_interface = true;

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
	      what->setViewed(this);
	      viewed_interfaces[num_viewed_interfaces++] = what;
	      is_packet_interface &= what->isPacketInterface();
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
			   void *user_data) {
  bool ret = false;
  u_int32_t flows_begin_slot = 0; /* Always from the beginning, all flows */

  if(id == SYSTEM_INTERFACE_ID)
    return(false);

  switch(wtype) {
  case walker_flows:
    for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
      flows_begin_slot = 0; /* Always visit all the flows starting from slot 0 */
      ret |= viewed_interfaces[s]->walker(&flows_begin_slot, true /* walk_all == true */, wtype, walker, user_data);
    }
    break;
  default:
    ret = NetworkInterface::walker(begin_slot, walk_all, wtype, walker, user_data);
    break;
  }

  return(ret);
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

u_int64_t ViewInterface::getNumDiscardedProbingPackets() const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumDiscardedProbingPackets();

  return(tot);
};


/* **************************************************** */

u_int64_t ViewInterface::getNumDiscardedProbingBytes() const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumDiscardedProbingBytes();

  return(tot);
};


/* **************************************************** */

u_int64_t ViewInterface::getNumNewFlows() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumNewFlows();

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

u_int ViewInterface::getNumDroppedFlowScriptsCalls() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumDroppedFlowScriptsCalls();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getNumActiveAlertedFlows() const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumActiveAlertedFlows();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getNumActiveMisbehavingFlows() const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumActiveMisbehavingFlows();

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

u_int64_t ViewInterface::getCheckPointNumDiscardedProbingPackets() const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumDiscardedProbingPackets();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getCheckPointNumDiscardedProbingBytes() const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumDiscardedProbingBytes();

  return(tot);
};

/* **************************************************** */

void ViewInterface::checkPointCounters(bool drops_only) {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    viewed_interfaces[s]->checkPointCounters(drops_only);
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

Flow* ViewInterface::findFlowByKeyAndHashId(u_int32_t key, u_int hash_id, AddressTree *allowed_hosts) {
  Flow *f = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((f = (Flow*)viewed_interfaces[s]->findFlowByKeyAndHashId(key, hash_id, allowed_hosts)))
      break;
  }

  return(f);
}

/* **************************************************** */

void ViewInterface::sumStats(TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
			     LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
			     PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats,
			     ProtoStats *_discardedProbingStats) const {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    viewed_interfaces[s]->sumStats(_tcpFlowStats, _ethStats, _localStats, _ndpiStats, _pktStats, _tcpPacketStats, _discardedProbingStats);
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

/* NOTE: this method is void, it does not correspond to the
 * static bool NetworkInterface::periodicHTStateUpdate. */
void ViewInterface::periodicHTStateUpdate(time_t deadline, lua_State* vm, bool skip_user_scripts) {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    viewed_interfaces[s]->periodicHTStateUpdate(deadline, vm, skip_user_scripts);

  /* Also call the base, overridden NetworkInterface::periodicHTStateUpdate for this view.
     It is necessary to ensure idle hash entries (e.g., hosts) are deleted from memory */
  NetworkInterface::periodicHTStateUpdate(deadline, vm, skip_user_scripts);

  /* It is necessary to call purgeIdle explicitly here (other than in
   * ViewInterface::generic_periodic_hash_entry_state_update) as if all the
   * sub interfaces hash tables are empty generic_periodic_hash_entry_state_update
   * would not be called. */
  purgeIdle(time(NULL));
}

/* **************************************************** */

void ViewInterface::viewed_flows_walker(Flow *f, void *user_data) {
  periodic_ht_state_update_user_data_t *periodic_ht_state_update_user_data = (periodic_ht_state_update_user_data_t*)user_data;
  const struct timeval *tv = periodic_ht_state_update_user_data->tv;

  NetworkStats *network_stats;
  PartializableFlowTrafficStats partials;
  bool first_partial; /* Whether this is the first time the view is visiting this flow */
  const IpAddress *cli_ip = f->get_cli_ip_addr(), *srv_ip = f->get_srv_ip_addr();

  if(f->get_last_seen() > getTimeLastPktRcvd())
    setTimeLastPktRcvd(f->get_last_seen());

  if(f->get_partial_traffic_stats_view(&partials, &first_partial)) {
    if(!cli_ip || !srv_ip)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to get flow hosts. Out of memory? Expect issues.");

    if(cli_ip && srv_ip) {
      Host *cli_host = NULL, *srv_host = NULL;

      findFlowHosts(f->get_vlan_id(),
		    NULL /* no src mac yet */, (IpAddress*)cli_ip, &cli_host,
		    NULL /* no dst mac yet */, (IpAddress*)srv_ip, &srv_host);

      f->hosts_periodic_stats_update(this, cli_host, srv_host, &partials, first_partial, tv);

      if(cli_host) {
	if(first_partial) {
	  cli_host->incNumFlows(f->get_last_seen(), true, srv_host, f), cli_host->incUses();
	  network_stats = cli_host->getNetworkStats(cli_host->get_local_network_id());
	  if(network_stats) network_stats->incNumFlows(f->get_last_seen(), true);
	  if(f->getViewInterfaceFlowStats()) f->getViewInterfaceFlowStats()->setClientHost(cli_host);
	}

	if(f->idle())
	  cli_host->decNumFlows(f->get_last_seen(), true, srv_host, f), cli_host->decUses();
      }

      if(srv_host) {
	if(first_partial) {
	  srv_host->incUses(), srv_host->incNumFlows(f->get_last_seen(), false, cli_host, f);
	  network_stats = srv_host->getNetworkStats(srv_host->get_local_network_id());
	  if(network_stats) network_stats->incNumFlows(f->get_last_seen(), false);
	  if(f->getViewInterfaceFlowStats()) f->getViewInterfaceFlowStats()->setServerHost(srv_host);
	}

	if(f->idle())
	  srv_host->decUses(), srv_host->decNumFlows(f->get_last_seen(), false, cli_host, f);
      }

      incStats(true /* ingressPacket */,
	       tv->tv_sec, cli_ip && cli_ip->isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	       f->getStatsProtocol(), f->get_protocol_category(),
	       f->get_protocol(),
	       partials.get_srv2cli_bytes() + partials.get_cli2srv_bytes(),
	       partials.get_srv2cli_packets() + partials.get_cli2srv_packets(),
	       24 /* 8 Preamble + 4 CRC + 12 IFG */ + 14 /* Ethernet header */);
    }
  }
}

/* **************************************************** */

void ViewInterface::flowPollLoop() {
  while(!ntop->getGlobals()->isShutdownRequested()) {
    while(idle()) sleep(1);
    /* Nothing to do, everything is done in ViewInterface::generic_periodic_hash_entry_state_update */
    _usleep(1000000);
  }
}

/* **************************************************** */

void ViewInterface::generic_periodic_hash_entry_state_update(GenericHashEntry *node, void *user_data) {
  periodic_ht_state_update_user_data_t *periodic_ht_state_update_user_data = (periodic_ht_state_update_user_data_t*)user_data;
  /* The user data contains the pointer to the original underlying viewed interface which has called us.
     So in order to reterieve `this` pointer, it suffices to access iface method viewedBy() */
  ViewInterface *this_view = periodic_ht_state_update_user_data->iface->viewedBy();

  /* Trigger the walker only for flows - it's that walker which triggers the creation of hosts
     and other hash table entries. */
  if(Flow *flow = dynamic_cast<Flow*>(node)) {
    this_view->viewed_flows_walker(flow, user_data);
  }

  /* purgeIdle must be called here as this is the only point where the update of the hash tables
     is sequential with the purging of the same. */
  this_view->purgeIdle(time(NULL));
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
