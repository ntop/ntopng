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

/* *************************************** */

Radius::Radius() {
  result = 0;
  radiusServer = radiusSecret = authServer = radiusAdminGroup =
      radiusUnprivCapabilitiesGroup = NULL;

  /* Check if some information are already stored in redis */
  updateLoginInfo();
}

/* *************************************** */

Radius::~Radius() {
  if (radiusAdminGroup) free(radiusAdminGroup);
  if (radiusUnprivCapabilitiesGroup) free(radiusUnprivCapabilitiesGroup);
  if (radiusServer) free(radiusServer);
  if (radiusSecret) free(radiusSecret);
  if (authServer) free(authServer);
}

/* *************************************** */

bool Radius::authenticate(const char *user, const char *password,
                          bool *has_unprivileged_capabilities, bool *is_admin) {
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL, *received = NULL;

  if (!radiusServer || !radiusSecret || !authServer ||
      !radiusUnprivCapabilitiesGroup || !radiusAdminGroup) {
    /* No info currently saved, try to load from redis */
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Initialization Failed");
    goto radius_auth_out;
  }

  if (!radiusServer[0] || !radiusSecret[0]) {
    if (!updateLoginInfo()) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Radius: no radius server or secret set !");
      goto radius_auth_out;
    }
  }

  snprintf(authServer, MAX_RADIUS_LEN - 1, "%s:%s", radiusServer, radiusSecret);

  /* NOTE: this is an handle to the radius lib. It will be passed to multiple
   * functions and cleaned up at the end.
   * https://github.com/FreeRADIUS/freeradius-client/blob/master/src/radembedded.c
   */
  rh = rc_new();
  if (rh == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to allocate memory");
    goto radius_auth_out;
  }

  /* ****************************** */

  /* rh initialization, initialize the 'Radius Header' with all the key-value
   * required */
  rh = rc_config_init(rh);

  if (rh == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: failed to init configuration");
    goto radius_auth_out;
  }

  /* RADIUS authorization checks, in case of fail, return false */
  if (rc_add_config(rh, "auth_order", "radius", "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set auth_order");
    goto radius_auth_out;
  }

  if (rc_add_config(rh, "radius_retries", "3", "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set retries config");
    goto radius_auth_out;
  }

  if (rc_add_config(rh, "radius_timeout", "5", "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set timeout config");
    goto radius_auth_out;
  }

  snprintf(dict_path, sizeof(dict_path), "%s/other/radcli_dictionary.txt",
           ntop->getPrefs()->get_docs_dir());
  if (rc_add_config(rh, "dictionary", dict_path, "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set dictionary config");
    goto radius_auth_out;
  }

  if (rc_add_config(rh, "authserver", authServer, "config", 0) != 0) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Radius: Unable to set authserver config: \"%s\"",
        authServer);
    goto radius_auth_out;
  }

#ifdef HAVE_RC_TEST_CONFIG
  /* Necessary since radcli release 1.2.10 */
  if (rc_test_config(rh, "ntopng") != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: rc_test_config failed");
    goto radius_auth_out;
  }
#endif

  if (rc_read_dictionary(rh, rc_conf_str(rh, "dictionary")) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to read dictionary");
    goto radius_auth_out;
  }

  if (rc_avpair_add(rh, &send, PW_USER_NAME, user, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set username");
    goto radius_auth_out;
  }

  if (rc_avpair_add(rh, &send, PW_USER_PASSWORD, password, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set password");
    goto radius_auth_out;
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Radius: performing auth for user %s", user);

  /* ****************************** */

  /* Check the authentication */
  result = rc_auth(rh, 0, send, &received, NULL);

  if (result == OK_RC) {
    /* Auth is OK */

    if ((radiusAdminGroup[0] != '\0') ||
        (radiusUnprivCapabilitiesGroup[0] != '\0')) {
      VALUE_PAIR *vp = received;
      char name[sizeof(vp->name)];
      char value[sizeof(vp->strvalue)];

      while (vp != NULL) {
        if (rc_avpair_tostr(rh, vp, name, sizeof(name), value, sizeof(value)) ==
            0) {
          /* The "Filter-Id" attribute is used to set user privileges */
          if (strcmp(name, "Filter-Id") == 0) {
            if (strcmp(value, radiusAdminGroup) == 0)
              *is_admin = true;
            else if (strcmp(value, radiusUnprivCapabilitiesGroup) == 0)
              *has_unprivileged_capabilities = true;

            break; /* We care only about "Filter-Id" */
          }
        }

        vp = vp->next;
      }
    }

    radius_ret = true;
  } else {
    /* Do not display messages for user 'admin' */

    if (strcmp(user, "admin")) {
      switch (result) {
        case TIMEOUT_RC:
          ntop->getTrace()->traceEvent(
              TRACE_WARNING, "Radius Authentication timeout for user \"%s\"",
              user);
          break;
        case REJECT_RC:
          ntop->getTrace()->traceEvent(
              TRACE_WARNING, "Radius Authentication rejected for user \"%s\"",
              user);
          break;
        default:
          ntop->getTrace()->traceEvent(
              TRACE_WARNING, "Radius Authentication failure[%d]: user \"%s\"",
              result, user);
      }
    }
  }

radius_auth_out:
  if (rh) rc_destroy(rh);
  if (send) rc_avpair_free(send);
  if (received) rc_avpair_free(received);

  return radius_ret;
}

/* *************************************** */

bool Radius::updateLoginInfo() {
  /* Allocation failed, do not authenticate, exit */
  if (((!radiusServer) &&
       !(radiusServer = (char *)calloc(sizeof(char), MAX_RADIUS_LEN))) ||
      ((!radiusSecret) &&
       !(radiusSecret = (char *)calloc(sizeof(char), MAX_SECRET_LENGTH + 1))) ||
      ((!radiusAdminGroup) &&
       !(radiusAdminGroup = (char *)calloc(sizeof(char), MAX_RADIUS_LEN))) ||
      ((!radiusUnprivCapabilitiesGroup) &&
       !(radiusUnprivCapabilitiesGroup =
             (char *)calloc(sizeof(char), MAX_RADIUS_LEN))) ||
      ((!authServer) &&
       !(authServer = (char *)calloc(sizeof(char), MAX_RADIUS_LEN)))) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to allocate memory");
    return false;
  }

  if (!ntop->getRedis()) return false;

  /* Allocation failed, do not authenticate */
  ntop->getRedis()->get((char *)PREF_RADIUS_SERVER, radiusServer,
                        MAX_RADIUS_LEN);
  ntop->getRedis()->get((char *)PREF_RADIUS_SECRET, radiusSecret,
                        MAX_SECRET_LENGTH + 1);
  ntop->getRedis()->get((char *)PREF_RADIUS_ADMIN_GROUP, radiusAdminGroup,
                        MAX_RADIUS_LEN);
  ntop->getRedis()->get((char *)PREF_RADIUS_UNPRIV_CAP_GROUP,
                        radiusUnprivCapabilitiesGroup, MAX_RADIUS_LEN);

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Radius: server - %s | secret - %s | admin "
                               "group - %s | capabilities group - %s",
                               radiusServer, radiusSecret, radiusAdminGroup,
                               radiusUnprivCapabilitiesGroup);

  return true;
}

bool Radius::startSession() { return true; }

/* *************************************** */

bool Radius::stopSession() { return true; }

/* *************************************** */

bool Radius::updateSession() { return true; }

/* *************************************** */
