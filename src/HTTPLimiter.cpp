/*
 *
 * (C) 2017 - ntop.org
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

HTTPlimiter::HTTPlimiter() {
  mutex = new Mutex();
  active_threads = 0;
  active_websockets = 0;
  if((active_hosts = (ActiveRemoteWebHost*)calloc(Utils::getNumHTTPServerThreads(), sizeof(ActiveRemoteWebHost))) == NULL)
    throw "Not enough memory";
}

HTTPlimiter::~HTTPlimiter() {
  if(active_hosts) free(active_hosts);
  delete mutex;
}

bool HTTPlimiter::connectHost(uint32_t ip, int port, bool is_websocket) {
  bool success = true;

  mutex->lock(__FILE__, __LINE__);

  if (((is_websocket) && (active_websockets >= Utils::getNumHTTPWebSocketServerThreads()))
      || (active_threads >= Utils::getNumHTTPServerThreads())) {
    success = false;
  } else {
    int num_hits = 0;
    for (int i=0; i<active_threads; i++) {
      if (active_hosts[i].ip == ip)
        num_hits++;
    }

    if (num_hits >= Utils::getMaxNumHTTPServerThreadsPerHost())
      success = false;
  }

  if (success) {
    active_hosts[active_threads].ip = ip;
    active_hosts[active_threads].port = port;

    if (is_websocket) {
      active_hosts[active_threads].websocket = true;
      active_websockets++;
    } else {
      active_hosts[active_threads].websocket = false;
    }
    
    active_threads++;
  }

  mutex->unlock(__FILE__, __LINE__);

  return success;
}

void HTTPlimiter::disconnectHost(uint32_t ip, int port) {
  mutex->lock(__FILE__, __LINE__);

  for (int i=0; i<active_threads; i++) {
    if ((active_hosts[i].ip == ip) && (active_hosts[i].port == port)) {
      bool is_websocket = active_hosts[i].websocket;

      if (i < active_threads - 1)
        memmove(&active_hosts[i], &active_hosts[i+1], (active_threads - i - 1) * sizeof(active_hosts[0]));

      active_threads--;

      if (is_websocket)
        active_websockets--;

      break;
    }
  }

  mutex->unlock(__FILE__, __LINE__);
}
