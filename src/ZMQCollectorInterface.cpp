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

#ifndef HAVE_NEDGE

/* **************************************************** */

ZMQCollectorInterface::ZMQCollectorInterface(const char *_endpoint) : ZMQParserInterface(_endpoint) {
  char *tmp, *e, *t;
  const char *topics[] = { "flow", "event", "counter", "template", "option", "hello", NULL };
  
  num_subscribers = 0;
  server_secret_key[0] = '\0';
  server_public_key[0] = '\0';

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

    if(subscriber[num_subscribers].socket == NULL)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create ZMQ socket");

    if(ntop->getPrefs()->is_zmq_encryption_enabled()) {
#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,1,0)
      const char *server_secret_key = ntop->getPrefs()->get_zmq_encryption_priv_key();

      if (server_secret_key == NULL)
        server_secret_key = generateEncryptionKeys(); 

      if (server_secret_key != NULL) {
        if(strlen(server_secret_key) != 40)
          ntop->getTrace()->traceEvent(TRACE_ERROR, "Bad ZMQ secret key len (%lu != 40)", strlen(server_secret_key));
        else {
          int val = 1;

          if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_CURVE_SERVER, &val, sizeof(val)) != 0) 
            ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set ZMQ_CURVE_SERVER");
          else {
            if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_CURVE_SECRETKEY, server_secret_key, 41) != 0)
              ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set ZMQ_CURVE_SECRETKEY");
            else
              ntop->getTrace()->traceEvent(TRACE_INFO, "ZMQ CURVE encryption enabled");
          }
        }
      }
#else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable ZMQ CURVE encryption, ZMQ >= 4.1 is required");
#endif
    }

    val = 8388608; /* 8M default: cat /proc/sys/net/core/rmem_max */
    if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_RCVBUF, &val, sizeof(val)) != 0)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enlarge ZMQ buffer size");

    if(!strncmp(e, (char*)"tcp://", 6)) {
      val = DEFAULT_ZMQ_TCP_KEEPALIVE;
      if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_TCP_KEEPALIVE, &val, sizeof(val)) != 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set tcp keepalive");
      else
	ntop->getTrace()->traceEvent(TRACE_INFO, "TCP keepalive set");

      val = DEFAULT_ZMQ_TCP_KEEPALIVE_IDLE;
      if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_TCP_KEEPALIVE_IDLE, &val, sizeof(val)) != 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set tcp keepalive idle to %u seconds", val);
      else
	ntop->getTrace()->traceEvent(TRACE_INFO, "TCP keepalive idle set to %u seconds", val);

      val = DEFAULT_ZMQ_TCP_KEEPALIVE_CNT;
      if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_TCP_KEEPALIVE_CNT, &val, sizeof(val)) != 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set tcp keepalive count to %u", val);
      else
	ntop->getTrace()->traceEvent(TRACE_INFO, "TCP keepalive count set to %u", val);

      val = DEFAULT_ZMQ_TCP_KEEPALIVE_INTVL;
      if(zmq_setsockopt(subscriber[num_subscribers].socket, ZMQ_TCP_KEEPALIVE_INTVL, &val, sizeof(val)) != 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set tcp keepalive interval to %u seconds", val);
      else
	ntop->getTrace()->traceEvent(TRACE_INFO, "TCP keepalive interval set to %u seconds", val);
    }

    if(last_char == 'c')
      is_collector = true, e[l] = '\0';

    if(is_collector) {
      if(zmq_bind(subscriber[num_subscribers].socket, e) != 0) {
	zmq_close(subscriber[num_subscribers].socket);
	zmq_ctx_destroy(context);
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind to ZMQ endpoint %s [collector]: %s (%d)",
				     e, strerror(errno), errno);
	free(tmp);
	throw("Unable to bind to the specified ZMQ endpoint");
      }
    } else {
      if(zmq_connect(subscriber[num_subscribers].socket, e) != 0) {
	zmq_close(subscriber[num_subscribers].socket);
	zmq_ctx_destroy(context);
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to connect to ZMQ endpoint %s [probe]: %s (%d)",
          e, strerror(errno), errno);
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

ZMQCollectorInterface::~ZMQCollectorInterface() {
#ifdef PROFILING
  u_int64_t n = recvStats.num_flows;

  if(n > 0) {
    for (u_int i = 0; i < PROFILING_NUM_SECTIONS; i++) {
      if(PROFILING_SECTION_LABEL(i) != NULL)
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "[PROFILING] Section #%d '%s': AVG %llu ticks",
          i, PROFILING_SECTION_LABEL(i), PROFILING_SECTION_AVG(i, n));
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[PROFILING] Section #%d '%s': %llu ticks",
          i, PROFILING_SECTION_LABEL(i), PROFILING_SECTION_TICKS(i));
    }
  }
#endif

  for(int i=0; i<num_subscribers; i++) {
    if(subscriber[i].endpoint) free(subscriber[i].endpoint);
    zmq_close(subscriber[i].socket);
  }

  zmq_ctx_destroy(context);
}

/* **************************************************** */

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,1,0)
char *ZMQCollectorInterface::generateEncryptionKeys() {
  char public_key_path[PATH_MAX], secret_key_path[PATH_MAX];
  char *public_key = NULL, *secret_key = NULL;
  int rc = 0;

  snprintf(public_key_path, sizeof(public_key_path), "%s/%d/key.pub", ntop->get_working_dir(), get_id());
  snprintf(secret_key_path, sizeof(secret_key_path), "%s/%d/key.priv", ntop->get_working_dir(), get_id());
  ntop->fixPath(public_key_path);
  ntop->fixPath(secret_key_path);

  if (Utils::file_read(public_key_path, &public_key) > 0 &&
      Utils::file_read(secret_key_path, &secret_key) > 0) {
    strncpy(server_public_key, public_key, sizeof(server_public_key));
    strncpy(server_secret_key, secret_key, sizeof(server_secret_key));
    server_public_key[sizeof(server_public_key)-1] = '\0';
    server_secret_key[sizeof(server_secret_key)-1] = '\0';
    rc = 0;
  } else {
    rc = zmq_curve_keypair(server_public_key, server_secret_key);
    if (rc == 0) {
      Utils::file_write(public_key_path, server_public_key, strlen(server_public_key));
      Utils::file_write(secret_key_path, server_secret_key, strlen(server_secret_key));
    }
  }

  if (public_key != NULL) free(public_key);
  if (secret_key != NULL) free(secret_key);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to generate/read ZMQ encryption keys");
    return NULL;
  }

  return server_secret_key;
}
#endif

/* **************************************************** */

void ZMQCollectorInterface::checkPointCounters(bool drops_only) {
  if(!drops_only) {
    recvStatsCheckpoint.num_flows = recvStats.num_flows,
      recvStatsCheckpoint.num_dropped_flows = recvStats.num_dropped_flows,
      recvStatsCheckpoint.num_events = recvStats.num_events,
      recvStatsCheckpoint.num_counters = recvStats.num_counters,
      recvStatsCheckpoint.num_templates = recvStats.num_templates,
      recvStatsCheckpoint.num_options = recvStats.num_options,
      recvStatsCheckpoint.num_network_events = recvStats.num_network_events,
      recvStatsCheckpoint.zmq_msg_rcvd = recvStats.zmq_msg_rcvd;
  }

  recvStatsCheckpoint.zmq_msg_drops = recvStats.zmq_msg_drops;

  NetworkInterface::checkPointCounters(drops_only);
}

/* **************************************************** */

void ZMQCollectorInterface::collect_flows() {
  struct zmq_msg_hdr_v0 h0;
  struct zmq_msg_hdr *h = (struct zmq_msg_hdr *) &h0; /* NOTE: in network-byte-order format */
  char *payload;
  const u_int payload_len = 32768;
  zmq_pollitem_t items[MAX_ZMQ_SUBSCRIBERS];
  u_int32_t zmq_max_num_polls_before_purge = MAX_ZMQ_POLLS_BEFORE_PURGE;
  u_int32_t now, next_purge_idle = (u_int32_t)time(NULL) + FLOW_PURGE_FREQUENCY;
  int rc, size;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Collecting flows on %s", ifname);

  if((payload = (char*)malloc(payload_len+1 /* Leave a char for \0 */)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Out of memory");
    return;
  }
  
  while(isRunning()) {
    while(idle()) {
      purgeIdle(time(NULL));
      sleep(1);
      if(ntop->getGlobals()->isShutdown()) {
	free(payload);
	return;
      }
    }

    for(int i=0; i<num_subscribers; i++)
      items[i].socket = subscriber[i].socket, items[i].fd = 0, items[i].events = ZMQ_POLLIN, items[i].revents = 0;

    do {
      rc = zmq_poll(items, num_subscribers,  MAX_ZMQ_POLL_WAIT_MS);

      now = (u_int32_t)time(NULL);
      zmq_max_num_polls_before_purge--;

      if((rc < 0) || (!isRunning())) {
	free(payload);
	return;
      }
      
      if(rc == 0 || now >= next_purge_idle || zmq_max_num_polls_before_purge == 0) {
	purgeIdle(now);
	next_purge_idle = now + FLOW_PURGE_FREQUENCY;
	zmq_max_num_polls_before_purge = MAX_ZMQ_POLLS_BEFORE_PURGE;
      }
    } while(rc == 0);

    for(int subscriber_id = 0; subscriber_id < num_subscribers; subscriber_id++) {
      u_int32_t msg_id, last_msg_id;
      u_int8_t source_id = 0;
      u_int32_t publisher_version = 0;
	
      if(items[subscriber_id].revents & ZMQ_POLLIN) {
	size = zmq_recv(items[subscriber_id].socket, &h0, sizeof(h0), 0);

	if(size == sizeof(struct zmq_msg_hdr_v0)) {
	  /* Legacy version */
	  msg_id = 0, source_id = 0;
          publisher_version = h0.version;

	} else /* size == struct zmq_msg_hdr */ {
          /* safety checks */
          if(size != sizeof(struct zmq_msg_hdr) || (
            h->version != ZMQ_MSG_VERSION && 
            h->version != ZMQ_MSG_VERSION_TLV &&
            h->version != ZMQ_COMPATIBILITY_MSG_VERSION
          )) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING,
				         "Unsupported publisher version: is your nProbe sender "
					 "outdated? [%u][%u][%u][%u][%u]",
				         size, sizeof(struct zmq_msg_hdr), h->version,
					 ZMQ_MSG_VERSION, ZMQ_COMPATIBILITY_MSG_VERSION);
	    continue; /* skip message */
          }

#ifdef ZMQ_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[version: %u]", h->version);
#endif

	  if(h->version == ZMQ_COMPATIBILITY_MSG_VERSION) {
	    source_id = 0, msg_id = h->msg_id; // host byte order
            publisher_version = h->version;
	  } else {
	    source_id = h->source_id, msg_id = ntohl(h->msg_id);
            publisher_version = h->version;
          }
        }

	if(source_id_last_msg_id.find(source_id) == source_id_last_msg_id.end())
	  source_id_last_msg_id[source_id] = 0;

	last_msg_id = source_id_last_msg_id[source_id];
	
#ifdef ZMQ_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "[topic: %s]", h->url);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "[subscriber_id: %u][message source: %u]"
				     "[msg_id: %u][last_msg_id: %u][lost: %i]",
				     subscriber_id, source_id, msg_id, last_msg_id, msg_id - last_msg_id - 1);
#endif
	
	if(msg_id > 0) {
	  if(msg_id < last_msg_id) ; /* Start over */
	  else if(last_msg_id > 0) {
	    int32_t diff = msg_id - last_msg_id;

	    if(diff > 1) {
	      recvStats.zmq_msg_drops += diff - 1;

#ifdef ZMQ_DEBUG
	      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[msg_id=%u][last=%u][tot_msgs=%u][drops=%u][+%u]", 
					   msg_id, last_msg_id, recvStats.zmq_msg_rcvd, recvStats.zmq_msg_drops, diff-1);
#endif
	    }
	  }

	  source_id_last_msg_id[source_id] = msg_id;
	}       

	/*
          The zmq_recv() function shall return number of bytes in the message if successful.
          Note that the value can exceed the value of the len parameter in case the message was truncated.
          If not successful the function shall return -1 and set errno to one of the values defined below.
	*/
	size = zmq_recv(items[subscriber_id].socket, payload, payload_len, 0);
	
	if(size > 0 && (u_int32_t)size > payload_len)
	  ntop->getTrace()->traceEvent(TRACE_WARNING,
				       "ZMQ message truncated? [size: %u][payload_len: %u]",
				       size, payload_len);
	else if(size > 0) {
	  char *uncompressed = NULL;
	  u_int uncompressed_len;
          bool tlv_encoding = false;
          bool compressed = false;

	  recvStats.zmq_msg_rcvd++;
	  payload[size] = '\0';
	  
          if(publisher_version == ZMQ_MSG_VERSION_TLV)
            tlv_encoding = true;
          else if(payload[0] == 0)
            compressed = true;

	  if(compressed /* Compressed traffic */) {
#ifdef HAVE_ZLIB
	    int err;
	    uLongf uLen;

	    uLen = uncompressed_len = max(5 * size, MAX_ZMQ_FLOW_BUF);
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
          } else if(tlv_encoding /* TLV encoding */) {
            // ntop->getTrace()->traceEvent(TRACE_NORMAL, "TLV message over ZMQ");
	    uncompressed = payload, uncompressed_len = size;
	  } else /* JSON string */
	    uncompressed = payload, uncompressed_len = size;          

	  if(ntop->getPrefs()->get_zmq_encryption_pwd())
	    Utils::xor_encdec((u_char*)uncompressed, uncompressed_len, (u_char*)ntop->getPrefs()->get_zmq_encryption_pwd());

	  if(false) {
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[url: %s]", h->url);
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [msg_id=%u][url: %s]", uncompressed, msg_id, h->url);
	  }
	  
          switch(h->url[0]) {
          case 'e': /* event */
            recvStats.num_events++;
            parseEvent(uncompressed, uncompressed_len, source_id, this);
            break;

          case 'f': /* flow */
            if(tlv_encoding) 
              recvStats.num_flows += parseTLVFlow(uncompressed, uncompressed_len, subscriber_id, this);
            else {
	      uncompressed[uncompressed_len] = '\0';
              recvStats.num_flows += parseJSONFlow(uncompressed, uncompressed_len, subscriber_id);
	    }
            break;

          case 'c': /* counter */
            recvStats.num_counters++;
            parseCounter(uncompressed, uncompressed_len, subscriber_id, this);
            break;

          case 't': /* template */
            recvStats.num_templates++;
            parseTemplate(uncompressed, uncompressed_len, subscriber_id, this);
            break;

          case 'o': /* option */
            recvStats.num_options++;
            parseOption(uncompressed, uncompressed_len, subscriber_id, this);
            break;

	  case 'h': /* hello */
	    recvStats.num_hello++;
#ifndef HAVE_NEDGE
	    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[HELLO] %s", uncompressed);
#endif
	    ntop->askToRefreshIPSRules();
	    break;
          }

	  /* ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s", h->url, uncompressed); */

#ifdef HAVE_ZLIB
	  if(compressed /* only if the traffic was actually compressed */)
	    if(uncompressed) free(uncompressed);
#endif
	} /* size > 0 */
      }
    } /* for */
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow collection is over.");

  free(payload);
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  ZMQCollectorInterface *iface = (ZMQCollectorInterface*)ptr;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  iface->collect_flows();
  return(NULL);
}

/* **************************************************** */

void ZMQCollectorInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

bool ZMQCollectorInterface::set_packet_filter(char *filter) {
  ntop->getTrace()->traceEvent(TRACE_ERROR,
			       "No filter can be set on a collector interface. Ignored %s", filter);
  return(false);
}

/* **************************************************** */

void ZMQCollectorInterface::lua(lua_State* vm) {
  ZMQParserInterface::lua(vm);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "flows", recvStats.num_flows);
  lua_push_uint64_table_entry(vm, "dropped_flows", recvStats.num_dropped_flows);
  lua_push_uint64_table_entry(vm, "events", recvStats.num_events);
  lua_push_uint64_table_entry(vm, "counters", recvStats.num_counters);
  lua_push_uint64_table_entry(vm, "zmq_msg_rcvd", recvStats.zmq_msg_rcvd);
  lua_push_uint64_table_entry(vm, "zmq_msg_drops", recvStats.zmq_msg_drops);
  lua_pushstring(vm, "zmqRecvStats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "flows", recvStats.num_flows - recvStatsCheckpoint.num_flows);
  lua_push_uint64_table_entry(vm, "dropped_flows", recvStats.num_dropped_flows - recvStatsCheckpoint.num_dropped_flows);
  lua_push_uint64_table_entry(vm, "events", recvStats.num_events - recvStatsCheckpoint.num_events);
  lua_push_uint64_table_entry(vm, "counters", recvStats.num_counters - recvStatsCheckpoint.num_counters);
  lua_push_uint64_table_entry(vm, "zmq_msg_rcvd", recvStats.zmq_msg_rcvd - recvStatsCheckpoint.zmq_msg_rcvd);
  lua_push_uint64_table_entry(vm, "zmq_msg_drops", recvStats.zmq_msg_drops - recvStatsCheckpoint.zmq_msg_drops);
  lua_pushstring(vm, "zmqRecvStats_since_reset");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if(ntop->getPrefs()->is_zmq_encryption_enabled() && strlen(server_public_key) > 0) {
    lua_newtable(vm);
    lua_push_str_table_entry(vm, "public_key", server_public_key);
    lua_pushstring(vm, "encryption");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* **************************************************** */

void ZMQCollectorInterface::purgeIdle(time_t when, bool force_idle, bool full_scan) {
  NetworkInterface::purgeIdle(when, force_idle, full_scan);

  for(std::map<u_int64_t, NetworkInterface*>::iterator it = flowHashing.begin(); it != flowHashing.end(); ++it)
    it->second->purgeIdle(when, force_idle, full_scan);
}

#endif
