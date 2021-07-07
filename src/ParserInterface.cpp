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

#ifndef HAVE_NEDGE

/* **************************************************** */

ParserInterface::ParserInterface(const char *endpoint, const char *custom_interface_type) : NetworkInterface(endpoint, custom_interface_type) {
  num_companion_interfaces = 0;
  companion_interfaces = new (std::nothrow) NetworkInterface*[MAX_NUM_COMPANION_INTERFACES]();
}

/* **************************************************** */

ParserInterface::~ParserInterface() {
  if(companion_interfaces)
    delete []companion_interfaces;
}

/* **************************************************** */

bool ParserInterface::processFlow(ParsedFlow *zflow) {
  bool src2dst_direction, new_flow;
  Flow *flow;
  time_t now;
  bpf_timeval now_tv = { 0 };
  Mac *srcMac = NULL, *dstMac = NULL;
  IpAddress srcIP, dstIP;
  now = time(NULL);
  now_tv.tv_sec = now;

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s()", __FUNCTION__);
  
  if(unlikely(ntop->getPrefs()->get_num_simulated_ips())) {
    u_int32_t num_sim_ips = ntop->getPrefs()->get_num_simulated_ips();
    u_int32_t base_ip = 167772161; /* 10.0.0.1 */

    zflow->src_ip.set(ntohl(base_ip + rand() % num_sim_ips));
    zflow->dst_ip.set(ntohl(base_ip + rand() % num_sim_ips));
    zflow->vlan_id = 0;
  }

  if(discardProbingTraffic()) {
    if(isProbingFlow(zflow)) {
      discardedProbingStats.inc(zflow->pkt_sampling_rate * (zflow->in_pkts + zflow->out_pkts),
				zflow->pkt_sampling_rate * (zflow->in_bytes + zflow->out_bytes));
      return false;
    }
  }

  if(!isSubInterface()) {
    bool processed = false;

    /* Deliver eBPF info to companion queues */
    if(zflow->process_info_set || 
       zflow->container_info_set || 
       zflow->tcp_info_set ||
       zflow->external_alert ||
       zflow->getAdditionalFieldsJSON()) {
      deliverFlowToCompanions(zflow);
    }

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    /* Custom disaggregation */
    if(sub_interfaces && sub_interfaces->getNumSubInterfaces() > 0) {
      processed = sub_interfaces->processFlow(zflow);
    }
#endif
#endif
    if(!processed && flowHashingMode != flowhashing_none) {
      NetworkInterface *vIface = NULL, *vIfaceEgress = NULL;

      switch(flowHashingMode) {
      case flowhashing_probe_ip:
        vIface = getDynInterface((u_int64_t)zflow->device_ip, true);
        break;

      case flowhashing_iface_idx:
        if(flowHashingIgnoredInterfaces.find((u_int64_t)zflow->outIndex) == flowHashingIgnoredInterfaces.end())
	  vIfaceEgress = getDynInterface((u_int64_t)zflow->outIndex, true);
        /* No break HERE, want to get two interfaces, one for the ingress
           and one for the egress. */

      case flowhashing_ingress_iface_idx:
        if(flowHashingIgnoredInterfaces.find((u_int64_t)zflow->inIndex) == flowHashingIgnoredInterfaces.end())
	  vIface = getDynInterface((u_int64_t)zflow->inIndex, true);
        break;

      case flowhashing_probe_ip_and_ingress_iface_idx:
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "[IP: %u][inIndex: %u]", zflow->device_ip, zflow->inIndex);
	vIface = getDynInterface((((u_int64_t)zflow->device_ip) << 32) + zflow->inIndex, true);
      break;
      
      case flowhashing_vrfid:
        vIface = getDynInterface((u_int64_t)zflow->vrfId, true);
        break;

      case flowhashing_vlan:
        vIface = getDynInterface((u_int64_t)zflow->vlan_id, true);
        break;

      default:
        break;
      }

      if(vIface) {
        ParserInterface *vPIface = dynamic_cast<ParserInterface*>(vIface);
        vPIface->processFlow(zflow);
      }

      if(vIfaceEgress) {
        ParserInterface *vPIface = dynamic_cast<ParserInterface*>(vIfaceEgress);
        vPIface->processFlow(zflow);
      }

      processed = true;
    }

    if(processed && !showDynamicInterfaceTraffic()) {
      return true;
    }
  }

  if(!ntop->getPrefs()->do_ignore_macs()) {
    srcMac = getMac((u_int8_t*)zflow->src_mac, true /* Create if missing */, true /* Inline call */);
    dstMac = getMac((u_int8_t*)zflow->dst_mac, true /* Create if missing */, true /* Inline call */);
  }

  srcIP.set(&zflow->src_ip), dstIP.set(&zflow->dst_ip);

  PROFILING_SECTION_ENTER("NetworkInterface::processFlow: getFlow", 0);

  /* Updating Flow */
  flow = getFlow(srcMac, dstMac,
		 zflow->vlan_id, zflow->observationPointId,
		 zflow->device_ip,
		 zflow->inIndex, zflow->outIndex,
		 NULL /* ICMPinfo */,
		 &srcIP, &dstIP,
		 zflow->src_port, zflow->dst_port,
		 zflow->l4_proto, &src2dst_direction,
		 zflow->first_switched,
		 zflow->last_switched,
		 0, &new_flow, true);

  PROFILING_SECTION_EXIT(0);

  if(flow == NULL)
    return false;  

  if(zflow->absolute_packet_octet_counters) {
    /* Ajdust bytes and packets counters if the zflow update contains absolute values.

       As flows may arrive out of sequence, special care is needed to avoid counting absolute values multiple times.

       http://www.cisco.com/c/en/us/td/docs/security/asa/special/netflow/guide/asa_netflow.html#pgfId-1331296
       Different events in the life of a flow may be issued in separate NetFlow packets and may arrive out-of-order
       at the collector. For example, the packet containing a flow teardown event may reach the collector before the packet
       containing a flow creation event. As a result, it is important that collector applications use the Event Time field
       to correlate events.
    */

    u_int64_t in_cur_pkts = src2dst_direction ? flow->get_packets_cli2srv() : flow->get_packets_srv2cli(),
      in_cur_bytes = src2dst_direction ? flow->get_bytes_cli2srv() : flow->get_bytes_srv2cli();
    u_int64_t out_cur_pkts = src2dst_direction ? flow->get_packets_srv2cli() : flow->get_packets_cli2srv(),
      out_cur_bytes = src2dst_direction ? flow->get_bytes_srv2cli() : flow->get_bytes_cli2srv();
    bool out_of_sequence = false;

    if(zflow->in_pkts) {
      if(zflow->in_pkts >= in_cur_pkts) zflow->in_pkts -= in_cur_pkts;
      else zflow->in_pkts = 0, out_of_sequence = true;
    }

    if(zflow->in_bytes) {
      if(zflow->in_bytes >= in_cur_bytes) zflow->in_bytes -= in_cur_bytes;
      else zflow->in_bytes = 0, out_of_sequence = true;
    }

    if(zflow->out_pkts) {
      if(zflow->out_pkts >= out_cur_pkts) zflow->out_pkts -= out_cur_pkts;
      else zflow->out_pkts = 0, out_of_sequence = true;
    }

    if(zflow->out_bytes) {
      if(zflow->out_bytes >= out_cur_bytes) zflow->out_bytes -= out_cur_bytes;
      else zflow->out_bytes = 0, out_of_sequence = true;
    }

    if(out_of_sequence) {
#ifdef ABSOLUTE_COUNTERS_DEBUG
      char flowbuf[265];
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "A flow received an update with absolute values smaller than the current values. "
				   "[in_bytes: %u][in_cur_bytes: %u][out_bytes: %u][out_cur_bytes: %u]"
				   "[in_pkts: %u][in_cur_pkts: %u][out_pkts: %u][out_cur_pkts: %u]\n"
				   "%s",
				   zflow->in_bytes, in_cur_bytes, zflow->out_bytes, out_cur_bytes,
				   zflow->in_pkts, in_cur_pkts, zflow->out_pkts, out_cur_pkts,
				   flow->print(flowbuf, sizeof(flowbuf)));
#endif
    }
  }

  if(zflow->tcp.clientNwLatency.tv_sec || zflow->tcp.clientNwLatency.tv_usec)
    flow->setFlowNwLatency(&zflow->tcp.clientNwLatency, src2dst_direction);

  if(zflow->tcp.serverNwLatency.tv_sec || zflow->tcp.serverNwLatency.tv_usec)
    flow->setFlowNwLatency(&zflow->tcp.serverNwLatency, !src2dst_direction);

  if(zflow->tcp.in_window)  flow->setFlowTcpWindow(zflow->tcp.in_window, src2dst_direction);
  if(zflow->tcp.out_window) flow->setFlowTcpWindow(zflow->tcp.out_window, !src2dst_direction);

  if(zflow->flow_verdict == 2 /* DROP */) flow->setDropVerdict();

  flow->setRisk(zflow->ndpi_flow_risk_bitmap);
  flow->setTOS(zflow->src_tos, true), flow->setTOS(zflow->dst_tos, false);
  flow->setRtt();

  if(src2dst_direction)
    flow->setFlowApplLatency(zflow->tcp.applLatencyMsec);

  /* Update process and container info */
  if(zflow->hasParsedeBPF()) {
    flow->setParsedeBPFInfo(zflow,
			    src2dst_direction /* FIX: direction also depends on the type of event. */);
    /* Now refresh the flow last seen so it will stay active as long as we keep receiving updates */
    flow->updateSeen();
  }

  flow->setFlowDevice(zflow->device_ip, zflow->observationPointId,
		      src2dst_direction ? zflow->inIndex  : zflow->outIndex,
		      src2dst_direction ? zflow->outIndex : zflow->inIndex);

#ifdef MAC_DEBUG
  char bufm1[32], bufm2[32];
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
      "Processing Flow [src mac: %s][dst mac: %s][src2dst: %i]",
      Utils::formatMac(srcMac->get_mac(), bufm1, sizeof(bufm1)),
      Utils::formatMac(dstMac->get_mac(), bufm2, sizeof(bufm2)),
      (src2dst_direction) ? 1 : 0);
#endif

  /* Update Mac stats
     Note: do not use src2dst_direction to inc the stats as
     in_bytes/in_pkts and out_bytes/out_pkts are already relative to the current
     source mac (srcMac) and destination mac (dstMac)
  */
  if(likely(srcMac != NULL)) {
    srcMac->incSentStats(getTimeLastPktRcvd(), zflow->pkt_sampling_rate * zflow->in_pkts,
			 zflow->pkt_sampling_rate * zflow->in_bytes);
    srcMac->incRcvdStats(getTimeLastPktRcvd(), zflow->pkt_sampling_rate * zflow->out_pkts,
			 zflow->pkt_sampling_rate * zflow->out_bytes);

    srcMac->setSourceMac();
  }

  if(likely(dstMac != NULL)) {
    dstMac->incSentStats(getTimeLastPktRcvd(), zflow->pkt_sampling_rate * zflow->out_pkts,
			 zflow->pkt_sampling_rate * zflow->out_bytes);
    dstMac->incRcvdStats(getTimeLastPktRcvd(), zflow->pkt_sampling_rate * zflow->in_pkts,
			 zflow->pkt_sampling_rate * zflow->in_bytes);
  }

  if(zflow->observationPointId != 0) 
    incObservationPointIdFlows(zflow->observationPointId,
			       zflow->pkt_sampling_rate * (zflow->in_bytes + zflow->out_bytes));      

  if(zflow->l4_proto == IPPROTO_TCP) {
    if(zflow->tcp.client_tcp_flags || zflow->tcp.server_tcp_flags) {
      /* There's a breadown between client and server TCP flags */
      if(zflow->tcp.client_tcp_flags)
	flow->updateTcpFlags(&now_tv, zflow->tcp.client_tcp_flags, src2dst_direction);

      if(zflow->tcp.server_tcp_flags)
	flow->updateTcpFlags(&now_tv, zflow->tcp.server_tcp_flags, !src2dst_direction);
      
      if(zflow->tcp.tcp_flags
	 && (zflow->tcp.client_tcp_flags == 0)
	 && (zflow->tcp.server_tcp_flags == 0)) {
	/* TCP flags are cumulative and set only if client/server flags are zero */
	flow->updateTcpFlags(&now_tv, zflow->tcp.tcp_flags, src2dst_direction);
      }
    }

    flow->updateTcpSeqIssues(zflow);

    Flow::incTcpBadStats(true,
			 flow->get_cli_host(), flow->get_srv_host(),
			 this,
			 zflow->tcp.ooo_in_pkts, zflow->tcp.retr_in_pkts,
			 zflow->tcp.lost_in_pkts, 0 /* TODO: add keepalive */);
    Flow::incTcpBadStats(false,
			 flow->get_cli_host(), flow->get_srv_host(),
			 this,
			 zflow->tcp.ooo_out_pkts, zflow->tcp.retr_out_pkts,
			 zflow->tcp.lost_out_pkts, 0 /* TODO: add keepalive */);
  }

  flow->addFlowStats(new_flow,
		     src2dst_direction,
		     zflow->pkt_sampling_rate*zflow->in_pkts,
		     zflow->pkt_sampling_rate*zflow->in_bytes, 0,
		     zflow->pkt_sampling_rate*zflow->out_pkts,
		     zflow->pkt_sampling_rate*zflow->out_bytes, 0,
		     zflow->pkt_sampling_rate*zflow->in_fragments,
		     zflow->pkt_sampling_rate*zflow->out_fragments,
		     zflow->first_switched,
		     zflow->last_switched);

  if(!flow->isDetectionCompleted()) {
    ndpi_protocol p = Flow::ndpiUnknownProtocol;
    ndpi_protocol guessed_protocol = Flow::ndpiUnknownProtocol;

    p.app_protocol = zflow->l7_proto.app_protocol;
    p.master_protocol = zflow->l7_proto.master_protocol;
    p.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;

    /* First, there's an attempt to guess the protocol so that custom protocols
       defined in ntopng will still be applied to the protocols detected by nprobe. */
    guessed_protocol = ndpi_guess_undetected_protocol(get_ndpi_struct(),
						      flow->get_ndpi_flow(),
						      flow->get_protocol(),
						      ntohl(flow->get_cli_ip_addr()->get_ipv4()),
						      (flow->get_cli_port()),
						      ntohl(flow->get_srv_ip_addr()->get_ipv4()),
						      (flow->get_srv_port()));

    if (
	/* If nprobe acts is in collector-passthrough mode L7_PROTO is not present,
	   using the protocol guess on the ntopng side is desirable in this case */
	(zflow->l7_proto.app_protocol    == NDPI_PROTOCOL_UNKNOWN &&
	 zflow->l7_proto.master_protocol == NDPI_PROTOCOL_UNKNOWN)
	||
	/* If the protocol is greater than NDPI_MAX_SUPPORTED_PROTOCOLS, it means it is
	   a custom protocol so the application protocol received from nprobe can be
	   overridden */
	(guessed_protocol.app_protocol >= NDPI_MAX_SUPPORTED_PROTOCOLS)
	)
      p = guessed_protocol;

    if(zflow->hasParsedeBPF()) {
      /* nProbe Agent does not perform nDPI detection*/
      p.master_protocol = guessed_protocol.master_protocol;
      p.app_protocol = guessed_protocol.app_protocol;
    }

    /* Now, depending on the q and on the zflow, there's an additional check
       to possibly override the category, according to the rules specified
       in ntopng */
    flow->fillZmqFlowCategory(zflow, &p);

    /* Here everything is setup and it is possible to set the actual protocol to the flow */
    flow->setDetectedProtocol(p);
  }

#ifdef NTOPNG_PRO
  if(zflow->device_ip) {
    // if(ntop->getPrefs()->is_flow_device_port_rrd_creation_enabled() && ntop->getPro()->has_valid_license()) {
    if(!flow_interfaces_stats)
      flow_interfaces_stats = new (std::nothrow) FlowInterfacesStats();

    if(flow_interfaces_stats) {
      flow_interfaces_stats->incStats(now,
				      zflow->device_ip, zflow->inIndex,
				      flow->getStatsProtocol(),
				      zflow->pkt_sampling_rate * zflow->out_pkts, zflow->pkt_sampling_rate * zflow->out_bytes,
				      zflow->pkt_sampling_rate * zflow->in_pkts, zflow->pkt_sampling_rate * zflow->in_bytes);
      /* If the SNMP device is actually an host with an SNMP agent, then traffic can enter and leave it
	 from the same interface (think to a management interface). For this reason it is important to check
	 the outIndex and increase its counters only if it is different from inIndex to avoid double counting. */
      if(zflow->outIndex != zflow->inIndex)
	flow_interfaces_stats->incStats(now,
					zflow->device_ip, zflow->outIndex,
					flow->getStatsProtocol(),
					zflow->pkt_sampling_rate * zflow->in_pkts, zflow->pkt_sampling_rate * zflow->in_bytes,
					zflow->pkt_sampling_rate * zflow->out_pkts, zflow->pkt_sampling_rate * zflow->out_bytes);
    }
  }
#endif

  flow->setJSONInfo(zflow->getAdditionalFieldsJSON());
  flow->setTLVInfo(zflow->getAdditionalFieldsTLV());

  flow->updateInterfaceLocalStats(src2dst_direction,
				  zflow->pkt_sampling_rate*(zflow->in_pkts+zflow->out_pkts),
				  zflow->pkt_sampling_rate*(zflow->in_bytes+zflow->out_bytes));

  if(flow->isDNS())
    flow->updateDNS(zflow);

  if(flow->isHTTP())
    flow->updateHTTP(zflow);

  if(zflow->tls_server_name) {
    flow->setServerName(zflow->tls_server_name);
    zflow->tls_server_name = NULL;
  }

  if(zflow->bittorrent_hash) {
    flow->setBTHash(zflow->bittorrent_hash);
    zflow->bittorrent_hash = NULL;
  }

  if(zflow->vrfId) flow->setVRFid(zflow->vrfId);

  if(zflow->src_as) flow->setSrcAS(zflow->src_as);
  if(zflow->dst_as) flow->setDstAS(zflow->dst_as);

  if(zflow->prev_adjacent_as) flow->setPrevAdjacentAS(zflow->prev_adjacent_as);
  if(zflow->next_adjacent_as) flow->setNextAdjacentAS(zflow->next_adjacent_as);

  if(zflow->ja3c_hash) flow->updateJA3C(zflow->ja3c_hash);
  if(zflow->ja3s_hash) flow->updateJA3S(zflow->ja3s_hash);  
  
#ifdef NTOPNG_PRO
  if(zflow->custom_app.pen) {
    flow->setCustomApp(zflow->custom_app);

    if(custom_app_stats || (custom_app_stats = new(std::nothrow) CustomAppStats(this))) {
      custom_app_stats->incStats(zflow->custom_app.remapped_app_id,
				 zflow->pkt_sampling_rate * (zflow->in_bytes + zflow->out_bytes));
    }
  }
#endif

  if(zflow->external_alert) {
    enum json_tokener_error jerr = json_tokener_success;
    json_object *o = json_tokener_parse_verbose(zflow->external_alert, &jerr);
    if(o) flow->setExternalAlert(o);
  }

  flow->updateSuspiciousDGADomain();

  /* Do not put incStats before guessing the flow protocol */
  if(zflow->direction == UNKNOWN_FLOW_DIRECTION)
    incStats(true /* ingressPacket */,
	     now, srcIP.isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	     flow->getStatsProtocol(),
	     flow->get_protocol_category(),
	     zflow->l4_proto,
	     zflow->pkt_sampling_rate*(zflow->in_bytes + zflow->out_bytes),
	     zflow->pkt_sampling_rate*(zflow->in_pkts + zflow->out_pkts));
  else {
    u_int16_t eth_type = srcIP.isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6;

#if 0
    ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%d) [in: %u][out: %u]",
				 (zflow->direction == 0 /* RX */) ? "RX" : "TX",
				 zflow->direction,
				 zflow->in_pkts, zflow->out_pkts);
#endif
    
    if(zflow->direction == 0 /* RX */) {
      incStats(true /* ingress */,
	       now, eth_type,
	       flow->getStatsProtocol(),
	       flow->get_protocol_category(),
	       zflow->l4_proto,
	       zflow->pkt_sampling_rate*zflow->out_bytes,
	       zflow->pkt_sampling_rate*zflow->out_pkts);

      if(zflow->out_bytes)
	incStats(false /* egress */,
		 now, eth_type,
		 flow->getStatsProtocol(),
		 flow->get_protocol_category(),
		 zflow->l4_proto,
		 zflow->pkt_sampling_rate*zflow->in_bytes,
		 zflow->pkt_sampling_rate*zflow->in_pkts);
    } else {
      incStats(false /* egress */,
	       now, eth_type,
	       flow->getStatsProtocol(),
	       flow->get_protocol_category(),
	       zflow->l4_proto,
	       zflow->pkt_sampling_rate*zflow->in_bytes,
	       zflow->pkt_sampling_rate*zflow->in_pkts);

      if(zflow->out_bytes)
	incStats(true /* ingress */,
		 now, eth_type,
		 flow->getStatsProtocol(),
		 flow->get_protocol_category(),
		 zflow->l4_proto,
		 zflow->pkt_sampling_rate*zflow->out_bytes,
		 zflow->pkt_sampling_rate*zflow->out_pkts);
    }
  }
  
#ifdef NTOPNG_PRO
  /* Check if direct flow dump is enabled */
  if(ntop->getPrefs()->do_dump_flows_direct() && (
     ntop->getPrefs()->is_flows_dump_enabled()
#ifndef HAVE_NEDGE
     || ntop->get_export_interface()
#endif
     )) {
    /* Dump flow */
    flow->dump(zflow->last_switched, true /* last dump before free */);
  }
#endif

  /* purge is actually performed at most one time every FLOW_PURGE_FREQUENCY */
  // purgeIdle(zflow->last_switched);

  return true;
}

/* **************************************************** */

bool ParserInterface::isProbingFlow(const ParsedFlow *zflow) {
  switch(zflow->l4_proto) {
  case IPPROTO_TCP:
    {
      /* zflow->tcp.tcp_flags are, according to the specs, the 'Cumulative of all the TCP flags seen for this flow'.
         Hence, for bi-directional flows, they are the locigal OR of client and server flags whereas for mono-directional
         flows they are the logical OR of client-to-server flags. */

      /* A SYN only seen by the client is very likely a scan. Any established TCP connection involves at least
         an ACK from both parties as this is also part of the initial three-way-handshake. */
      if((zflow->tcp.client_tcp_flags & TCP_SCAN_MASK) == TH_SYN
	 || (zflow->tcp.tcp_flags & TCP_SCAN_MASK) == TH_SYN)
	return true;

      /* A client SYN+RST can be found when a scan finds the destination port OPEN. For example,
         using nmap, a scan which finds destination port 22 open involves the following 3 packets:
         1. client sends SYN to server port 22
         2. server responds with SYN+ACK as its port 22 is open and it is willing to establish the connection
         3. client immediately closes the connection with RST

         See: https://nmap.org/book/synscan.html */
      if((zflow->tcp.client_tcp_flags & TCP_SCAN_MASK) == (TH_SYN | TH_RST)
	 || (zflow->tcp.tcp_flags & TCP_SCAN_MASK) == (TH_SYN | TH_RST))
	return true;

      /* A server RST+ACK can be found when a scan finds the destination port CLOSED. For example,
         using nmap, a scan which finds destination port 22 closed involves the following 2 packets:
         1. client sends SYN to server port 22
         2. server responds with SYN+RST because either its port is closed or is not willing to establish the connection */
      if((zflow->tcp.server_tcp_flags & TCP_SCAN_MASK) == (TH_RST | TH_ACK)
	 || (zflow->tcp.tcp_flags & TCP_SCAN_MASK) == (TH_RST | TH_ACK))
	return true;

      /* When only a RST is seen from the server, it means no data has been exchanged and the server is not
         willing to communicate with the client which is very likely a scanner */
      if((zflow->tcp.server_tcp_flags & TCP_SCAN_MASK) == TH_RST
	 || (zflow->tcp.tcp_flags &TCP_SCAN_MASK) == TH_RST)
	return true;
    }
    break;
  case IPPROTO_UDP:
    {
      if(zflow->in_pkts + zflow->out_pkts <= 1)
	return true;
    }
    break;
  default:
    break;
  }

  return false;
}

/* **************************************************** */

void ParserInterface::reloadCompanions() {
  char key[CONST_MAX_LEN_REDIS_KEY];
  int num_companions;
  char **companions = NULL;
  bool found;

  if(!ntop->getRedis()) return;

  snprintf(key, sizeof(key), CONST_IFACE_COMPANIONS_SET, get_id());
  num_companions = ntop->getRedis()->smembers(key, &companions);

  companions_lock.lock(__FILE__, __LINE__);

  if(num_companion_interfaces > 0) {
    /* Check and possibly remove old companions */
    for(int i = 0; i < MAX_NUM_COMPANION_INTERFACES; i++) {
      if(!companion_interfaces[i]) continue;

      found = false;
      for(int j = 0; j < num_companions; j++) {
	if(companion_interfaces[i]->get_id() == atoi(companions[j])) {
	  found = true;
	  break;
	}
      }

      if(!found) {
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Removed companion interface [interface: %s][companion: %s]",
	// 			     get_name(), companion_interfaces[i]->get_name());
	companion_interfaces[i] = NULL;
	num_companion_interfaces--;
      }
    }
  }

  if(num_companions > 0) {
    /* Check and possibly add new companions */
    for(int i = 0; i < num_companions; i++) {
      found = false;
      for(int j = 0; j < MAX_NUM_COMPANION_INTERFACES; j++) {
	if(companion_interfaces[j] && companion_interfaces[j]->get_id() == atoi(companions[i])) {
	  found = true;
	  break;
	}
      }

      if(!found) {
	if(num_companion_interfaces < MAX_NUM_COMPANION_INTERFACES) {
	  for(int j = 0; j < MAX_NUM_COMPANION_INTERFACES; j++) {
	    if(!companion_interfaces[j]) {
	      companion_interfaces[j] = ntop->getInterfaceById(atoi(companions[i]));

	      if(companion_interfaces[j]) {
		num_companion_interfaces++;
		// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Added new companion interface [interface: %s][companion: %s]",
		// 			     get_name(), companion_interfaces[j]->get_name());
	      }

	      break;
	    }
	  }
	} else
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many companion interfaces defined [interface: %s]", get_name());
      }

      free(companions[i]);
    }
  }

  companions_lock.unlock(__FILE__, __LINE__);

  if(companions)
    free(companions);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Companion interface reloaded [interface: %s][companion: %s]",
  // 			       get_name(), companion_interface ? companion_interface->get_name() : "NULL");
}

/* **************************************************** */

void ParserInterface::deliverFlowToCompanions(ParsedFlow * const flow) {
  if(num_companion_interfaces > 0) {
    NetworkInterface *flow_interface = flow->ifname ? ntop->getNetworkInterface(flow->ifname) : NULL;

    for(int i = 0; i < MAX_NUM_COMPANION_INTERFACES; i++) {
      NetworkInterface *cur_companion = companion_interfaces[i];

      if(!cur_companion) continue;

      if(cur_companion->isTrafficMirrored())
	cur_companion->enqueueFlowToCompanion(flow, true /* Skip loopback traffic */);
      else if(cur_companion == flow_interface)
	cur_companion->enqueueFlowToCompanion(flow, false /* do NOT skip loopback traffic */);
    }
  }
}

#endif
