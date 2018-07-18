/*
 *
 * (C) 2013-18 - ntop.org
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

RemoteHost::RemoteHost(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip) : Host(_iface, _mac, _vlanId, _ip) {
#ifdef REMOTEHOST_DEBUG
  char buf[48];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Instantiating REMOTE host %s", _ip ? _ip->print(buf, sizeof(buf)) : "");
#endif
  initialize();
}

/* *************************************** */

RemoteHost::RemoteHost(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId) : Host(_iface, ipAddress, _vlanId) {

}

/* *************************************** */

RemoteHost::~RemoteHost() {
}

/* *************************************** */

void RemoteHost::initialize() {
  char buf[64], host[96];
  char *strIP = ip.print(buf, sizeof(buf));
  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);
  char rsp[256];

  blacklisted_host = false,
    trafficCategory[0] = '\0';

  if(ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
    if(ntop->getRedis()->getAddress(host, rsp, sizeof(rsp), true) == 0)
      setName(rsp);
  }

  blacklisted_host = ntop->isBlacklistedIP(&ip);

  if((!blacklisted_host) && ntop->getPrefs()->is_httpbl_enabled() && ip.isIPv4()) {
    // http:bl only works for IPv4 addresses
    if(ntop->getRedis()->getAddressTrafficFiltering(host, iface, trafficCategory,
						    sizeof(trafficCategory), true) == 0) {
      if(strcmp(trafficCategory, NULL_BL)) {
	blacklisted_host = true;
      }
    }
  }

  iface->incNumHosts(false /* Remote Host */);
}

/* ***************************************** */

void RemoteHost::refreshHTTPBL() {
  if(ip.isIPv4()
     && (trafficCategory[0] == '\0')
     && ntop->get_httpbl()) {
    char buf[128] =  { 0 };
    char* ip_addr = ip.print(buf, sizeof(buf));

    ntop->get_httpbl()->findCategory(ip_addr, trafficCategory, sizeof(trafficCategory), false);
  }
}
