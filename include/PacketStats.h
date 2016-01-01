/*
 *
 * (C) 2013-16 - ntop.org
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

#ifndef _PACKETS_STATS_H_
#define _PACKETS_STATS_H_

#include "ntop_includes.h"

class PacketStats {
 private:
  u_int64_t upTo64, upTo128, upTo256,
    upTo512, upTo1024, upTo1518,
    upTo2500, upTo6500, upTo9000,
    above9000;

 public:
  PacketStats();
  
  void incStats(u_int pkt_len);  
  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();
  void lua(lua_State* vm, const char *label);
};

#endif /* _PACKETS_STATS_H_ */
