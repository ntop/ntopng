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

#ifndef _HTTP_LIMITER_H_
#define _HTTP_LIMITER_H_

#include "ntop_includes.h"

class HTTPlimiter {
  private:
    Mutex *mutex;
    int active_threads;
    int active_websockets;
    struct {
      uint32_t ip;
      int port;
      bool websocket;
    } active_hosts[HTTP_SERVER_NUM_THREADS];

  public:
    HTTPlimiter();
    ~HTTPlimiter();

    bool connectHost(uint32_t ip, int port, bool is_websocket);
    void disconnectHost(uint32_t ip, int port);    
};

#endif
