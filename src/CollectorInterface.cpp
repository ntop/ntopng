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

CollectorInterface::CollectorInterface(const char *_endpoint, const char *_topic)
  : ParserInterface(_endpoint) {
  char *tmp, *e;

  num_drops = 0, num_subscribers = 0;
  topic = strdup(_topic);

  context = zmq_ctx_new();

  if((tmp = strdup(_endpoint)) == NULL) throw("Out of memory");

  e = strtok(tmp, ",");
  while(e != NULL) {
    if(num_subscribers == CONST_MAX_NUM_ZMQ_SUBSCRIBERS) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Too many endpoints defined %u: skipping those in excess",
				   num_subscribers);
      break;
    }

    subscriber[num_subscribers].socket = zmq_socket(context, ZMQ_SUB);

    if(zmq_connect(subscriber[num_subscribers].socket, e) != 0) {
      zmq_close(subscriber[num_subscribers].socket);
      zmq_ctx_destroy(context);
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to connect to ZMQ endpoint %s", e);
      free(tmp);
      throw("Unable to connect to the specified ZMQ endpoint");
    }

    if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_SUBSCRIBE, topic, strlen(topic)) != 0) {
      zmq_close(subscriber[num_subscribers].socket);
      zmq_ctx_destroy(context);
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to connect to the specified ZMQ endpoint");
      free(tmp);
      throw("Unable to subscribe to the specified ZMQ endpoint");
    }

    subscriber[num_subscribers].endpoint = strdup(e);

    num_subscribers++;
    e = strtok(NULL, ",");
  }

  free(tmp);
}

/* **************************************************** */

CollectorInterface::~CollectorInterface() {
  for(int i=0; i<num_subscribers; i++) {
    if(subscriber[i].endpoint) free(subscriber[i].endpoint);
    zmq_close(subscriber[i].socket);
  }

  if(topic) free(topic);
  zmq_ctx_destroy(context);
}

/* **************************************************** */

void CollectorInterface::collect_flows() {
  struct zmq_msg_hdr h;
  char payload[8192];
  u_int payload_len = sizeof(payload)-1;
  zmq_pollitem_t items[CONST_MAX_NUM_ZMQ_SUBSCRIBERS];
  int rc, size;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Collecting flows on %s", ifname);

  while(isRunning()) {
    while(idle()) {
      purgeIdle(time(NULL));
      sleep(1);
      if(ntop->getGlobals()->isShutdown()) return;
    }

    for(int i=0; i<num_subscribers; i++)
      items[i].socket = subscriber[i].socket, items[i].fd = 0, items[i].events = ZMQ_POLLIN, items[i].revents = 0;

    do {
      rc = zmq_poll(items, num_subscribers, 1000 /* 1 sec */);
      if((rc < 0) || (!isRunning())) return;
      if(rc == 0) purgeIdle(time(NULL));
    } while(rc == 0);

    for(int source_id=0; source_id<num_subscribers; source_id++) {
      if(items[source_id].revents & ZMQ_POLLIN) {
	size = zmq_recv(items[source_id].socket, &h, sizeof(h), 0);

	if((size != sizeof(h)) || (h.version != MSG_VERSION)) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING,
				       "Unsupported publisher version [%d]: your nProbe sender is outdated?",
				       h.version);
	  continue;
	}

	size = zmq_recv(items[source_id].socket, payload, payload_len, 0);

	if(size > 0) {
	  payload[size] = '\0';

	  parse_flows(payload, sizeof(payload) , source_id, this);

	  ntop->getTrace()->traceEvent(TRACE_INFO, "[%u] %s", h.size, payload);
	}
      }
    } /* for */
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow collection is over.");
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  CollectorInterface *iface = (CollectorInterface*)ptr;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  iface->collect_flows();
  return(NULL);
}

/* **************************************************** */

void CollectorInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);
  pollLoopCreated = true; 
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void CollectorInterface::shutdown() {
  void *res;

  if(running) {
    NetworkInterface::shutdown();
    pthread_join(pollLoop, &res);
  }
}

/* **************************************************** */

bool CollectorInterface::set_packet_filter(char *filter) {
  ntop->getTrace()->traceEvent(TRACE_ERROR,
			       "No filter can be set on a collector interface. Ignored %s", filter);
  return(false);
}

/* **************************************************** */
