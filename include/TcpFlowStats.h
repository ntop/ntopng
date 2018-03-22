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

#ifndef _TCP_FLOW_STATS_H_
#define _TCP_FLOW_STATS_H_

#include "ntop_includes.h"

class TcpFlowStats {
 private:
  u_int32_t numSynFlows, numEstablishedFlows, numResetFlows, numFinFlows;

 public:
  TcpFlowStats();
  
  inline void incSyn()         { numSynFlows++;    }
  inline void incEstablished() { numEstablishedFlows++; }
  inline void incReset()       { numResetFlows++;       }
  inline void incFin()         { numFinFlows++;         }

  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();
  void lua(lua_State* vm, const char *label);
  inline void sum(TcpFlowStats *s) {
    s->numSynFlows += numSynFlows, s->numEstablishedFlows += numEstablishedFlows,
      s->numResetFlows += numResetFlows, s->numFinFlows += numFinFlows;
  };
};

#endif /* _TCP_FLOW_STATS_H_ */
