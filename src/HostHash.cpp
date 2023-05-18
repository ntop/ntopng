/*
 *
 * (C) 2013-23 - ntop.org
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

/* ************************************ */

HostHash::HostHash(NetworkInterface *_iface, u_int _num_hashes,
                   u_int _max_hash_size)
    : GenericHash(_iface, _num_hashes, _max_hash_size, "HostHash") {
  num_http_hosts = 0;
}

/* ************************************ */

Host *HostHash::get(u_int16_t vlanId, IpAddress *key, Mac *mac,
                    bool is_inline_call, u_int16_t observation_point_id) {
  u_int32_t hash = (key->key() % num_hashes);

  /* Check if MAC address needs to be used in host key */
  if (ntop->getPrefs()->useMacAddressInFlowKey() == false) mac = NULL;

  if (table[hash] == NULL) {
    return (NULL);
  } else {
    Host *head;

    if (!is_inline_call) locks[hash]->rdlock(__FILE__, __LINE__);

    head = (Host *)table[hash];

    while (head != NULL) {
      if ((!head->idle()) && (head->get_vlan_id() == vlanId) &&
          (head->get_observation_point_id() == observation_point_id) &&
          (head->get_ip() != NULL) && (head->get_ip()->compare(key) == 0) &&
          ((mac == NULL) || (mac == head->getMac())))
        break;
      else
        head = (Host *)head->next();
    }

    if (!is_inline_call) locks[hash]->unlock(__FILE__, __LINE__);

    return (head);
  }
}

/* ************************************ */

void HostHash::incNumHTTPEntries() {
  m.lock(__FILE__, __LINE__);
  num_http_hosts++;
  m.unlock(__FILE__, __LINE__);
}

/* ************************************ */

void HostHash::decNumHTTPEntries() {
  m.lock(__FILE__, __LINE__);
  if (num_http_hosts > 0)
    num_http_hosts--;
  else
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "Internal error: [num_http_hosts=%u]", num_http_hosts);
  m.unlock(__FILE__, __LINE__);
}
