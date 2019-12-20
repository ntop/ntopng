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

void ParserInterface::processFlow(ParsedFlow *zflow) {
  bool src2dst_direction, new_flow;
  Flow *flow;
  ndpi_protocol p = Flow::ndpiUnknownProtocol;
  time_t now = time(NULL);
  Mac *srcMac = NULL, *dstMac = NULL;
  IpAddress srcIP, dstIP;

  if(!isSubInterface()) {
    /* Deliver eBPF info to companion queues */
    if(zflow->process_info_set || 
       zflow->container_info_set || 
       zflow->tcp_info_set ||
       zflow->external_alert ||
       zflow->getAdditionalFieldsJSON()) {
      deliverFlowToCompanions(zflow);
    }

    if(flowHashingMode == flowhashing_none) {
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
      /* Custom disaggregation */
      if(sub_interfaces && sub_interfaces->getNumSubInterfaces() > 0) {
        bool processed = sub_interfaces->processFlow(zflow);
     
        if(processed && !showDynamicInterfaceTraffic()) 
          return;
      }
#endif
#endif
    } else {
      NetworkInterface *vIface = NULL, *vIfaceEgress = NULL;

      switch(flowHashingMode) {
      case flowhashing_probe_ip:
        vIface = getDynInterface((u_int32_t)zflow->deviceIP, true);
        break;

      case flowhashing_iface_idx:
        if(flowHashingIgnoredInterfaces.find((u_int32_t)zflow->outIndex) == flowHashingIgnoredInterfaces.end())
	  vIfaceEgress = getDynInterface((u_int32_t)zflow->outIndex, true);
        /* No break HERE, want to get two interfaces, one for the ingress
           and one for the egress. */

      case flowhashing_ingress_iface_idx:
        if(flowHashingIgnoredInterfaces.find((u_int32_t)zflow->inIndex) == flowHashingIgnoredInterfaces.end())
	  vIface = getDynInterface((u_int32_t)zflow->inIndex, true);
        break;

      case flowhashing_vrfid:
        vIface = getDynInterface((u_int32_t)zflow->vrfId, true);
        break;

      case flowhashing_vlan:
        vIface = getDynInterface((u_int32_t)zflow->vlan_id, true);
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

      if (!showDynamicInterfaceTraffic())
        return;
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
		 zflow->vlan_id,
		 zflow->deviceIP,
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
    return;

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

  /* Update flow device stats */
  if(!flow->setFlowDevice(zflow->deviceIP,
			  src2dst_direction ? zflow->inIndex  : zflow->outIndex,
			  src2dst_direction ? zflow->outIndex : zflow->inIndex)) {
    static bool flow_device_already_set = false;
    if(!flow_device_already_set) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "A flow has been seen from multiple exporters or from "
				   "multiple IN/OUT interfaces. Check exporters configuration.");
      flow_device_already_set = true;
    }
  }

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

  if(zflow->l4_proto == IPPROTO_TCP) {
    if(zflow->tcp.client_tcp_flags || zflow->tcp.server_tcp_flags) {
      /* There's a breadown between client and server TCP flags */
      if(zflow->tcp.client_tcp_flags)
	flow->setTcpFlags(zflow->tcp.client_tcp_flags, src2dst_direction);
      if(zflow->tcp.server_tcp_flags)
	flow->setTcpFlags(zflow->tcp.server_tcp_flags, !src2dst_direction);
    } else if(zflow->tcp.tcp_flags)
      /* TCP flags are cumulated client + server */
      flow->setTcpFlags(zflow->tcp.tcp_flags, src2dst_direction);

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

#ifdef NTOPNG_PRO
  if(zflow->deviceIP) {
    // if(ntop->getPrefs()->is_flow_device_port_rrd_creation_enabled() && ntop->getPro()->has_valid_license()) {
    if(!flow_interfaces_stats)
      flow_interfaces_stats = new FlowInterfacesStats();

    if(flow_interfaces_stats) {
      flow_interfaces_stats->incStats(now, zflow->deviceIP, zflow->inIndex,
				      zflow->out_bytes, zflow->in_bytes);
      /* If the SNMP device is actually an host with an SNMP agent, then traffic can enter and leave it
	 from the same interface (think to a management interface). For this reason it is important to check
	 the outIndex and increase its counters only if it is different from inIndex to avoid double counting. */
      if(zflow->outIndex != zflow->inIndex)
	flow_interfaces_stats->incStats(now, zflow->deviceIP, zflow->outIndex,
					zflow->in_bytes, zflow->out_bytes);
    }
  }
#endif

  flow->addFlowStats(src2dst_direction,
		     zflow->pkt_sampling_rate*zflow->in_pkts,
		     zflow->pkt_sampling_rate*zflow->in_bytes, 0,
		     zflow->pkt_sampling_rate*zflow->out_pkts,
		     zflow->pkt_sampling_rate*zflow->out_bytes, 0,
		     zflow->pkt_sampling_rate*zflow->in_fragments,
		     zflow->pkt_sampling_rate*zflow->out_fragments,
		     zflow->last_switched);

  p.app_protocol = zflow->l7_proto.app_protocol, p.master_protocol = zflow->l7_proto.master_protocol;
  p.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;

  if(!flow->isDetectionCompleted()) {
    ndpi_protocol guessed_protocol = Flow::ndpiUnknownProtocol;
    u_int8_t is_proto_user_defined;

    /* First, there's an attempt to guess the protocol so that custom protocols
       defined in ntopng will still be applied to the protocols detected by nprobe. */
    guessed_protocol.app_protocol = (int16_t)ndpi_guess_protocol_id(get_ndpi_struct(),
								   NULL, flow->get_protocol(),
								   flow->get_cli_port(),
								   flow->get_srv_port(),
								   &is_proto_user_defined);
    if(guessed_protocol.app_protocol >= NDPI_MAX_SUPPORTED_PROTOCOLS) {
      /* If the protocol is greater than NDPI_MAX_SUPPORTED_PROTOCOLS, it means it is
         a custom protocol so the application protocol received from nprobe can be
         overridden */
      p.app_protocol = guessed_protocol.app_protocol;
    }

    /* Now, depending on the q and on the zflow, there's an additional check
       to possibly override the category, according to the rules specified
       in ntopng */
    flow->fillZmqFlowCategory(zflow, &p);

    /* Here everything is setup and it is possible to set the actual protocol to the flow */
    flow->setDetectedProtocol(p, true);
  }

  flow->setJSONInfo(zflow->getAdditionalFieldsJSON());
  flow->setTLVInfo(zflow->getAdditionalFieldsTLV());

  flow->updateInterfaceLocalStats(src2dst_direction,
				  zflow->pkt_sampling_rate*(zflow->in_pkts+zflow->out_pkts),
				  zflow->pkt_sampling_rate*(zflow->in_bytes+zflow->out_bytes));

  if(zflow->dns_query) {
    flow->setDNSQuery(zflow->dns_query);
    zflow->dns_query = NULL;
  }
  flow->setDNSQueryType(zflow->dns_query_type);
  flow->setDNSRetCode(zflow->dns_ret_code);

  if(zflow->http_url) {
    flow->setHTTPURL(zflow->http_url);
    zflow->http_url = NULL;
  }

  if(zflow->http_site) {
    flow->setServerName(zflow->http_site);
    zflow->http_site = NULL;
  }

  if(zflow->http_method) {
    flow->setHTTPMethod(zflow->http_method);
    zflow->http_method = NULL;
  }

  flow->setHTTPRetCode(zflow->http_ret_code);

  if(zflow->tls_server_name) {
    flow->setServerName(zflow->tls_server_name);
    zflow->tls_server_name = NULL;
  }

  if(zflow->bittorrent_hash) {
    flow->setBTHash(zflow->bittorrent_hash);
    zflow->bittorrent_hash = NULL;
  }

  if(zflow->vrfId)      flow->setVRFid(zflow->vrfId);

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

  /* Do not put incStats before guessing the flow protocol */
  incStats(true /* ingressPacket */,
	   now, srcIP.isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	   flow->getStatsProtocol(),
	   flow->get_protocol_category(),
	   zflow->l4_proto,
	   zflow->pkt_sampling_rate*(zflow->in_bytes + zflow->out_bytes),
	   zflow->pkt_sampling_rate*(zflow->in_pkts + zflow->out_pkts),
	   24 /* 8 Preamble + 4 CRC + 12 IFG */ + 14 /* Ethernet header */);

  /* purge is actually performed at most one time every FLOW_PURGE_FREQUENCY */
  // purgeIdle(zflow->last_switched);
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
