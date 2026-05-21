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

BGPPrefixListener::BGPPrefixListener(char *url) {
  void *context = zmq_ctx_new();
  void *sock = zmq_socket(context, ZMQ_SUB);
  const char *topic_filter = "prefix_change";
  size_t filter_len = strlen(topic_filter) + 1;
  
  if(zmq_connect(sock, url) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to connect to ZMQ endpoint %s: %s (%d)", url,
				 strerror(errno), errno);
    zmq_ctx_destroy(context);
    return;
  }

  zmq_setsockopt(sock, ZMQ_SUBSCRIBE, topic_filter, strlen(topic_filter));

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Subscribed to topic %s on %s",
			       topic_filter, url);

  bgp_prefix_polling_active = true;
  
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

      buffer[bytes_received] = '\0';
      message = &buffer[filter_len];
      
      ntop->getRedis()->lpush(BGP_PREFIX_UPDATE_QUEUE_NAME,
			      message, 100 /* max queue lenght */);
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", message);
    } else {
      // No data arrived within the timeout      
    }
  }

  bgp_prefix_polling_active = false;
  zmq_close(sock);
  zmq_ctx_destroy(context);
}

/* *************************************** */

void BGPPrefixListener::termBGPPrefixUpdatesPolling() {
  bgp_prefix_polling_active = false;
}

/* *************************************** */
