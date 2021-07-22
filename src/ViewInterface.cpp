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

#include "ntop_includes.h"

/* **************************************************** */

ViewInterface::ViewInterface(const char *_endpoint) : NetworkInterface(_endpoint) {
  is_view = true; /* This is a view interface */
  is_packet_interface = true;

  memset(viewed_interfaces, 0, sizeof(viewed_interfaces));
  memset(viewed_interfaces_queues, 0, sizeof(viewed_interfaces_queues));
  num_viewed_interfaces = 0;

  if(!strcmp(_endpoint, "view:all")) {
    /* Create a view on all the active interfaces */
    for(int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
      NetworkInterface *iface = ntop->getInterface(i);

      if(!iface)
	break;

      if(!iface->isViewed() && (iface->getIfType() != interface_type_VIEW)) {
	if(!addSubinterface(iface))
	  break;
      }
    }
  } else {
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
	    NetworkInterface *what = ntop->getInterfaceById(i);

	    if(!what)
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal Error: NULL interface [%s][%d]", ifName, i);
	    else {
	      addSubinterface(what);
	      found = true;
	    }

	    break;
	  }
	}

	if(!found)
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping view sub-interface %s: not found", iface);
	else if(num_viewed_interfaces >= MAX_NUM_VIEW_INTERFACES)
	  break; /* Upper interface limit reached */

	iface = strtok_r(NULL, ",", &tmp);
      }
      
      free(ifaces);
    }
  }

  if(num_viewed_interfaces == 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Empty view interface: \"%s\"", get_name());
}

/* **************************************************** */

bool ViewInterface::viewEnqueue(time_t t, Flow *f, u_int8_t viewed_interface_id) {
  /*
    Put the element into the right single-producer (the viewed interface) single-consumer (this view interface) queue
   */
  if(viewed_interface_id < num_viewed_interfaces
     && viewed_interfaces_queues[viewed_interface_id]->enqueue(f, true)) {
    /*
      Enqueue was successful - enough room in the queue.
     */
    f->incUses(); /* Increase the reference counter. Decrease will be done when dequeuing this flow */
    return true;
  }

  return false;
}

/* **************************************************** */

u_int64_t ViewInterface::viewDequeue(u_int budget) {
  u_int64_t num = 0;
  struct timeval tv;

  gettimeofday(&tv, NULL);

  for(int i = 0; i < num_viewed_interfaces; i++) {
    u_int64_t flows_done = 0;

    while(viewed_interfaces_queues[i]->isNotEmpty()) {
      Flow *f = viewed_interfaces_queues[i]->dequeue();

      viewed_flows_walker(f, &tv);

#if 0
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeued view flow");
#endif

      f->decUses(); /* Decrease uses now that the job is done */

      flows_done++;
      if(budget > 0 /* Budget requested */
	 && flows_done >= budget /* Budget exceeded */)
	break;
    }

    num += flows_done;
  }

  return num;
}

/* **************************************************** */

bool ViewInterface::addSubinterface(NetworkInterface *what) {
  if(num_viewed_interfaces < MAX_NUM_VIEW_INTERFACES) {
    if(what->isViewed()) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Interface already belonging to a view [%s][%d]", what->get_name(), what->get_id());
      return(false);
    } else {
      char buf[MAX_INTERFACE_NAME_LEN + 7 /* strlen("viewed_") */ + 1];

      snprintf(buf, sizeof(buf), "viewed_%s", what->get_name());
      what->setViewed(this, num_viewed_interfaces);
      viewed_interfaces[num_viewed_interfaces] = what;
      /* Instantiate the queue which will be used by the view interface to enqueue flows for this view */
      viewed_interfaces_queues[num_viewed_interfaces] = new (std::nothrow) SPSCQueue<Flow *>(MAX_VIEW_INTERFACE_QUEUE_LEN, buf);
      num_viewed_interfaces++;
      is_packet_interface &= what->isPacketInterface();
      return(true);
    }
  }

  return(false);
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

u_int64_t ViewInterface::getNumDroppedAlerts() {  
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumDroppedAlerts();

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

u_int64_t ViewInterface::getNumActiveAlertedFlows() const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumActiveAlertedFlows();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getNumActiveAlertedFlows(AlertLevelGroup alert_level_group) const {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumActiveAlertedFlows(alert_level_group);

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

u_int64_t ViewInterface::getCheckPointDroppedAlerts() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointDroppedAlerts();

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

bool ViewInterface::hasSeenVLANTaggedPackets() const {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if(viewed_interfaces[s]->hasSeenVLANTaggedPackets())
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
			     ProtoStats *_discardedProbingStats, DSCPStats *_dscpStats,
			     SyslogStats *_syslogStats) const {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    viewed_interfaces[s]->sumStats(_tcpFlowStats, _ethStats, _localStats, _ndpiStats, _pktStats, _tcpPacketStats, _discardedProbingStats, _dscpStats, _syslogStats);
}

/* **************************************************** */

Flow* ViewInterface::findFlowByTuple(VLANid vlan_id,
				     u_int16_t observation_point_id,
				     IpAddress *src_ip,  IpAddress *dst_ip,
				     u_int16_t src_port, u_int16_t dst_port,
				     u_int8_t l4_proto,
				     AddressTree *allowed_hosts) const {
  Flow *f = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((f = (Flow*)viewed_interfaces[s]->findFlowByTuple(vlan_id, observation_point_id,
							 src_ip, dst_ip, src_port, dst_port, l4_proto, allowed_hosts)))
      break;
  }

  return(f);
}

/* **************************************************** */

void ViewInterface::viewed_flows_walker(Flow *f, const struct timeval *tv) {
  NetworkStats *network_stats;
  PartializableFlowTrafficStats partials;
  bool first_partial; /* Whether this is the first time the view is visiting this flow */
  const IpAddress *cli_ip = f->get_cli_ip_addr(), *srv_ip = f->get_srv_ip_addr();

  if(f->get_last_seen() > getTimeLastPktRcvd())
    setTimeLastPktRcvd(f->get_last_seen());

  /* NOTE: partials are calculated as a delta between the current and the past traffic.
   * When the hash tables are full and hosts cannot be allocated during the
   * first iteration of this method on the flow (when first_partial is true),
   * such stats on the hosts will be lost.
   */
  if(f->get_partial_traffic_stats_view(&partials, &first_partial)) {
    if(!cli_ip || !srv_ip)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to get flow hosts. Out of memory? Expect issues.");

    if(cli_ip && srv_ip) {
      Host *cli_host = NULL, *srv_host = NULL;

      /* Important: findFlowHosts can allocate new hosts. The first_partial condition
       * is used to call `incNumFlows` and `incUses` on the hosts below, so it is essential that
       * findFlowHosts is called only when first_partial is true. */
      if(first_partial) {
	findFlowHosts(f->get_vlan_id(), f->get_observation_point_id(),
		      NULL /* no src mac yet */, (IpAddress*)cli_ip, &cli_host,
		      NULL /* no dst mac yet */, (IpAddress*)srv_ip, &srv_host);

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
	/*
	  For view interfaces, service and periodicity maps need to be updated there,
	  only the first time a flow is seen.
	 */
	updateFlowPeriodicity(f);
	updateServiceMap(f);
#endif
      } else {
	/* The unsafe pointers can be used here as ViewInterface::viewed_flows_walker is
	 * called synchronously with the ViewInterface purgeIdle. This also saves some
	 * unnecessary hash table lookup time. */
	cli_host = f->getViewSharedClient();
	srv_host = f->getViewSharedServer();
      }

      f->hosts_periodic_stats_update(this, cli_host, srv_host, &partials, first_partial, tv);

      if(cli_host) {
	if(first_partial) {
	  cli_host->incNumFlows(f->get_last_seen(), true), cli_host->incUses();
	  network_stats = cli_host->getNetworkStats(cli_host->get_local_network_id());
	  if(network_stats) network_stats->incNumFlows(f->get_last_seen(), true);
	  if(f->getViewInterfaceFlowStats()) f->getViewInterfaceFlowStats()->setClientHost(cli_host);
	}
      }

      if(srv_host) {
	if(first_partial) {
	  srv_host->incUses(), srv_host->incNumFlows(f->get_last_seen(), false);
	  network_stats = srv_host->getNetworkStats(srv_host->get_local_network_id());
	  if(network_stats) network_stats->incNumFlows(f->get_last_seen(), false);
	  if(f->getViewInterfaceFlowStats()) f->getViewInterfaceFlowStats()->setServerHost(srv_host);
	}
      }

      /* Score increments are performed here periodically for view interfaces */
      for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++) {
	ScoreCategory score_category = (ScoreCategory)i;
	u_int16_t cli_score_val = partials.get_cli_score(score_category),
	  srv_score_val = partials.get_srv_score(score_category);

	if(cli_score_val && cli_host)
	  cli_host->incScoreValue(cli_score_val, score_category, true /* as client */);

	if(srv_score_val && srv_host)
	  srv_host->incScoreValue(srv_score_val, score_category, false /* as server */);
      }

      if(partials.get_is_flow_alerted()) {
	if(cli_host) cli_host->incNumAlertedFlows(true /* As client */),  cli_host->incTotalAlerts();
	if(srv_host) srv_host->incNumAlertedFlows(false /* As server */), srv_host->incTotalAlerts();
      }

      incStats(true /* ingressPacket */,
	       tv->tv_sec, cli_ip && cli_ip->isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	       f->getStatsProtocol(), f->get_protocol_category(),
	       f->get_protocol(),
	       partials.get_srv2cli_bytes() + partials.get_cli2srv_bytes(),
	       partials.get_srv2cli_packets() + partials.get_cli2srv_packets());
    }
  }
}

/* **************************************************** */

bool ViewInterface::isSampledTraffic() const {
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    if(viewed_interfaces[s]->isSampledTraffic()) return true;

  return false;
}

/* **************************************************** */

void ViewInterface::flowPollLoop() {
  while(!ntop->getGlobals()->isShutdownRequested()) {
    while(idle()) sleep(1);

    u_int64_t num = viewDequeue(MAX_VIEW_INTERFACE_QUEUE_LEN);

    purgeIdle(time(NULL));

    if(num == 0)
      _usleep(100);
  }
}

/* **************************************************** */

void ViewInterface::dumpFlowLoop() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Started flow dump loop on View interface %s [id: %u]...",
			       get_description(), get_id());

  /* Wait until it starts up */
  while(!isRunning()) _usleep(10000);

  /* Now operational */
  while(isRunning()) {
    u_int64_t n = 0;

    /*
      Dequeue flows for dump. Use an limited budget also for idle flows, even if they're high-priority.
      This is to guarantee idle flows are dequeued from all viewed interfaces and to prevent a single
      viewed interface to starve all the others.
    */
    for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
      n += viewed_interfaces[s]->dequeueFlowsForDump(128 /* Limited budget for idle flows to */,
						     32 /* Limited budged for active flows */);

    if(n == 0)
      _usleep(100);
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow dump thread completed for %s", get_name());
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

/* **************************************************** */

void ViewInterface::lua_queues_stats(lua_State* vm) {
  for(int i = 0; i < num_viewed_interfaces; i++)
    viewed_interfaces_queues[i]->lua(vm);
}
