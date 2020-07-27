/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _DSCP_STATS_H_
#define _DSCP_STATS_H_

#include "ntop_includes.h"

#define DS_PRECEDENCE_GROUPS 10 /* CS 0..7, LE, Unknown */
#define DS_PR_LE              8
#define DS_PR_UNKN            9

#define NUM_DS_VALUES        64

/* *************************************** */

typedef struct {
  u_int64_t sent, rcvd;
} DSCPDirectionsCounter;

typedef struct {
  DSCPDirectionsCounter packets, bytes;
} DSCPCounter;

class NetworkInterface;

/* *************************************** */

class DSCPStats {
 private:
  DSCPCounter counters[DS_PRECEDENCE_GROUPS];

  u_int8_t ds2Precedence(u_int8_t ds_id);
  char *precedence2Name(u_int8_t p, char *buf, size_t buf_size);

 public:
  DSCPStats();
  DSCPStats(const DSCPStats &stats);
  ~DSCPStats();

  void updateStats(const struct timeval *tv);

  void incStats(u_int16_t ds_id,
		u_int64_t sent_packets, u_int64_t sent_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes);

  void print(NetworkInterface *iface);
  void lua(NetworkInterface *iface, lua_State* vm, bool tsLua = false);
  void sum(DSCPStats *s) const;
  void resetStats();
};

#endif /* _DSCP_STATS_H_ */
