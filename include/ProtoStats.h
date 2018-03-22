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

#ifndef _PROTO_STATS_H_
#define _PROTO_STATS_H_

#include "ntop_includes.h"

class ProtoStats {
 private:
  u_int64_t volatile numPkts, numBytes;

 public:
  ProtoStats();

  inline void reset()                              { numPkts = 0, numBytes = 0; };
  inline void inc(u_int32_t pkts, u_int32_t bytes) { numPkts += pkts, numBytes += bytes; };
  inline u_int64_t getPkts()                       { return(numPkts);  };
  inline u_int64_t getBytes()                      { return(numBytes); };
  inline void setPkts(u_int64_t v)                 { numPkts = v;  };
  inline void setBytes(u_int64_t v)                { numBytes = v; };
  void lua(lua_State *vm, const char *prefix);
  void print(const char *prefix);
  inline void sum(ProtoStats *p) { p->numPkts += numPkts, p->numBytes += numBytes; };
};

#endif /* _PROTO_STATS_H_ */
