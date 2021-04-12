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

#ifndef _REMOTE_CONNECTION_H_
#define _REMOTE_CONNECTION_H_

#include "ntop_includes.h"

class RemoteConnection : public HostCallback {
public:
  RemoteConnection();
  ~RemoteConnection() {};

  RemoteConnectionAlert *allocAlert(HostCallback *c, Host *h, AlertLevel severity, u_int8_t cli_score, u_int8_t srv_score, u_int8_t num_remote_access) {
    return new RemoteConnectionAlert(c, h, severity, cli_score, srv_score, num_remote_access);
  };

  bool loadConfiguration(json_object *config);
  void periodicUpdate(Host *h, HostAlert *engaged_alert);
  
  HostCallbackID getID() const { return host_callback_remote_connection; }
  std::string getName()  const { return(std::string("remote_connection")); }
};

#endif
