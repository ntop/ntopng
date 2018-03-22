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

#ifndef HAVE_NEDGE

/* **************************************************** */

CollectorInterface::CollectorInterface(const char *_endpoint) : ParserInterface(_endpoint) {
  char *tmp, *e, *t;
  const char *topics[] = { "flow", "event", "counter", NULL };

  memset(&recvStats, 0, sizeof(recvStats));
  num_subscribers = 0;

  context = zmq_ctx_new();

  if((tmp = strdup(_endpoint)) == NULL) throw("Out of memory");

  is_collector = false;
  
  e = strtok_r(tmp, ",", &t);
  while(e != NULL) {
    int l = strlen(e)-1, val;
    char last_char = e[l];

    if(num_subscribers == MAX_ZMQ_SUBSCRIBERS) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Too many endpoints defined %u: skipping those in excess",
				   num_subscribers);
      break;
    }

    subscriber[num_subscribers].socket = zmq_socket(context, ZMQ_SUB);

    val = 131072;
    if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_RCVBUF, &val, sizeof(val)) != 0)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enlarge ZMQ buffer size");

    if(last_char == 'c')
      is_collector = true, e[l] = '\0';

    if(is_collector) {
      if(zmq_bind(subscriber[num_subscribers].socket, e) != 0) {
	zmq_close(subscriber[num_subscribers].socket);
	zmq_ctx_destroy(context);
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind to ZMQ endpoint %s [collector]", e);
	free(tmp);
	throw("Unable to bind to the specified ZMQ endpoint");
      }
    } else {
      if(zmq_connect(subscriber[num_subscribers].socket, e) != 0) {
	zmq_close(subscriber[num_subscribers].socket);
	zmq_ctx_destroy(context);
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to connect to ZMQ endpoint %s [probe]", e);
	free(tmp);
	throw("Unable to connect to the specified ZMQ endpoint");
      }
    }

    for(int i=0; topics[i] != NULL; i++) {
      if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_SUBSCRIBE, topics[i], strlen(topics[i])) != 0) {
	zmq_close(subscriber[num_subscribers].socket);
	zmq_ctx_destroy(context);
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to connect to subscribe to topic %s", topics[i]);
	free(tmp);
	throw("Unable to subscribe to the specified ZMQ endpoint");
      }
    }

    subscriber[num_subscribers].endpoint = strdup(e);

    num_subscribers++;

    e = strtok_r(NULL, ",", &t);
  }

  free(tmp);
}

/* **************************************************** */

CollectorInterface::~CollectorInterface() {
  for(int i=0; i<num_subscribers; i++) {
    if(subscriber[i].endpoint) free(subscriber[i].endpoint);
    zmq_close(subscriber[i].socket);
  }

  zmq_ctx_destroy(context);
}

/* **************************************************** */

void CollectorInterface::collect_flows() {
  struct zmq_msg_hdr h;
  char payload[8192];
  u_int payload_len = sizeof(payload)-1;
  zmq_pollitem_t items[MAX_ZMQ_SUBSCRIBERS];
  u_int32_t zmq_max_num_polls_before_purge = MAX_ZMQ_POLLS_BEFORE_PURGE;
  u_int32_t now, next_purge_idle = (u_int32_t)time(NULL) + FLOW_PURGE_FREQUENCY;
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
      rc = zmq_poll(items, num_subscribers,  MAX_ZMQ_POLL_WAIT_MS);

      now = (u_int32_t)time(NULL);
      zmq_max_num_polls_before_purge--;

      if((rc < 0) || (!isRunning())) return;

      if(rc == 0 || now >= next_purge_idle || zmq_max_num_polls_before_purge == 0) {
	purgeIdle(now);
	next_purge_idle = now + FLOW_PURGE_FREQUENCY;
	zmq_max_num_polls_before_purge = MAX_ZMQ_POLLS_BEFORE_PURGE;
      }
    } while(rc == 0);

    for(int source_id=0; source_id<num_subscribers; source_id++) {
      u_int32_t msg_id;
	
      if(items[source_id].revents & ZMQ_POLLIN) {
	size = zmq_recv(items[source_id].socket, &h, sizeof(h), 0);

	if(size == sizeof(struct zmq_msg_hdr_v0)) {
	  /* Legacy version */
	  msg_id = 0;
	} else if((size != sizeof(h)) || (h.version != ZMQ_MSG_VERSION)) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING,
				       "Unsupported publisher version: your nProbe sender is outdated? [%u][%u]",
				       sizeof(struct zmq_msg_hdr), sizeof(h));
	  continue;
	} else
	  msg_id = h.msg_id;

	if((!is_collector) && (msg_id > 0)) {
	  /* 
	     TODO
	     Develop logic for computing drops in collector mode
	  */
	  if(msg_id < recvStats.last_zmq_msg_id) {
	    /* Start over */
	  } else if(recvStats.last_zmq_msg_id > 0) {
	    u_int32_t diff = msg_id - recvStats.last_zmq_msg_id;

	    if(diff != 1) {
	      recvStats.zmq_msg_drops += diff;
	      ntop->getTrace()->traceEvent(TRACE_INFO, "msg_id=%u, drops=%u", msg_id, recvStats.zmq_msg_drops);
	    }
	  }

	  recvStats.last_zmq_msg_id = msg_id;
	}       
	
	size = zmq_recv(items[source_id].socket, payload, payload_len, 0);

	if(size > 0) {
	  char *uncompressed = NULL;
	  u_int uncompressed_len;
	  
	  payload[size] = '\0';

	  if(payload[0] == 0 /* Compressed traffic */) {
#ifdef HAVE_ZLIB
	    int err;
	    uLongf uLen;

	    uLen = uncompressed_len = max(3*size, MAX_ZMQ_FLOW_BUF);
	    uncompressed = (char*)malloc(uncompressed_len+1);
	    if((err = uncompress((Bytef*)uncompressed, &uLen, (Bytef*)&payload[1], size-1)) != Z_OK) {
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Uncompress error [%d][len: %u]", err, size);
	      continue;
	    }

	    uncompressed_len = uLen, uncompressed[uLen] = '\0';
#else
	    static bool once = false;

	    if(!once)
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to uncompress ZMQ traffic: ntopng compiled without zlib"), once = true;

	    continue;
#endif
	  } else
	    uncompressed = payload, uncompressed_len = size;

	  if(ntop->getPrefs()->get_zmq_encryption_pwd())
	    Utils::xor_encdec((u_char*)uncompressed, uncompressed_len, (u_char*)ntop->getPrefs()->get_zmq_encryption_pwd());
	  
	  ntop->getTrace()->traceEvent(TRACE_INFO, "%s [msg_id=%u]", uncompressed, msg_id);

	  switch(h.url[0]) {
	  case 'e': /* event */
	    recvStats.num_events++;
	    parseEvent(uncompressed, uncompressed_len, source_id, this);
	    break;

	  case 'f': /* flow */
	    recvStats.num_flows += parseFlow(uncompressed, uncompressed_len, source_id, this);
	    break;

	  case 'c': /* counter */
	    recvStats.num_counters++;
	    parseCounter(uncompressed, uncompressed_len, source_id, this);
	    break;
	  }

	  /* ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s", h.url, uncompressed); */

#ifdef HAVE_ZLIB
	  if(payload[0] == 0 /* only if the traffic was actually compressed */)
	    if(uncompressed) free(uncompressed);
#endif
	} /* size > 0 */
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

void CollectorInterface::lua(lua_State* vm) {
  ParserInterface::lua(vm);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "flows", recvStats.num_flows);
  lua_push_int_table_entry(vm, "events", recvStats.num_events);
  lua_push_int_table_entry(vm, "counters", recvStats.num_counters);
  lua_push_int_table_entry(vm, "zmq_msg_drops", recvStats.zmq_msg_drops);
  lua_pushstring(vm, "zmqRecvStats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* **************************************************** */

void CollectorInterface::purgeIdle(time_t when) {
  NetworkInterface::purgeIdle(when);

  if(flowHashing) {
    FlowHashing *current, *tmp;
    HASH_ITER(hh, flowHashing, current, tmp)
      static_cast<NetworkInterface*>(current->iface)->purgeIdle(when);
  }
}

#endif
