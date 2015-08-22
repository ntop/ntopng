/*
 *
 * (C) 2013-15 - ntop.org
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

#if defined(HAVE_NETFILTER)

#ifdef NTOPNG_PRO
extern int pro_netfilter_callback(struct nfq_q_handle *qh,
				  struct nfgenmsg *nfmsg,
				  struct nfq_data *nfa,
				  void *data);
#endif

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  NetfilterInterface *iface = (NetfilterInterface*)ptr;
  struct nfq_handle *h;
  int fd;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  h = iface->get_nfHandle();
  fd = iface->get_fd();

  while(iface->isRunning()) {
    int len;
    char pktBuf[4096] __attribute__ ((aligned));

    len = recv(fd, pktBuf, sizeof(pktBuf), 0);

    if(len >= 0) {
      int rc = nfq_handle_packet(h, pktBuf, len);

      if(rc < 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "nfq_handle_packet() failed: [len: %d][rc: %d][errno: %d]", len, rc, errno);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "NF_QUEUE receive error");
      break;
    }
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Leaving netfilter packet poll loop");
  return(NULL);
}

/* **************************************************** */

#ifndef NTOPNG_PRO
static int netfilter_callback(struct nfq_q_handle *qh,
			      struct nfgenmsg *nfmsg,
			      struct nfq_data *nfa,
			      void *data) {
  const u_char *payload;
  struct nfqnl_msg_packet_hdr *ph = nfq_get_msg_packet_hdr(nfa);
  NetfilterInterface *iface = (NetfilterInterface *)data;
  u_int payload_len = nfq_get_payload(nfa, (unsigned char **)&payload);
  struct pcap_pkthdr h;
  int a, b;

  if(!ph) return(-1);

  h.len = h.caplen = payload_len, nfq_get_timestamp(nfa, &h.ts);

  iface->packet_dissector(&h, payload, &a, &b);

  return(nfq_set_verdict(qh, ntohl(ph->packet_id), NF_ACCEPT, 0, NULL));
}
#endif

/* **************************************************** */

NetfilterInterface::NetfilterInterface(const char *name) : NetworkInterface(name) {
  queueId = atoi(&name[3]);
  nfHandle = nfq_open();

  if(nfHandle == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to get netfilter handle [%d]", queueId);
    throw 1;
  }

  if(nfq_unbind_pf(nfHandle, AF_INET) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to unbind [%d]", queueId);
    throw 1;
  }

  if(nfq_bind_pf(nfHandle, AF_INET) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind [%d]", queueId);
    throw 1;
  }

  if((queueHandle = nfq_create_queue(nfHandle, queueId,
#ifdef NTOPNG_PRO
				     &pro_netfilter_callback,
#else
				     &netfilter_callback,
#endif
				     this)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Error during attach to queue %d: is it configured?", queueId);
    throw 1;
  } else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Succesfully connected to NF_QUEUE %d", queueId);

  if(nfq_set_mode(queueHandle, NFQNL_COPY_PACKET, 0XFFFF) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set packet_copy mode");
    throw 1;
  }

  nf_fd = nfq_fd(nfHandle);

  if(ntop->getPrefs()->do_change_user()) {
    /*
       If using netfilter we must avoid changing userId otherwise packet polling
       will fail
    */
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Disabling user change as otherwise netfilter won't work");
    ntop->getPrefs()->dont_change_user();
  }
}

/* **************************************************** */

NetfilterInterface::~NetfilterInterface() {
  if(queueHandle) nfq_destroy_queue(queueHandle);
  if(nfHandle)    nfq_close(nfHandle);
  nf_fd = 0;
}

/* **************************************************** */

void NetfilterInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

#endif /* HAVE_NETFILTER */
