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

#ifndef _ZMQ_COLLECTOR_INTERFACE_H_
#define _ZMQ_COLLECTOR_INTERFACE_H_

#include "ntop_includes.h"

#ifndef HAVE_NEDGE

class LuaEngine;

typedef struct {
  char *endpoint;
  void *socket;
} zmq_subscriber;

class ZMQCollectorInterface : public ZMQParserInterface {
 private:
  void *context;
  std::map<u_int8_t, u_int32_t>source_id_last_msg_id;
  bool is_collector;
  u_int8_t num_subscribers;
  zmq_subscriber subscriber[MAX_ZMQ_SUBSCRIBERS];
  char server_public_key[41], server_secret_key[41];
    
#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,1,0)
  char *generateEncryptionKeys();
#endif

 public:
  ZMQCollectorInterface(const char *_endpoint);
  ~ZMQCollectorInterface();

  virtual const char* get_type()      const { return(CONST_INTERFACE_TYPE_ZMQ);      };
  inline char* getEndpoint(u_int8_t id)     { return((id < num_subscribers) ?
						     subscriber[id].endpoint : (char*)""); };
  virtual void checkPointCounters(bool drops_only);
  virtual bool isPacketInterface() const  { return(false);      };
  void collect_flows();

  virtual void purgeIdle(time_t when, bool force_idle = false, bool full_scan = false);

  void startPacketPolling();
  bool set_packet_filter(char *filter);
  virtual void lua(lua_State* vm);
  virtual bool areTrafficDirectionsSupported() { return(true); };
};

#endif /* HAVE_NEDGE */

#endif /* _ZMQ_COLLECTOR_INTERFACE_H_ */

