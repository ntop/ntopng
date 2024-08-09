/*
 *
 * (C) 2013-24 - ntop.org
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

RemoteHost::RemoteHost(NetworkInterface *_iface, int32_t _iface_idx, Mac *_mac,
                       u_int16_t _u_int16_t, u_int16_t _observation_point_id,
                       IpAddress *_ip)
  : Host(_iface, _iface_idx, _mac, _u_int16_t, _observation_point_id, _ip) {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
#ifdef REMOTEHOST_DEBUG
  char buf[48];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Instantiating REMOTE host %s",
    _ip ? _ip->print(buf, sizeof(buf)) : "");
#endif
  initialize();
}

/* *************************************** */

RemoteHost::RemoteHost(NetworkInterface *_iface, int32_t _iface_idx,
		       char *ipAddress, u_int16_t _u_int16_t,
		       u_int16_t _observation_point_id)
  : Host(_iface, _iface_idx, ipAddress, _u_int16_t, _observation_point_id) {
  initialize();
}

/* *************************************** */

RemoteHost::~RemoteHost() {
  /* Decrease number of active hosts */
  if(isUnicastHost())
  iface->decNumHosts(isLocalHost(), isRxOnlyHost());
}

/* *************************************** */

void RemoteHost::set_hash_entry_state_idle() {
  GenericHashEntry::set_hash_entry_state_idle();
}

/* *************************************** */

/* NOTE: Host::initialize will be called by the constructor after the Host initializator */
void RemoteHost::initialize() {
  char buf[64], host[96];
  char *strIP = ip.print(buf, sizeof(buf));
  char rsp[256];

  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);
  stats = allocateStats();
  updateHostPool(true /* inline with packet processing */,
                 true /* first inc */);

  if (ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
    /* Just ask ntopng to resolve the name. Actual name will be grabbed once
       needed using the getter.
    */
    ntop->getRedis()->getAddress(host, rsp, sizeof(rsp), true);
  }

  if (isUnicastHost())
    iface->incNumHosts(false /* isLocalHost() */, true /* Initialization: bytes are 0, considered RX only */);
}
