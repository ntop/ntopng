/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef _IEC104_STATS_H_
#define _IEC104_STATS_H_

#include "ntop_includes.h"

class IEC104Stats {
 private:
  struct {
    u_int32_t tx, rx;
  } pkt_lost; /* Counter for packet loss sequences */
  std::unordered_map<u_int16_t, u_int32_t> type_i_transitions;
  std::unordered_map<u_int16_t, u_int32_t> typeid_uses;
  u_int16_t last_type_i;
  struct timeval last_i_apdu;
  struct ndpi_analyze_struct *i_s_apdu;
  u_int16_t tx_seq_num, rx_seq_num;

 public:
  IEC104Stats();
  ~IEC104Stats();

  void processPacket(Flow *f, bool tx_direction,
		     const u_char *payload, u_int16_t payload_len,
		     struct timeval *packet_time);

  void lua(lua_State* vm);
};

#endif /* _IEC104_STATS_H_ */
