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

#include "ntop_includes.h"

/* *************************************** */

StringHost::StringHost(NetworkInterface *_iface, char *_key, 
		       u_int16_t _family_id) : GenericHost(_iface) {
  keyname = strdup(_key), family_id = _family_id;

  /* Purify name */
  for(int i=0; keyname[i] != '\0'; i++)
    if((keyname[i] == '%')
       || (keyname[i] == '"')
       || (keyname[i] == '\''))
      keyname[i] = '_';
  /*
    Set to true if this host can be persistently
    written on disk
  */
  tracked_host = false, queriesReceived = 0;
  mode = aggregation_client_name;
  readStats();
}

/* *************************************** */

StringHost::~StringHost() {
  flushContacts(true);

  dumpStats(ntop->getPrefs()->get_aggregation_mode() == aggregations_enabled_with_bitmap_dump);
  free(keyname);
}

/* *************************************** */

void StringHost::computeHostSerial() {
  if(host_serial) {
    /* We need to reconfirm the id (e.g. after a day wrap) */
    ntop->getRedis()->setHostId(iface, NULL, keyname, host_serial);
  } else
    host_serial = ntop->getRedis()->addHostToDBDump(iface, NULL, keyname);
}

/* *************************************** */

void StringHost::flushContacts(bool freeHost) {
  if(tracked_host) {
    bool _localHost = localHost;

    localHost = true; /* Hack */
    if(!host_serial) computeHostSerial();
    dumpHostContacts(family_id);
    contacts->purgeAll();
    localHost = _localHost;

    if(!freeHost) {
      /*
	Recompute it so that if the day wrapped
	we have a new one
      */
      computeHostSerial();
    }
  } 
}

/* *************************************** */

bool StringHost::idle() {
  if(!iface->is_purge_idle_interface()) return(false);
  return(will_be_purged || isIdle(ntop->getPrefs()->get_host_max_idle(tracked_host))); 
};

/* *************************************** */

void StringHost::lua(lua_State* vm, patricia_tree_t *ptree, bool returnHost) {
  lua_newtable(vm);

  lua_push_str_table_entry(vm, "name", keyname);

  lua_push_int_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_int_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());
  lua_push_int_table_entry(vm, "pkts.sent", sent.getNumPkts());
  lua_push_int_table_entry(vm, "pkts.rcvd", rcvd.getNumPkts());
  lua_push_int_table_entry(vm, "queries.rcvd", queriesReceived);
  lua_push_int_table_entry(vm, "seen.first", first_seen);
  lua_push_int_table_entry(vm, "seen.last", last_seen);
  lua_push_int_table_entry(vm, "duration", get_duration());
  lua_push_int_table_entry(vm, "family", family_id);
  lua_push_bool_table_entry(vm, "tracked", tracked_host);
  lua_push_int_table_entry(vm, "aggregation", mode);
  lua_push_float_table_entry(vm, "throughput_bps", bytes_thpt);
  lua_push_int_table_entry(vm, "throughput_trend_bps", getThptTrend());

  if(ndpiStats) ndpiStats->lua(iface->get_view(), vm);
  getHostContacts(vm, ptree);

  if(returnHost) {
    lua_pushstring(vm, keyname);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool StringHost::addIfMatching(lua_State* vm, char *key) {
  if(strcasestr(host_key(), key)) {
    lua_push_str_table_entry(vm, host_key(), host_key());
    return(true);
  } else
    return(false);
}

/* *************************************** */

char* StringHost::get_string_key(char *buf, u_int buf_len) {
  snprintf(buf, buf_len, "%s", host_key());
  return(buf);
}

