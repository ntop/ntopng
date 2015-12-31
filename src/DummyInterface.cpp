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

/* **************************************************** */

DummyInterface::DummyInterface() : ParserInterface("dummy") {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Initialized dummy interface");
}

/* **************************************************** */

void DummyInterface::forgeFlow(u_int iteration) {
  char payload[256];
  u_int32_t srcIp = 0xC0A80000;
  u_int32_t dstIp = 0x0A000000;
  u_int id, mval = 1+(ntop->getPrefs()->get_max_num_hosts()/ntop->getPrefs()->get_max_num_flows());
  time_t now = time(NULL);

  id = iteration % ntop->getPrefs()->get_max_num_hosts();
  srcIp += id, dstIp += id;
  
  for(u_int i=0; i<mval; i++) {
    char a[32], b[32];
    u_int16_t sport = 1234+i, dport = 80;

    snprintf(payload, sizeof(payload), 
	     "{\"8\":\"%s\",\"12\":\"%s\",\"10\":0,\"14\":0,\"2\":%u,\"1\":%u,\"22\":%lu,\"21\":%lu,\"7\":%u,\"11\":%u,\"6\":0,\"4\":17,\"5\":0,\"16\":0,\"17\":0,\"9\":0,\"13\":0,\"42\":297}",
	     Utils::intoaV4(srcIp, a, sizeof(a)),
	     Utils::intoaV4(dstIp, b, sizeof(b)),
	     iteration, iteration*1500,
	     now-60, now, sport, dport);

    parse_flows(payload, sizeof(payload), 1 /* source_id */, this /* iface */);
  }

  if(id == 0) sleep(1);
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  DummyInterface *iface = (DummyInterface*)ptr;
  u_int32_t iteration = 0;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  while(iface->isRunning()) {
    iface->forgeFlow(++iteration);
    usleep(10);
  }
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow collection is over.");
  return(NULL);
}

/* **************************************************** */

void DummyInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void DummyInterface::shutdown() {
  void *res;

  if(running) {
    NetworkInterface::shutdown();
    pthread_join(pollLoop, &res);
  }
}
