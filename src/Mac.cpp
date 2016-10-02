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

#include "ntop_includes.h"

/* *************************************** */

Mac::Mac(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId) : GenericHashEntry(_iface) {
  memcpy(mac, _mac, 6), vlan_id = _vlanId;
}

/* *************************************** */

Mac::~Mac() {
  ;
}

/* *************************************** */

bool Mac::isIdle(u_int max_idleness) {
  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);
  
  if(num_uses > 0) return(false);
  
  return(false);
}

/* *************************************** */

bool Mac::idle() {
  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);
  
  return(isIdle(MAX_LOCAL_HOST_IDLE));
}


