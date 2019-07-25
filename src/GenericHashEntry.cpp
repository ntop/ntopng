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

/* ***************************************** */

GenericHashEntry::GenericHashEntry(NetworkInterface *_iface) {
  hash_next = NULL, iface = _iface, first_seen = last_seen = 0, num_uses = 0;

  hash_entry_state = hash_entry_state_active;
  
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

HashEntryState GenericHashEntry::get_state() const {
  if(iface && !iface->isRunning()) /* When the interface is no longer running it is safe to assume the entry is idle */
    return hash_entry_state_idle;

  return hash_entry_state;
};

/* ***************************************** */

bool GenericHashEntry::idle() {
  return get_state() != hash_entry_state_active;
};

/* ***************************************** */

bool GenericHashEntry::isIdle(u_int max_idleness) {
  return((((u_int)(iface->getTimeLastPktRcvd()) > (last_seen + max_idleness)) ? true : false));
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
