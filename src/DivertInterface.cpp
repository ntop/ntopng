/*
 *
 * (C) 2013-18 - ntop.org
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

#if defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__APPLE__)

/* http://resin.csoft.net/cgi-bin/man.cgi?section=0&topic=divert */

/* **************************************************** */

static void* divertPacketPollLoop(void* ptr) {
  DivertInterface *iface = (DivertInterface*)ptr;
  int fd;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  fd = iface->get_fd();

  while(iface->isRunning()) {
    int len;
    u_char packet[IP_MAXPACKET];
    struct sockaddr_in sin;
    socklen_t sin_len = sizeof(struct sockaddr_in);
    u_int16_t c;
    struct pcap_pkthdr h;
    Host *srcHost = NULL, *dstHost = NULL;
    Flow *flow = NULL;
    
    len = recvfrom(fd, packet, sizeof(packet), 0,
		   (struct sockaddr *)&sin, &sin_len);

    if(len == 1) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Receive error");
      break;
    }

    if(len < sizeof(struct ip)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Packet too short (%d bytes)", len);
      break;
    }
  
#ifdef __OpenBSD__
    struct timeval tv;
    h.len = h.caplen = len, gettimeofday(&tv, NULL);
    h.ts.tv_sec  = tv.tv_sec;
    h.ts.tv_usec = tv.tv_usec;
#else
    h.len = h.caplen = len, gettimeofday(&h.ts, NULL);
#endif /* __OpenBSD__ */
    iface->dissectPacket(DUMMY_BRIDGE_INTERFACE_ID,
			 true /* ingress packet */,
			 NULL, &h, packet, &c, &srcHost, &dstHost, &flow);

    /* Enable the row below to specify the firewall rule corresponding to the protocol */
#if 0
    sin.sin_port = c | 0x1000 /* DIVERT_ALTQ */;
#endif
    if(sendto(fd, packet, len, 0, (struct sockaddr *)&sin, sin_len) < 0)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "sendto(len=%d,sin_len=%d,altq=%d) failed [%d/%s]",
				   len, sin_len, c, errno, strerror(errno));    
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Leaving divert packet poll loop");
  return(NULL);
}

/* **************************************************** */

DivertInterface::DivertInterface(const char *name) : NetworkInterface(name) {
  struct sockaddr_in sin;
  socklen_t sin_len;
  
  port = atoi(&name[7]);

  if((sock = socket(PF_INET, SOCK_RAW, IPPROTO_DIVERT)) == -1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to created divert socket");
    throw 1;
  }

  memset(&sin, 0, sizeof(sin));
  sin.sin_family = AF_INET, sin.sin_port = htons(port);
  sin_len = sizeof(struct sockaddr_in);

  if(::bind(sock, (struct sockaddr *) &sin, sin_len) == -1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind divert socket to port %d", port);
    throw 1;
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created divert socket listening on port %d", port);
  
  pcap_datalink_type = DLT_IPV4;
}

/* **************************************************** */

DivertInterface::~DivertInterface() {
  closesocket(sock);
}

/* **************************************************** */

void DivertInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, divertPacketPollLoop, (void*)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

#endif /* defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__APPLE__) */
