/*
 *
 * (C) 2013-17 - ntop.org
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

/* *************************************** */

Mac::Mac(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId) : GenericHashEntry(_iface) {
  memcpy(mac, _mac, 6), vlan_id = _vlanId;
  special_mac = Utils::isSpecialMac(mac);
  if(iface->getTimeLastPktRcvd() > 0)
    first_seen = last_seen = iface->getTimeLastPktRcvd();
  else
    first_seen = last_seen = time(NULL);

  if(ntop->getMacManufacturers())
    manuf = ntop->getMacManufacturers()->getManufacturer(mac);
  else
    manuf = NULL;

#ifdef MANUF_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Assigned manufacturer [mac: %02x:%02x:%02x:%02x:%02x:%02x] [manufacturer: %s]",
			       mac[0], mac[1], mac[2], mac[3], mac[4], mac[5],
			       manuf ? manuf : "- not available -");
#endif

#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created %s/%u [total %u][%s]",
			       Utils::formatMac(mac, buf, sizeof(buf)),
			       vlan_id, iface->getNumL2Devices(),
			       special_mac ? "Special" : "Host");
#endif

  if(!special_mac) iface->incNumL2Devices();
}

/* *************************************** */

Mac::~Mac() {
  /* TODO: decide if it is useful to dump mac stats to redis */
  if(!special_mac) {
    char buf[64], buf1[64], buf2[64], when[16];
    
    iface->decNumL2Devices();

    snprintf(buf, sizeof(buf), CONST_MAC_LAST_SEEN, iface->get_id());
    snprintf(when, sizeof(when), "%u", time(NULL));
    snprintf(buf2, sizeof(buf2), "%s@%d", Utils::formatMac(mac, buf1, sizeof(buf1)), vlan_id);
    ntop->getRedis()->hashSet(buf, buf2, when);
  }

#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted %s/%u [total %u][%s]",
			       Utils::formatMac(mac, buf, sizeof(buf)),
			       vlan_id, iface->getNumL2Devices(),
			       special_mac ? "Special" : "Host");
#endif
}

/* *************************************** */

bool Mac::idle() {
  bool rc;
  
  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);

  rc = isIdle(MAX_LOCAL_HOST_IDLE);

#ifdef DEBUG
  if(true) {
    char buf[32];
    
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Is idle %s/%u [uses %u][%s][last: %u][diff: %d]",
				 Utils::formatMac(mac, buf, sizeof(buf)),
				 vlan_id, num_uses,
				 rc ? "Idle" : "Not Idle",
				 last_seen, iface->getTimeLastPktRcvd() - (last_seen+MAX_LOCAL_HOST_IDLE));
  }
#endif
  
  return(rc);
}

/* *************************************** */

void Mac::lua(lua_State* vm, bool show_details, bool asListElement) {
  char buf[32], *m;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "mac", m = Utils::formatMac(mac, buf, sizeof(buf)));
  lua_push_int_table_entry(vm, "vlan", vlan_id);

  lua_push_int_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_int_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  if(show_details) {
    if(manuf)
      lua_push_str_table_entry(vm, "manufacturer", (char*)manuf);

    lua_push_bool_table_entry(vm, "special_mac", special_mac);
    ((GenericTrafficElement*)this)->lua(vm, show_details);
  }

  lua_push_int_table_entry(vm, "seen.first", first_seen);
  lua_push_int_table_entry(vm, "seen.last", last_seen);
  lua_push_int_table_entry(vm, "duration", get_duration());

  lua_push_int_table_entry(vm,   "num_hosts", getNumHosts());

  if(asListElement) {
    lua_pushstring(vm, m);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool Mac::equal(u_int16_t _vlanId, const u_int8_t _mac[6]) {
  if((vlan_id == _vlanId) && (memcmp(mac, _mac, 6) == 0))
    return(true);
  else
    return(false);
}
