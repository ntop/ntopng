/*
 *
 * (C) 2016-18 - ntop.org
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

#if defined(HAVE_PF_RING) && (!defined(NTOPNG_EMBEDDED_EDITION)) && (!defined(__i686__)) && (!defined(__ARM_ARCH))

/* **************************************************** */

ZCCollectorInterface::ZCCollectorInterface(const char *name) : ParserInterface(name) {
  char ifname[32];
  char *at;

  cluster_id = queue_id = 0;

  snprintf(ifname, sizeof(ifname), "%s", &name[7]);

  at = strchr(ifname, '@');

  if(at != NULL) {
    queue_id = atoi(&at[1]);
    at[0] = '\0';
  }

  cluster_id = atoi(ifname);

  zq = pfring_zc_ipc_attach_queue(cluster_id, queue_id, rx_only);

  if(zq == NULL)
    throw("pfring_zc_ipc_attach_queue error");

  zp = pfring_zc_ipc_attach_buffer_pool(cluster_id, queue_id);

  if(zp == NULL)
    throw("pfring_zc_ipc_attach_buffer_pool error");

  buffer = pfring_zc_get_packet_handle_from_pool(zp);

  if(buffer == NULL)
    throw("pfring_zc_get_packet_handle_from_pool error");

  memset(&last_pfring_zc_stat, 0, sizeof(last_pfring_zc_stat));
}

/* **************************************************** */

ZCCollectorInterface::~ZCCollectorInterface() {
  pfring_zc_sync_queue(zq, rx_only);
  pfring_zc_release_packet_handle_to_pool(zp, buffer);
  pfring_zc_ipc_detach_queue(zq);
  pfring_zc_ipc_detach_buffer_pool(zp);
}

/* **************************************************** */

void ZCCollectorInterface::collect_flows() {
  int rc;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Collecting flows from ZC queue %u@%u", cluster_id, queue_id);

  while(isRunning()) {
    while(idle()) {
      purgeIdle(time(NULL));
      sleep(1);
      if(ntop->getGlobals()->isShutdown()) return;
    }

    rc = pfring_zc_recv_pkt(zq, &buffer, 0 /* wait_for_packet */);

    if(rc > 0) {
      u_char *json = pfring_zc_pkt_buff_data(buffer, zq);
      const char *master = "{ \"if.name\"";
      
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s", json);
      // fprintf(stdout, "+"); fflush(stdout);

      if(strncmp((char*)json, master, strlen(master)) == 0) {
	parseEvent((char*)json, buffer->len, 0, (void*)this);
      } else
	parseFlow((char*)json, buffer->len, 0, (void*)this);
      // fprintf(stdout, "."); fflush(stdout);
    } else if(rc == 0) {
      usleep(1);
      purgeIdle(time(NULL));
      // fprintf(stdout, "*"); fflush(stdout);
    } else {
      /* rc < 0 */
      break;
    }
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "ZC Flow collection is over.");

  pfring_zc_sync_queue(zq, rx_only);
}

/* **************************************************** */

static void *packetPollLoop(void *ptr) {
  ZCCollectorInterface *iface = (ZCCollectorInterface *) ptr;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  iface->collect_flows();
  return(NULL);
}

/* **************************************************** */

void ZCCollectorInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void *) this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void ZCCollectorInterface::shutdown() {
  if(running) {
    void *res;

    NetworkInterface::shutdown();
    pfring_zc_queue_breakloop(zq);
    pthread_join(pollLoop, &res);
  }
}

/* **************************************************** */

bool ZCCollectorInterface::set_packet_filter(char *filter) {
  ntop->getTrace()->traceEvent(TRACE_ERROR,
			       "No filter can be set on a collector interface. Ignored %s", filter);
  return(false);
}

/* **************************************************** */

u_int32_t ZCCollectorInterface::getNumDroppedPackets() {
  pfring_zc_stat stats;

  if(pfring_zc_stats(zq, &stats) >= 0) {
#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][Sent: %llu]"
				 "[Rcvd: %llu][Drops: %llu][QueueLen: %d]",
				 ifname, stats.sent, stats.recv, stats.drop,
				 stats.sent-stats.recv);
#endif
    return(stats.drop);
  }

  return 0;
}

/* **************************************************** */

#endif

#endif
