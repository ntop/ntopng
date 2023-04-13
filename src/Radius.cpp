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

/* Include the code only if the user has radius */
#ifdef HAVE_RADIUS

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

bool Radius::buildConfiguration(rc_handle **rh) {
  if (!radiusServer || !radiusSecret || !authServer ||
      !radiusUnprivCapabilitiesGroup || !radiusAdminGroup) {
    /* No info currently saved, try to load from redis */
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Initialization Failed");
    return false;
  }

  if (!radiusServer[0] || !radiusSecret[0]) {
    /* Try to check if the info are */
    if (!updateLoginInfo()) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Radius: no radius server or secret set !");
      return false;
    }
  }

  snprintf(authServer, MAX_RADIUS_LEN - 1, "%s:%s", radiusServer, radiusSecret);

  /* If the header is NULL try to init it, otherwise fails */
  if (*rh == NULL)
    *rh = rc_new();

  if (*rh == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to allocate memory");
    return false;
  }

  /* rh initialization, initialize the 'Radius Header' with all the key-value
   * required */
  *rh = rc_config_init(*rh);

  if (*rh == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: failed to init configuration");
    return false;
  }

  /* RADIUS authorization checks, in case of fail, return false */
  if (rc_add_config(*rh, "auth_order", "radius", "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set auth_order");
    return false;
  }

  if (rc_add_config(*rh, "radius_retries", "3", "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set retries config");
    return false;
  }

  if (rc_add_config(*rh, "radius_timeout", "5", "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set timeout config");
    return false;
  }

  snprintf(dict_path, sizeof(dict_path), "%s/other/radcli_dictionary.txt",
           ntop->getPrefs()->get_docs_dir());
  if (rc_add_config(*rh, "dictionary", dict_path, "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Unable to set dictionary config");
    return false;
  }

  if (rc_add_config(*rh, "authserver", authServer, "config", 0) != 0) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Radius: Unable to set authserver config: \"%s\"",
        authServer);
    return false;
  }

#ifdef HAVE_RC_TEST_CONFIG
  /* Necessary since radcli release 1.2.10 */
  if (rc_test_config(*rh, "ntopng") != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: rc_test_config failed");
    return false;
  }
#endif

  if (rc_read_dictionary(*rh, rc_conf_str(*rh, "dictionary")) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to read dictionary");
    return false;
  }

  return true;
}

/* *************************************** */

/* Performs the basic configuration for the accounting, Status type, service, username and session id */
bool Radius::addBasicConfigurationAcct(rc_handle **rh, VALUE_PAIR **send, const char *status_type, const char *username, const char *session_id) {
  if (rc_avpair_add(*rh, send, PW_ACCT_STATUS_TYPE, status_type, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Status Type");
    return false;
  }

  if (rc_avpair_add(*rh, send, PW_SERVICE_TYPE, RADIUS_ACCT_SERVICE_TYPE, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Service Type");
    return false;
  }

  if (rc_avpair_add(*rh, send, PW_USER_NAME, username, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set username");
    return false;
  }

  if (rc_avpair_add(*rh, send, PW_ACCT_SESSION_ID, session_id, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Session ID");
    return false;
  }

  return true;
}

/* *************************************** */

/* Performs the basic configuration for the accounting, Status type, service, username and session id */
bool Radius::addUpdateConfigurationAcct(rc_handle **rh, VALUE_PAIR **send, Host *h) {
  char data[64];
  if(!h) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Host NULL");
    return false;
  }
  
  snprintf(data, sizeof(data), "%lu", h->get_last_seen() - h->get_first_seen());
  if (rc_avpair_add(*rh, send, PW_ACCT_SESSION_TIME, data, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Session Time");
    return false;
  }

  snprintf(data, sizeof(data), "%lu", h->getNumPktsRcvd());
  if (rc_avpair_add(*rh, send, PW_ACCT_INPUT_PACKETS, data, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Input Packets");
    return false;
  }

  snprintf(data, sizeof(data), "%lu", h->getNumPktsSent());
  if (rc_avpair_add(*rh, send, PW_ACCT_OUTPUT_PACKETS, data, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Output Packets");
    return false;
  }

  snprintf(data, sizeof(data), "%lu", h->getNumBytesRcvd());
  if (rc_avpair_add(*rh, send, PW_ACCT_INPUT_OCTETS, data, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Bytes Received");
    return false;
  }

  snprintf(data, sizeof(data), "%lu", h->getNumBytesSent());
  if (rc_avpair_add(*rh, send, PW_ACCT_OUTPUT_OCTETS, data, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Bytes Sent");
    return false;
  }

  return true;
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

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "Radius: server - %s | secret - %s | admin "
                               "group - %s | capabilities group - %s",
                               radiusServer, radiusSecret, radiusAdminGroup,
                               radiusUnprivCapabilitiesGroup);

  return true;
}

/* *************************************** */

bool Radius::authenticate(const char *user, const char *password,
                          bool *has_unprivileged_capabilities, bool *is_admin) {
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL, *received = NULL;

  if(!buildConfiguration(&rh)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Configuration Failed");
    goto radius_auth_out;
  }

  /* NOTE: this is an handle to the radius lib. It will be passed to multiple
   * functions and cleaned up at the end.
   * https://github.com/FreeRADIUS/freeradius-client/blob/master/src/radembedded.c
   */

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

bool Radius::startSession(const char *username, const char *session_id) { 
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL;

  if(!buildConfiguration(&rh)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Configuration Failed");
    goto radius_auth_out;
  }

  if(!addBasicConfigurationAcct(&rh, &send, RADIUS_ACCT_STATUS_TYPE_START, username, session_id)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }
  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Radius: performing accounting start for: %s", username);

  /* ****************************** */

  /* Check the accounting */
  result = rc_acct(rh, 0, send);

  if (result == OK_RC) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Radius: Accounting start Succedeed");
    radius_ret = true;
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting start failed with result: %d", result);
  }

radius_auth_out:
  if (rh) rc_destroy(rh);
  if (send) rc_avpair_free(send);

  return radius_ret; 
}

/* *************************************** */

bool Radius::updateSession(const char *username, const char *session_id, Host *h) { 
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL;

  /* Init the configuration */
  if(!buildConfiguration(&rh)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Configuration Failed");
    goto radius_auth_out;
  }

  /* Create the basic configuration, used by the accounting */
  if(!addBasicConfigurationAcct(&rh, &send, RADIUS_ACCT_STATUS_TYPE_UPDATE, username, session_id)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  /* Add to the dictionary the interim-update data (needed even in the stop) */
  if(!addUpdateConfigurationAcct(&rh, &send, h)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Radius: performing accounting interim-update for: %s", username);

  /* ****************************** */

  /* Check the accounting */
  result = rc_acct(rh, 0, send);

  if (result == OK_RC) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Radius: Accounting start Succedeed");
    radius_ret = true;
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting start failed with result: %d", result);
  }

radius_auth_out:
  if (rh) rc_destroy(rh);
  if (send) rc_avpair_free(send);

  return radius_ret; 
}

/* *************************************** */

bool Radius::stopSession(const char *username, const char *session_id, Host *h) { 
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL;
  
  if(!h) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Host NULL");
    return false;
  }

  /* Init the configuration */
  if(!buildConfiguration(&rh)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Configuration Failed");
    goto radius_auth_out;
  }

  /* Create the basic configuration, used by the accounting */
  if(!addBasicConfigurationAcct(&rh, &send, RADIUS_ACCT_STATUS_TYPE_STOP, username, session_id)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  /* Add to the dictionary the interim-update data (needed even in the stop) */
  if(!addUpdateConfigurationAcct(&rh, &send, h)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  /* TODO: Change the terminate clause to the correct one */
  if (rc_avpair_add(rh, &send, PW_ACCT_TERMINATE_CAUSE, "No More Allowed", -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Bytes Sent");
    return false;
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Radius: performing accounting stop for: %s", username);

  /* ****************************** */

  /* Check the accounting */
  result = rc_acct(rh, 0, send);

  if (result == OK_RC) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Radius: Accounting start Succedeed");
    radius_ret = true;
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting start failed with result: %d", result);
  }

radius_auth_out:
  if (rh) rc_destroy(rh);
  if (send) rc_avpair_free(send);

  return radius_ret; 
}

/* *************************************** */

#endif