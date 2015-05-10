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

#ifdef HAVE_NETFILTER
#include "NetfilterHandler.h"

#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

/* **************************************************** */

NetfilterInterface::NetfilterInterface(const char *name) : NetworkInterface(name) {
  nfHandle = NULL;
  char queueId_s[64];

  if(strncmp(name, "nf:", 3) != 0)
    throw 1;

  snprintf(queueId_s, sizeof(queueId_s), "%s", &name[3]);

  queueId = atoi(queueId_s);
  nfHandle = nfq_open();
  if (nfHandle == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to get netfilter handle [%d]", queueId);
    return;
  }
  if (nfq_unbind_pf(nfHandle, AF_INET) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to unbind [%d]", queueId);
    return;
  }
  if (nfq_bind_pf(nfHandle, AF_INET) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind [%d]", queueId);
    return;
  }

#ifdef NTOPNG_PRO
  handler = new NetfilterHandler();
#endif
}

/* **************************************************** */

NetfilterInterface::~NetfilterInterface() {
  if (nfQHandle)
    nfq_destroy_queue(nfQHandle);
  if (nfHandle)
    nfq_close(nfHandle);
  nf_fd = 0;
}

/* **************************************************** */

static int netfilter_callback(struct nfq_q_handle *qh,
			      struct nfgenmsg *nfmsg,
			      struct nfq_data *nfa,
			      void *data) {
  const u_char *payload;
  u_int payload_len;
  u_int32_t nf_verdict, nf_mark;
  struct nfqnl_msg_packet_hdr *ph = nfq_get_msg_packet_hdr(nfa);
  int last_rcvd_packet_id, rc;
  NetfilterInterface *iface = (NetfilterInterface *)data;

  last_rcvd_packet_id = ph ? ntohl(ph->packet_id) : 0;
  payload_len = nfq_get_payload(nfa, (unsigned char **)&payload);
  nf_verdict = NF_ACCEPT, nf_mark = 0;

#ifdef NTOPNG_PRO
  iface->handler->handlePacket(payload_len, payload, nfa, &nf_verdict, &nf_mark, data);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "[NetFilter] [packet len: %u][verdict: %u][nf_mark: %u]",
	                       payload_len, nf_verdict, nf_mark);

#ifdef HAVE_NFQ_SET_VERDICT2
  rc = nfq_set_verdict2(
#else
  rc = nfq_set_verdict_mark(
#endif
        qh, last_rcvd_packet_id, nf_verdict,
	nf_mark, 0, NULL);

  return rc;
}

/* **************************************************** */

int NetfilterInterface::attachToNetFilter(void) {

  /* Binding this socket to queue 'queueId' */
  nfQHandle = nfq_create_queue(nfHandle, queueId, &netfilter_callback, this);
  if(nfQHandle == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Error during attach to queue %d: is it configured?", queueId);
    return -1;
  }

  if(nfq_set_mode(nfQHandle, NFQNL_COPY_PACKET,
                  1000 /* readOnlyGlobals.snaplen  IP_MAXPACKET */) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set packet_copy mode");
    return -1;
  }

  nf_fd = nfq_fd(nfHandle);

  return nf_fd;
}

/* **************************************************** */

#endif /* HAVE_NETFILTER */
