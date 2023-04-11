/*
 *
 * (C) 2014-23 - ntop.org
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

#ifndef _RADIUS_
#define _RADIUS_

#include "ntop_includes.h"

#ifdef HAVE_RADIUS

class Radius {
 private:
  int result;
  char *radiusServer, *radiusSecret, *authServer, *radiusAdminGroup,
      *radiusUnprivCapabilitiesGroup;
  char dict_path[MAX_RADIUS_LEN];

  bool buildConfiguration(rc_handle *rh);
  bool addBasicConfigurationAcct(rc_handle *rh, VALUE_PAIR *send, const char *status_type, const char *username, const char *session_id);
  bool addUpdateConfigurationAcct(rc_handle *rh, VALUE_PAIR *send, Host *h);
 public:
  Radius();
  ~Radius();

  bool updateLoginInfo();

  bool authenticate(const char *user, const char *password,
                    bool *has_unprivileged_capabilities, bool *is_admin);
  bool startSession(const char *username, const char *session_id);
  bool stopSession(const char *username, const char *session_id, Host *h);
  bool updateSession(const char *username, const char *session_id, Host *h);
};

#endif

#endif