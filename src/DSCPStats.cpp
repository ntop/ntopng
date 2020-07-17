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

#include "ntop_includes.h"

const u_int8_t ds_table[NUM_DS_VALUES] = {
  /* [0] = */ 0,  /* [1] = */ DS_PR_LE,   /* [2] = */ DS_PR_UNKN, /* [3] = */ DS_PR_UNKN, /* [4] = */ DS_PR_UNKN, /* [5] = */ DS_PR_UNKN, /* [6] = */ DS_PR_UNKN, /* [7] = */ DS_PR_UNKN,
  /* [8] = */ 1,  /* [9] = */ DS_PR_UNKN,
  /* [10] = */ 1, /* [11] = */ DS_PR_UNKN,
  /* [12] = */ 1, /* [13] = */ DS_PR_UNKN,
  /* [14] = */ 1, /* [15] = */ DS_PR_UNKN,
  /* [16] = */ 2, /* [17] = */ DS_PR_UNKN,
  /* [18] = */ 2, /* [19] = */ DS_PR_UNKN,
  /* [20] = */ 2, /* [21] = */ DS_PR_UNKN,
  /* [22] = */ 2, /* [23] = */ DS_PR_UNKN,
  /* [24] = */ 3, /* [25] = */ DS_PR_UNKN,
  /* [26] = */ 3, /* [27] = */ DS_PR_UNKN,
  /* [28] = */ 3, /* [29] = */ DS_PR_UNKN,
  /* [30] = */ 3, /* [31] = */ DS_PR_UNKN,
  /* [32] = */ 4, /* [33] = */ DS_PR_UNKN,
  /* [34] = */ 4, /* [35] = */ DS_PR_UNKN,
  /* [36] = */ 4, /* [37] = */ DS_PR_UNKN,
  /* [38] = */ 4, /* [39] = */ DS_PR_UNKN,
  /* [40] = */ 5, /* [41] = */ DS_PR_UNKN, /* [42] = */ DS_PR_UNKN, /* [43] = */ DS_PR_UNKN, /* [44] = */ DS_PR_UNKN, /* [45] = */ DS_PR_UNKN,
  /* [46] = */ 5, /* [47] = */ DS_PR_UNKN,
  /* [48] = */ 6, /* [49] = */ DS_PR_UNKN, /* [50] = */ DS_PR_UNKN, /* [51] = */ DS_PR_UNKN, /* [52] = */ DS_PR_UNKN, /* [53] = */ DS_PR_UNKN, /* [54] = */ DS_PR_UNKN, /* [55] = */ DS_PR_UNKN, /* [56] = */ DS_PR_UNKN, 
  /* [57] = */ 7, /* [58] = */ DS_PR_UNKN, /* [59] = */ DS_PR_UNKN, /* [60] = */ DS_PR_UNKN, /* [61] = */ DS_PR_UNKN, /* [62] = */ DS_PR_UNKN, /* [63] = */ DS_PR_UNKN
};

/* *************************************** */

u_int8_t DSCPStats::ds2Precedence(u_int8_t ds_id) {
  if (ds_id < NUM_DS_VALUES)
    return ds_table[ds_id];
  else
    return DS_PR_UNKN;
}

/* *************************************** */

DSCPStats::DSCPStats() {
  memset(counters, 0, sizeof(counters));
}

/* *************************************** */

DSCPStats::DSCPStats(const DSCPStats &stats) {
  memcpy(counters, stats.counters, sizeof(counters));
}

/* *************************************** */

DSCPStats::~DSCPStats() {
}

/* *************************************** */

void DSCPStats::sum(DSCPStats *stats) const {
  for(int i = 0; i < DS_PRECEDENCE_GROUPS; i++) {
    stats->counters[i].packets.sent  += counters[i].packets.sent;
    stats->counters[i].packets.rcvd  += counters[i].packets.rcvd;
    stats->counters[i].bytes.sent    += counters[i].bytes.sent;
    stats->counters[i].bytes.rcvd    += counters[i].bytes.rcvd;
  }
}

/* *************************************** */

void DSCPStats::print(NetworkInterface *iface) {
  for(int i = 0; i < 8; i++) {
    if(counters[i].bytes.sent || counters[i].bytes.rcvd)
      printf("[%d] [pkts: %llu/%llu][bytes: %llu/%llu]\n", i,
        (long long unsigned) counters[i].packets.sent, (long long unsigned) counters[i].packets.rcvd,
        (long long unsigned) counters[i].bytes.sent,   (long long unsigned) counters[i].bytes.rcvd);
  }
}

/* *************************************** */

void DSCPStats::lua(NetworkInterface *iface, lua_State* vm, bool tsLua) {
  char name[16], buf[64];

  lua_newtable(vm);

  for(u_int8_t i = 0; i < DS_PRECEDENCE_GROUPS; i++) {
    if(counters[i].bytes.sent || counters[i].bytes.rcvd) {
      if(!tsLua) {
        lua_newtable(vm);

        lua_push_uint64_table_entry(vm, "packets.sent", counters[i].packets.sent);
        lua_push_uint64_table_entry(vm, "packets.rcvd", counters[i].packets.rcvd);
        lua_push_uint64_table_entry(vm, "bytes.sent", counters[i].bytes.sent);
        lua_push_uint64_table_entry(vm, "bytes.rcvd", counters[i].bytes.rcvd);

        lua_pushstring(vm, precedence2Name(i, name, sizeof(name)));
        lua_insert(vm, -2);
	lua_rawset(vm, -3);
      } else {

        snprintf(buf, sizeof(buf), "%llu|%llu",
          (unsigned long long)counters[i].bytes.sent,
	  (unsigned long long)counters[i].bytes.rcvd);

	lua_push_str_table_entry(vm, precedence2Name(i, name, sizeof(name)), buf);
      }
    }
  }

  lua_pushstring(vm, "dscp");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void DSCPStats::incStats(u_int16_t ds_id,
			 u_int64_t sent_packets, u_int64_t sent_bytes,
			 u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
  int p = ds2Precedence(ds_id);
  counters[p].packets.sent += sent_packets;
  counters[p].packets.rcvd += rcvd_packets;
  counters[p].bytes.sent += sent_bytes;
  counters[p].bytes.rcvd += rcvd_bytes;
}

/* *************************************** */
  
char *DSCPStats::precedence2Name(u_int8_t p, char *buf, size_t buf_size) {
  if (p < 8)
    snprintf(buf, buf_size, "cs%u", p);
  else if (p == DS_PR_LE)
    snprintf(buf, buf_size, "le");
  else
    snprintf(buf, buf_size, "unknown");
  return buf;
}

/* *************************************** */

void DSCPStats::resetStats() {
  memset(counters, 0, sizeof(counters));
}

/* *************************************** */

