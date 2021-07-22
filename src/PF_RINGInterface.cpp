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

#ifdef HAVE_PF_RING

#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

/* **************************************************** */

pfring *PF_RINGInterface::pfringSocketInit(const char *name) {
  u_int flags = ntop->getPrefs()->use_promiscuous() ? PF_RING_PROMISC : 0;
  pfring *handle;
  packet_direction direction;
  u_int32_t version;
  int rc;

  flags |= PF_RING_LONG_HEADER;
  flags |= PF_RING_DNA_SYMMETRIC_RSS;  /* Note that symmetric RSS is ignored by non-DNA drivers */
#ifdef PF_RING_DO_NOT_PARSE
  flags |= PF_RING_DO_NOT_PARSE;
#endif

  if(ntop->getPrefs()->are_ixia_timestamps_enabled())
    flags |= PF_RING_IXIA_TIMESTAMP;
  else if(ntop->getPrefs()->are_vss_apcon_timestamps_enabled())
    flags |= PF_RING_VSS_APCON_TIMESTAMP;

  if((handle = pfring_open(name, ntop->getGlobals()->getSnaplen(name), flags)) == NULL)
    return NULL;

  rc = pfring_version(handle, &version);

  rc = pfring_version(handle, &version);

  if (rc == -1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unexpected socket error: unable to read PF_RING version");
    exit(0);
  }

  if (version != RING_VERSION_NUM) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "PF_RING version mismatch (expected v.%d.%d.%d found v.%d.%d.%d)",
      (RING_VERSION_NUM & 0xFFFF0000) >> 16, (RING_VERSION_NUM & 0x0000FF00) >> 8, RING_VERSION_NUM & 0x000000FF,
      (version & 0xFFFF0000) >> 16, (version & 0x0000FF00) >> 8, version & 0x000000FF); 
    exit(0);
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from PF_RING v.%d.%d.%d interface %s...",
			       (version & 0xFFFF0000) >> 16, (version & 0x0000FF00) >> 8, version & 0x000000FF,
			       name);

  pfring_get_bound_device_address(handle, ifMac);
  pfring_set_poll_watermark(handle, 8);
  pfring_set_application_name(handle, (char*)"ntopng");

  if (ntop->getPrefs()->hasPF_RINGClusterID())
    pfring_set_cluster(handle, ntop->getPrefs()->getPF_RINGClusterID(), cluster_per_flow_5_tuple);
  else
    pfring_enable_rss_rehash(handle);
  
  switch(ntop->getPrefs()->getCaptureDirection()) {
  case PCAP_D_INOUT: direction = rx_and_tx_direction; break;
  case PCAP_D_IN:    direction = rx_only_direction;   break;
  case PCAP_D_OUT:   direction = tx_only_direction;   break;
  default:           direction = rx_and_tx_direction; break;
  }

  if(pfring_set_direction(handle, direction) != 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set packet capture direction on %s", name);
    if(strstr(name, "zc:") && direction != rx_only_direction)
      ntop->getTrace()->traceEvent(TRACE_WARNING, "ZC supports RX capture only, please use --capture-direction 1"); 
  }

  if(pfring_set_socket_mode(handle, recv_only_mode) != 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set socket mode on %s", name);
  
  memset(&last_pfring_stat, 0, sizeof(last_pfring_stat));

  /* 
   * We need to enable the ring here and not in packetPollLoop() as otherwise
   * with ZC we cannot allocate hugepages after we switched to nobody
   */
  pfring_enable_ring(handle);

  return handle;
}

/* **************************************************** */

PF_RINGInterface::PF_RINGInterface(const char *_name) : NetworkInterface(_name) {
  char name[MAX_INTERFACE_NAME_LEN];
  int err;

  num_pfring_handles = 0;
  pcap_datalink_type = DLT_EN10MB;
  dropped_packets = 0;

  strncpy(name, ifname, sizeof(name));
  name[sizeof(name) - 1] = '\0';

  if(strchr(name, ':') && strchr(name, ',')) { 
    char *item_name, *tmp;

    /* This looks like a list of ZC interfaces, aggregation need to be done here */
    item_name = strtok_r(name, ",", &tmp);
    while (item_name != NULL && num_pfring_handles < PF_RING_MAX_SOCKETS) {

      pfring_handle[num_pfring_handles] = pfringSocketInit(item_name);

      if(pfring_handle[num_pfring_handles] == NULL) {
        err = errno;
        throw err; 
      }
     
      num_pfring_handles++;

      item_name = strtok_r(NULL, ",", &tmp);
    }

  } else {

    if (ntop->getPrefs()->hasPF_RINGClusterID() && !strchr(name, ':')) {
      /* PF_RING cluster configured, cleaning up queue from the interface name */
      char *at = strchr(name, '@');
      if (at) *at = '\0';
    }

    pfring_handle[0] = pfringSocketInit(name);

    if(pfring_handle[0] == NULL) {
      err = errno;
      throw err; 
    }

    num_pfring_handles = 1;
  }
}

/* **************************************************** */

PF_RINGInterface::~PF_RINGInterface() {
  int i;

  shutdown();

  for (i = 0; i < num_pfring_handles; i++) {
    if(pfring_handle[i])
      pfring_close(pfring_handle[i]);
  }
}

/* **************************************************** */

void PF_RINGInterface::singlePacketPollLoop() {
  pfring  *pd = pfring_handle[0];
  u_int sleep_time, max_sleep = 1000, step_sleep = 100;
  u_char *buffer;
  struct pfring_pkthdr hdr;
  
  sleep_time = step_sleep;
  
  while(isRunning()) {
    if(pfring_recv(pd, &buffer, 0, &hdr, 0 /* wait_for_packet */) > 0) {
      try {
        u_int16_t p;
        Host *srcHost = NULL, *dstHost = NULL;
        Flow *flow = NULL;

        if(hdr.ts.tv_sec == 0) gettimeofday(&hdr.ts, NULL);
        dissectPacket(DUMMY_BRIDGE_INTERFACE_ID,
		      (hdr.extended_hdr.rx_direction == 1) ? 
		      true /* ingress */ : false /* egress */,
		      NULL, (const struct pcap_pkthdr *) &hdr, buffer,
		      &p, &srcHost, &dstHost, &flow);
	  sleep_time = step_sleep;
      } catch(std::bad_alloc& ba) {
        static bool oom_warning_sent = false;

        if(!oom_warning_sent) {
          ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
          oom_warning_sent = true;
        }
      }
    } else {
      if(sleep_time < max_sleep) sleep_time += step_sleep;
      _usleep(sleep_time);
      purgeIdle(time(NULL));
    }
  }
}

/* **************************************************** */

void PF_RINGInterface::multiPacketPollLoop() {
  u_char *buffer;
  struct pfring_pkthdr hdr;
  u_int sleep_time, max_sleep = 1000, step_sleep = 100;
  int rc, idx = 0;
 
  sleep_time = step_sleep;
  
  while(isRunning()) {
    rc = pfring_recv(pfring_handle[idx], &buffer, 0, &hdr, 0 /* wait_for_packet */);

    if(rc <= 0) {
      idx ^= 0x1;
      rc = pfring_recv(pfring_handle[idx], &buffer, 0, &hdr, 0 /* wait_for_packet */);
    }

    if(rc > 0) {
      try {
        u_int16_t p;
        Host *srcHost = NULL, *dstHost = NULL;
        Flow *flow = NULL;

        if(hdr.ts.tv_sec == 0) gettimeofday(&hdr.ts, NULL);
	dissectPacket(DUMMY_BRIDGE_INTERFACE_ID,
		      (idx == 0) /* Assuming 0 ingress, 1 egress (TAP) */,
		      NULL, (const struct pcap_pkthdr *) &hdr, buffer,
		      &p, &srcHost, &dstHost, &flow);
	sleep_time = step_sleep;
      } catch(std::bad_alloc& ba) {
	static bool oom_warning_sent = false;

	if(!oom_warning_sent) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	  oom_warning_sent = true;
	}
      }
    } else {
      if(sleep_time < max_sleep) sleep_time += step_sleep;
      _usleep(sleep_time);
      purgeIdle(time(NULL));
    }

    idx ^= 0x1;
  }
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  PF_RINGInterface *iface = (PF_RINGInterface *) ptr;
  
  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  while(iface->idle()) {
    if(ntop->getGlobals()->isShutdown()) return(NULL);
    iface->purgeIdle(time(NULL));
    sleep(1);
  }
  
  if(iface->get_num_pfring_handles() == 1)
    iface->singlePacketPollLoop();
  else
    iface->multiPacketPollLoop();  
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated packet polling for %s", 
			       iface->get_name());
  return(NULL);
}

/* **************************************************** */

void PF_RINGInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void PF_RINGInterface::shutdown() {
  for (int i = 0; i < num_pfring_handles; i++) {
    if(pfring_handle[i]) pfring_breakloop(pfring_handle[i]);
  }

  NetworkInterface::shutdown();
}

/* **************************************************** */

/* Note: getNumDroppedPackets is called inline from the GUI,
 * this creates issues when pfring_stats adds latency (e.g. with
 * Napatech streams), for this reason we are updating drop stats 
 * in a periodic housekeeping thread. */
void PF_RINGInterface::updatePacketsStats() {
  pfring_stat stats;
  u_int32_t dropped = 0;
  int i;

  for (i = 0; i < num_pfring_handles; i++) {
    if(pfring_stats(pfring_handle[i], &stats) >= 0) {
#if 0
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][Rcvd: %llu][Drops: %llu][DroppedByFilter: %u]",
				   ifname, stats.recv, stats.drop, stats.droppedbyfilter);
#endif
      dropped += stats.drop;
    }
  }

  dropped_packets = dropped;
}

/* **************************************************** */

u_int32_t PF_RINGInterface::getNumDroppedPackets() {
  return dropped_packets;
}

/* **************************************************** */

bool PF_RINGInterface::set_packet_filter(char *filter) {
  int i;

  for (i = 0; i < num_pfring_handles; i++) {
    if(pfring_set_bpf_filter(pfring_handle[i], filter) != 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set filter %s.\n", filter);
      return(false);
    }
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Packet capture filter set to \"%s\"", filter);

  return(true);
}

/* **************************************************** */

#endif /* HAVE_PF_RING */
