/*
 *
 * (C) 2013-26 - ntop.org
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

/* *************************************** */

static void* startPolling(void* arg) {
  BGPPrefixListener *l = (BGPPrefixListener*)arg;

  l->poll();

  return(NULL);
}

/* *************************************** */

BGPPrefixListener::BGPPrefixListener(char *url) {
  context = zmq_ctx_new();
  if(context == NULL) return;

  sock = zmq_socket(context, ZMQ_SUB);

  if(zmq_connect(sock, url) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to connect to ZMQ endpoint %s: %s (%d)", url,
				 strerror(errno), errno);
    zmq_ctx_destroy(context);
    context = NULL;
    return;
  }

  zmq_setsockopt(sock, ZMQ_SUBSCRIBE, CONST_BGP_PREFIX_TOPIC,
		 strlen(CONST_BGP_PREFIX_TOPIC));

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Subscribed to topic %s on %s",
			       CONST_BGP_PREFIX_TOPIC, url);

  polling = false;

  if(pthread_create(&threadId, nullptr, startPolling, this) != 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to start polling data");
}

/* *************************************** */

BGPPrefixListener::~BGPPrefixListener() {
  termBGPPrefixUpdatesPolling();
  while(is_polling()) sleep(1);

  if(sock)    zmq_close(sock);
  if(context) zmq_ctx_destroy(context);
}

/* *************************************** */

void BGPPrefixListener::termBGPPrefixUpdatesPolling() {
  if(context)
    bgp_prefix_polling_active = false;
}

/* *************************************** */

void BGPPrefixListener::poll() {
  size_t filter_len = strlen(CONST_BGP_PREFIX_TOPIC) + 1;
  if(!context) return;

  bgp_prefix_polling_active = true;
  polling = true;

  while((!ntop->getGlobals()->isShutdown())
	&& (!ntop->getGlobals()->isShutdownRequested())
	&& bgp_prefix_polling_active) {
    // Set up the polling item structure
    zmq_pollitem_t items[] = { { sock, 0, ZMQ_POLLIN, 0 } };

    // Poll the socket. Timeout is in milliseconds (100ms here).
    // Pass -1 to block indefinitely, or 0 to return instantly.
    int rc = zmq_poll(items, 1, 1000 /* 1000 msec */);

    if(rc < 0) {
      /* Polling error occurred */
      break;
    }

    // Check if our specific socket has data waiting to be read
    if (items[0].revents & ZMQ_POLLIN) {
      char buffer[1024], *message;
      int bytes_received = zmq_recv(sock, buffer, sizeof(buffer) - 1, 0);

      if (bytes_received < 0)
	break;

      /* zmq_recv() returns the full message size even when the message did
	 not fit in the buffer, so the copy is truncated at sizeof(buffer)-1
	 but bytes_received can be larger. Clamp it before terminating. */
      if (bytes_received > (int)sizeof(buffer) - 1)
	bytes_received = sizeof(buffer) - 1;

      buffer[bytes_received] = '\0';
      message = &buffer[filter_len];

      ntop->getRedis()->lpush(BGP_PREFIX_UPDATE_QUEUE_NAME,
			      message, 100 /* max queue lenght */);
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", message);
    } else {
      // No data arrived within the timeout
    }
  }

  polling = false;
  bgp_prefix_polling_active = false;
}
