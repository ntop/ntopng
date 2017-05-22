/*
 *
 * (C) 2013-17 - ntop.org
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

PF_RINGInterface::PF_RINGInterface(const char *name) : NetworkInterface(name) {
  u_int flags = ntop->getPrefs()->use_promiscuous() ? PF_RING_PROMISC : 0;
  packet_direction direction;

  flags |= PF_RING_LONG_HEADER;
  flags |= PF_RING_DNA_SYMMETRIC_RSS;  /* Note that symmetric RSS is ignored by non-DNA drivers */
#ifdef PF_RING_DO_NOT_PARSE
  flags |= PF_RING_DO_NOT_PARSE;
#endif

  if(ntop->getPrefs()->are_ixia_timestamps_enabled())
    flags |= PF_RING_IXIA_TIMESTAMP;
  else if(ntop->getPrefs()->are_vss_apcon_timestamps_enabled())
    flags |= PF_RING_VSS_APCON_TIMESTAMP;

  if((pfring_handle = pfring_open(ifname, ntop->getGlobals()->getSnaplen(), flags)) == NULL) {
    throw 1;
  } else {
    u_int32_t version;

    pfring_version(pfring_handle, &version);
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from PF_RING v.%d.%d.%d interface %s...",
				 (version & 0xFFFF0000) >> 16, (version & 0x0000FF00) >> 8, version & 0x000000FF,
				 ifname);
  }

  pcap_datalink_type = DLT_EN10MB;

  pfring_set_direction(pfring_handle, rx_only_direction);
  pfring_set_poll_watermark(pfring_handle, 8);
  pfring_set_application_name(pfring_handle, (char*)"ntopng");
  pfring_enable_rss_rehash(pfring_handle);
  
  switch(ntop->getPrefs()->getCaptureDirection()) {
  case PCAP_D_INOUT: direction = rx_and_tx_direction; break;
  case PCAP_D_IN:    direction = rx_only_direction;   break;
  case PCAP_D_OUT:   direction = tx_only_direction;   break;
  }

  if(pfring_set_direction(pfring_handle, direction) != 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set packet capture direction");

  memset(&last_pfring_stat, 0, sizeof(last_pfring_stat));
}

/* **************************************************** */

PF_RINGInterface::~PF_RINGInterface() {
  shutdown();

  if(pfring_handle)
    pfring_close(pfring_handle);
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  PF_RINGInterface *iface = (PF_RINGInterface*)ptr;
  pfring  *pd = iface->get_pfring_handle();

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);
  pfring_enable_ring(pd);

  while(iface->idle()) { iface->purgeIdle(time(NULL)); sleep(1); }

  while(iface->isRunning()) {
    if(pfring_is_pkt_available(pd)) {
      u_char *buffer;
      struct pfring_pkthdr hdr;

      if(pfring_recv(pd, &buffer, 0, &hdr, 0 /* wait_for_packet */) > 0) {
	try {
	  u_int16_t p;
	  Host *srcHost = NULL, *dstHost = NULL;
	  Flow *flow = NULL;

	  if(hdr.ts.tv_sec == 0) gettimeofday(&hdr.ts, NULL);
	  iface->dissectPacket(0, (const struct pcap_pkthdr *) &hdr, buffer,
			       &p, &srcHost, &dstHost, &flow);
	} catch(std::bad_alloc& ba) {
	  static bool oom_warning_sent = false;

	  if(!oom_warning_sent) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	    oom_warning_sent = true;
	  }
	}
      }
    } else {
      usleep(1);
      iface->purgeIdle(time(NULL));
    }
  }

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
  void *res;

  if(running) {
    NetworkInterface::shutdown();
    if(pfring_handle) pfring_breakloop(pfring_handle);
    pthread_join(pollLoop, &res);
  }
}

/* **************************************************** */

u_int32_t PF_RINGInterface::getNumDroppedPackets() {
  pfring_stat stats;

  if(pfring_stats(pfring_handle, &stats) >= 0) {
#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][Rcvd: %llu][Drops: %llu][DroppedByFilter: %u]",
				 ifname, stats.recv, stats.drop, stats.droppedbyfilter);
#endif
    return(stats.drop);
  }

  return 0;
}

/* **************************************************** */

bool PF_RINGInterface::set_packet_filter(char *filter) {
  if(pfring_set_bpf_filter(pfring_handle, filter) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set filter %s. Filter ignored.\n", filter);
    return(false);
  } else {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Packet capture filter set to \"%s\"", filter);
    return(true);
  }
}

/* **************************************************** */

#endif /* HAVE_PF_RING */
