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

#include "ntop_includes.h"

/* ***************************************** */

GenericHashEntry::GenericHashEntry(NetworkInterface *_iface) {
  hash_next = NULL, iface = _iface, first_seen = last_seen = 0;
  num_uses = 0;
  hash_table = NULL;

  hash_entry_state = hash_entry_state_active; /* Default for all but Flow */

  if(iface && iface->getTimeLastPktRcvd() > 0)
    first_seen = last_seen = iface->getTimeLastPktRcvd();
  else
    first_seen = last_seen = time(NULL);
}

/* ***************************************** */

GenericHashEntry::~GenericHashEntry() {
  ;
}

/* ***************************************** */

void GenericHashEntry::updateSeen(time_t _last_seen) {
  last_seen = _last_seen;

  if((first_seen == 0) || (first_seen > last_seen))
    first_seen = last_seen;
}

/* ***************************************** */

void GenericHashEntry::updateSeen() {
  updateSeen(iface->getTimeLastPktRcvd());
}

/* ***************************************** */

void GenericHashEntry::set_state(HashEntryState s) {
  if((s < hash_entry_state /* Can't go back */
      || (s != hash_entry_state + 1 /* Only ahead, one state at time */
	  /* Only exception is for flows, which can go from allocated to protocoldetected without
	     stepping on not yet detected */
	  && !(hash_entry_state == hash_entry_state_allocated && s == hash_entry_state_flow_protocoldetected)))
     && (!iface || iface->isRunning()))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: invalid state transition %d -> %d",
				 hash_entry_state, s);
  else
    hash_entry_state = s;
};

/* ***************************************** */

HashEntryState GenericHashEntry::get_state() const {
  return hash_entry_state;
};

/* ***************************************** */

void GenericHashEntry::periodic_hash_entry_state_update(void *user_data)  {
  if(get_state() == hash_entry_state_idle) {
    if(!idle() && !ntop->getGlobals()->isShutdown()) {
      /* This should never happen */
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Inconsistent state: GenericHashEntry<%p> state=hash_entry_state_idle but idle()=false", this);
    }
  }
}

/* ***************************************** */

void GenericHashEntry::periodic_stats_update(const struct timeval *tv)  {
  GenericTrafficElement *elem;

  if((elem = dynamic_cast<GenericTrafficElement*>(this)))
    elem->updateStats(tv);
}

/* ***************************************** */

bool GenericHashEntry::idle() const {
  return(get_state() > hash_entry_state_active);
};

/* ***************************************** */

bool GenericHashEntry::is_active_entry_now_idle(u_int max_idleness) const {
  bool ret = (((u_int)(iface->getTimeLastPktRcvd()) > (last_seen + max_idleness)) ? true : false);

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() [lastPkt: %u][last_seen: %u][max_idleness: %u][idle: %s]",
			       __FUNCTION__, iface->getTimeLastPktRcvd(), last_seen, max_idleness,
			       ret ? "true" : "false");
#endif

  return(ret);
}

/* ***************************************** */

void GenericHashEntry::deserialize(json_object *o) {
  json_object *obj;

  if(json_object_object_get_ex(o, "seen.first", &obj)) first_seen = json_object_get_int64(obj);

  /* NOTE: do not deserialize the last_seen, as an old timestamp will
   * make this (fresh) entry idle(). */
}

/* ***************************************** */

void GenericHashEntry::getJSONObject(json_object *my_object, DetailsLevel details_level) {
  json_object_object_add(my_object, "seen.first", json_object_new_int64(first_seen));
  json_object_object_add(my_object, "seen.last",  json_object_new_int64(last_seen));
}
