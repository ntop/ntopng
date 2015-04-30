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

#ifndef _STRING_HOST_H_
#define _STRING_HOST_H_

#include "ntop_includes.h"

class StringHost : public GenericHost {
 private:
  char *keyname;
  u_int16_t family_id;
  bool tracked_host;
  /* Throughput */
  u_int64_t queriesReceived;
  AggregationType mode;
  void computeHostSerial();

 public:
  StringHost(NetworkInterface *_iface, char *_key, u_int16_t _family_id);
  ~StringHost();
  
  inline AggregationType get_aggregation_mode()       { return(mode);        };
  inline void set_aggregation_mode(AggregationType m) { mode = m;            };
  inline void set_tracked_host(bool tracked)    { tracked_host = tracked; if(!host_serial) computeHostSerial(); };
  inline bool is_tracked_host()                 { return(tracked_host);      };
  inline char* host_key()                       { return(keyname);           };
  inline u_int16_t get_family_id()              { return(family_id);         };
  bool idle();
  void lua(lua_State* vm, patricia_tree_t *ptree, bool returnHost);
  inline u_int32_t key()             { return( Utils::hashString(keyname) ); };
  inline void inc_num_queries_rcvd() { queriesReceived++;                  };
  char* get_string_key(char *buf, u_int buf_len);
  void updateStats(struct timeval *tv);
  void flushContacts(bool freeHost);
  bool addIfMatching(lua_State* vm, char *key);
};

#endif /* _STRING_HOST_H_ */
