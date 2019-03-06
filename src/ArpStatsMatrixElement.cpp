/*
 *
 * (C) 2013-19 - ntop.org
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

ArpStatsMatrixElement::ArpStatsMatrixElement(NetworkInterface *_iface, const u_int8_t _src_mac[6],
	 const u_int8_t _dst_mac[6] ): GenericHashEntry(_iface) {
  memcpy(src_mac, _src_mac, 6);
  memcpy(dst_mac, _dst_mac, 6);
  memset(&stats, 0, sizeof(stats));

#ifdef ARP_STATS_MATRIX_ELEMENT_DEBUG
  char buf1[32], buf2[32];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "ADDED ArpMatrixElement: SourceMac %s - DestinationMac %s",
			       Utils::formatMac(src_mac, buf1, sizeof(buf1)),
			       Utils::formatMac(dst_mac, buf2, sizeof(buf2)));
#endif
}

/* *************************************** */

ArpStatsMatrixElement::~ArpStatsMatrixElement(){
#ifdef ARP_STATS_MATRIX_ELEMENT_DEBUG
  char buf1[32], buf2[32];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "DELETED ArpMatrixElement: SourceMac %s - DestinationMac %s",
			       Utils::formatMac(src_mac, buf1, sizeof(buf1)),
			       Utils::formatMac(dst_mac, buf2, sizeof(buf2)));
#endif

}

/* *************************************** */

bool ArpStatsMatrixElement::idle() {
  bool rc;

  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);

  rc = isIdle(MAX_LOCAL_HOST_IDLE);

  return(rc);
}

/* *************************************** */

bool ArpStatsMatrixElement::equal(const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6]) const {
  if(!_src_mac || !_dst_mac)
    return false;

  if(memcmp(src_mac, _src_mac, 6) == 0 && memcmp(dst_mac, _dst_mac, 6) == 0)
    return true;

  else if(memcmp(src_mac, _dst_mac, 6) == 0 && memcmp(dst_mac, _src_mac, 6) == 0) {
    return true;
  }
  else
    return false;
}

/* *************************************** */

u_int32_t ArpStatsMatrixElement::key() {
  return Utils::macHash(src_mac) + Utils::macHash(dst_mac);
}

/* *************************************** */

void ArpStatsMatrixElement::lua(lua_State* vm) {
  char buf1[32], buf2[32];
  char table_key[sizeof(buf1) + sizeof(buf1) + 2] = {0};

  lua_newtable(vm);

  Utils::formatMac(src_mac, buf1, sizeof(buf1));
  Utils::formatMac(dst_mac, buf2, sizeof(buf2));

  lua_push_uint64_table_entry(vm, "sent.requests", stats.sent.requests);
  lua_push_uint64_table_entry(vm, "rcvd.requests", stats.rcvd.requests);
  lua_push_uint64_table_entry(vm, "sent.replies", stats.sent.replies);
  lua_push_uint64_table_entry(vm, "rcvd.replies", stats.rcvd.replies);

  snprintf(table_key, sizeof(table_key), "%s.%s", buf1, buf2);

  lua_pushstring(vm, table_key);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
