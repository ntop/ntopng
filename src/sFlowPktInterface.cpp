/*
 *
 * (C) 2013-24 - ntop.org
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
#include "../third-party/sflow_collect.c"

/* **************************************************** */

sFlowPktInterface::sFlowPktInterface(const char *_name) : NetworkInterface(_name) {
  struct sockaddr_in svrAddr;
  u_int16_t port = atoi(&_name[6]);
  
  svrAddr.sin_family = AF_INET;
  svrAddr.sin_addr.s_addr = htonl(INADDR_ANY);
  svrAddr.sin_port = htons(port);

  sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
  if(sock_fd < 0)
    throw "Unable to create collection socket";
  
  if(::bind(sock_fd, (struct sockaddr *)&svrAddr, sizeof(svrAddr)) == -1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot bind at port %d [%s]",
				 port, strerror(errno));
    close(sock_fd);
    throw "bind error";
  } else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Waiting for flows at port %d", port);
}

/* **************************************************** */

sFlowPktInterface::~sFlowPktInterface() {
  close(sock_fd);
}

/* **************************************************** */

void sFlowPktInterface::sflowPacketPollLoop() {
  while (isRunning()) {
    fd_set flowMask;
    int rc;
    struct timeval wait_time;
    
    FD_ZERO(&flowMask);
    FD_SET(sock_fd, &flowMask);

    wait_time.tv_sec = 1, wait_time.tv_usec = 0;
    rc = select(sock_fd+1, &flowMask, NULL, NULL, &wait_time);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "select() returned %d", rc);
    
    if(rc > 0) {
      char buffer[2048];
      struct sockaddr_in fromHostV4;
      size_t len = sizeof(fromHostV4);
      
      rc = recvfrom(sock_fd, &buffer, sizeof(buffer),
		    0, (struct sockaddr*)&fromHostV4, (socklen_t*)&len);

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "recvfrom() returned %d", rc);
      
      if(rc > 0) {
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dissecting %u bytes sFlow", rc);
	
	dissectSflow(this, (u_char*)buffer, (uint)rc, &fromHostV4);
      } else
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "recvfrom failed[%d]: [%s/%d]\n",
				     rc, strerror(errno), errno);
    } else {
      purgeIdle(time(NULL));
    }
  }
}

/* **************************************************** */

static void *packetPollLoop(void *ptr) {
  sFlowPktInterface *iface = (sFlowPktInterface *)ptr;

  /* Wait until the initialization completes */
  while (iface->isStartingUp()) sleep(1);

  while (iface->idle()) {
    if (ntop->getGlobals()->isShutdown()) return (NULL);
    iface->purgeIdle(time(NULL));
    sleep(1);
  }

  iface->sflowPacketPollLoop();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated packet polling for %s",
                               iface->get_name());
  return (NULL);
}

/* **************************************************** */

void sFlowPktInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void *)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void sFlowPktInterface::shutdown() {
  NetworkInterface::shutdown();
}

/* **************************************************** */

#endif
