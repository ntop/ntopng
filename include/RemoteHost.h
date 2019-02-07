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

#ifndef _REMOTE_HOST_H_
#define _REMOTE_HOST_H_

#include "ntop_includes.h"

class RemoteHost : public Host {
 private:
  bool remote_to_remote_alerts;
  void initialize();

 public:
  RemoteHost(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip);
  RemoteHost(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  virtual ~RemoteHost();

  virtual bool setRemoteToRemoteAlerts();
  virtual int16_t get_local_network_id() const { return(-1);                };
  virtual bool isLocalHost()  const            { return(false);             };
  virtual bool isSystemHost() const            { return(false);             };
};

#endif /* _REMOTE_HOST_H_ */
