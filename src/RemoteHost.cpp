/*
 *
 * (C) 2013-21 - ntop.org
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

RemoteHost::RemoteHost(NetworkInterface *_iface, Mac *_mac, VLANid _vlanId,
		       u_int16_t _observation_point_id, IpAddress *_ip)
  : Host(_iface, _mac, _vlanId, _observation_point_id, _ip) {
#ifdef REMOTEHOST_DEBUG
  char buf[48];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Instantiating REMOTE host %s", _ip ? _ip->print(buf, sizeof(buf)) : "");
#endif
  initialize();
}

/* *************************************** */

RemoteHost::RemoteHost(NetworkInterface *_iface, char *ipAddress, VLANid _vlanId, u_int16_t _observation_point_id)
  : Host(_iface, ipAddress, _vlanId, _observation_point_id) {
  initialize();
}

/* *************************************** */

RemoteHost::~RemoteHost() {
}

/* *************************************** */

void RemoteHost::set_hash_entry_state_idle() {
  iface->decNumHosts(false /* A remote host */);

  GenericHashEntry::set_hash_entry_state_idle();
}

/* *************************************** */

void RemoteHost::initialize() {
  char buf[64], host[96];
  char *strIP = ip.print(buf, sizeof(buf));
  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);
  char rsp[256];

  stats = allocateStats();
  updateHostPool(true /* inline with packet processing */, true /* first inc */);

  if(ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
  /* Just ask ntopng to resolve the name. Actual name will be grabbed once needed
     using the getter.
   */    
    ntop->getRedis()->getAddress(host, rsp, sizeof(rsp), true);
  }

  iface->incNumHosts(false /* Remote Host */);
}
