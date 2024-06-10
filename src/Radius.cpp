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

/* Include the code only if the user has radius */
#ifdef HAVE_RADIUS

/* *************************************** */

Radius::Radius(bool _use_chap) {
  /*
    https://it.wikipedia.org/wiki/Password_authentication_protocol
    https://en.wikipedia.org/wiki/Challenge-Handshake_Authentication_Protocol
  */
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
  result = 0, use_chap = _use_chap; /* true = CHAP, false = PAP */
  radiusAuthServer = radiusAcctServer = radiusSecret = radiusAdminGroup =
    radiusUnprivCapabilitiesGroup = NULL;

  /* Check if some information are already stored in redis */
  updateLoginInfo();
}

/* *************************************** */

Radius::~Radius() {
  if (radiusAdminGroup) free(radiusAdminGroup);
  if (radiusUnprivCapabilitiesGroup) free(radiusUnprivCapabilitiesGroup);
  if (radiusAuthServer) free(radiusAuthServer);
  if (radiusAcctServer) free(radiusAcctServer);
  if (radiusSecret) free(radiusSecret);
}

/* *************************************** */

bool Radius::buildConfiguration(rc_handle **rh) {
  char server[MAX_RADIUS_LEN];
    
  if (!radiusAuthServer
      || !radiusAcctServer
      || !radiusSecret
      || !radiusUnprivCapabilitiesGroup || !radiusAdminGroup) {
    /* No info currently saved, try to load from redis */
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Initialization Failed");
    return false;
  }

  if (!radiusAuthServer[0] || !radiusSecret[0]) {
    /* Try to check if the info are */
    if (!updateLoginInfo()) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Radius: no radius server or secret set !");
      return false;
    }
  }

  /* If the header is NULL try to init it, otherwise fails */
  if (*rh == NULL) *rh = rc_new();

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

  snprintf(server, sizeof(server), "%s:%s", radiusAcctServer, radiusSecret);
  if (rc_add_config(*rh, "acctserver", server, "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Unable to set acctserver config: \"%s\"",
				 radiusAcctServer);
    return false;
  }

  snprintf(server, sizeof(server), "%s:%s", radiusAuthServer, radiusSecret);
  if (rc_add_config(*rh, "authserver", server, "config", 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Unable to set authserver config: \"%s\"",
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

/* Performs the basic configuration for the accounting, Status type, service,
 * username and session id */
bool Radius::addBasicConfigurationAcct(rc_handle *rh, VALUE_PAIR **send,
                                       u_int32_t status_type,
                                       RadiusTraffic *info) {
  if (rc_avpair_add(rh, send, PW_ACCT_STATUS_TYPE, &status_type, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Status Type");
    return false;
  }

  if(info->username) {
    if (rc_avpair_add(rh, send, PW_USER_NAME, info->username, -1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set username");
      return false;
    }
  }

/*
  if(info->session_id) {
    if (rc_avpair_add(rh, send, PW_ACCT_SESSION_ID, info->session_id, -1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                  "Radius: unable to set Session ID");
      return false;
    }
  }
*/
  if(info->last_ip) {
    u_int32_t addr = ntohl(inet_addr(info->last_ip));
    if (rc_avpair_add(rh, send, PW_FRAMED_IP_ADDRESS, &(addr), -1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set IP Address");
      return false;
    }
  }

  if(info->mac) {
    if (rc_avpair_add(rh, send, PW_CALLING_STATION_ID, info->mac, -1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set MAC Address");
      return false;
    }
  }

  if(info->nas_port_name) {
    if (rc_avpair_add(rh, send, PW_NAS_PORT_ID_STRING, info->nas_port_name, -1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set Nas Port Name");
      return false;
    }
  }

  if (rc_avpair_add(rh, send, PW_NAS_PORT, &(info->nas_port_id), -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Nas Port ID");
    return false;
  }

  return true;
}

/* *************************************** */

/* Performs the basic configuration for the accounting, Status type, service,
 * username and session id */
bool Radius::addUpdateConfigurationAcct(rc_handle *rh, VALUE_PAIR **send,
                                        RadiusTraffic *info) {
  if (!info) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: info not found");
    return false;
  }

  time_t now = time(NULL);

  if (rc_avpair_add(rh, send, PW_EVENT_TIMESTAMP, &now, -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Event Timestamp");
    return false;
  }

  if (rc_avpair_add(rh, send, PW_ACCT_INPUT_PACKETS, &(info->packets_rcvd), -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Input Packets");
    return false;
  }

  if (rc_avpair_add(rh, send, PW_ACCT_OUTPUT_PACKETS, &(info->packets_sent), -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Output Packets");
    return false;
  }

  if (rc_avpair_add(rh, send, PW_ACCT_INPUT_OCTETS, &(info->bytes_rcvd), -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Bytes Received");
    return false;
  }

  if (rc_avpair_add(rh, send, PW_ACCT_OUTPUT_OCTETS, &(info->bytes_sent), -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Bytes Sent");
    return false;
  }

  if (rc_avpair_add(rh, send, PW_ACCT_SESSION_TIME, &(info->time), -1, 0) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to set Accounting Session Time");
    return false;
  }

  return true;
}

/* *************************************** */

bool Radius::updateLoginInfo() {
  /* Allocation failed, do not authenticate, exit */
  if (
      ((!radiusAuthServer) && !(radiusAuthServer = (char *)calloc(sizeof(char), MAX_RADIUS_LEN))) ||
      ((!radiusAcctServer) && !(radiusAcctServer = (char *)calloc(sizeof(char), MAX_RADIUS_LEN))) ||
      ((!radiusSecret) &&     !(radiusSecret = (char *)calloc(sizeof(char), MAX_SECRET_LENGTH + 1))) ||
      ((!radiusAdminGroup) && !(radiusAdminGroup = (char *)calloc(sizeof(char), MAX_RADIUS_LEN))) ||
      ((!radiusUnprivCapabilitiesGroup)
       && !(radiusUnprivCapabilitiesGroup = (char *)calloc(sizeof(char), MAX_RADIUS_LEN))) ||
      ((!authServer) && !(authServer = (char *)calloc(sizeof(char), MAX_RADIUS_LEN)))) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: unable to allocate memory");
    return false;
  }

  if (!ntop->getRedis()) return false;

  char buf[32];
  /* Allocation failed, do not authenticate */
  ntop->getRedis()->get((char *)PREF_RADIUS_AUTH_SERVER, radiusAuthServer, MAX_RADIUS_LEN);
  ntop->getRedis()->get((char *)PREF_RADIUS_ACCT_SERVER, radiusAcctServer, MAX_RADIUS_LEN); 
  ntop->getRedis()->get((char *)PREF_RADIUS_AUTH_PROTO, buf, sizeof(buf));
  ntop->getRedis()->get((char *)PREF_RADIUS_SECRET, radiusSecret, MAX_SECRET_LENGTH + 1);
  ntop->getRedis()->get((char *)PREF_RADIUS_ADMIN_GROUP, radiusAdminGroup, MAX_RADIUS_LEN);
  ntop->getRedis()->get((char *)PREF_RADIUS_UNPRIV_CAP_GROUP, radiusUnprivCapabilitiesGroup, MAX_RADIUS_LEN);

  if((radiusAuthServer[0] == '\0') || (radiusAcctServer[0] == '\0')) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "No Radius server configured for authentication or accounting [Auth: %s][Acct: %s]",
				 radiusAuthServer, radiusAcctServer);
    return(false);
  }
    
  if(!strcmp(buf, "chap"))
    use_chap = true;
  else
    use_chap = false;
  
  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Radius: server - %s/%s | secret - %s | admin "
                               "group - %s | capabilities group - %s | auth. protocol - %s",
                               radiusAuthServer, radiusAcctServer, radiusSecret, radiusAdminGroup,
                               radiusUnprivCapabilitiesGroup, buf);

  return true;
}

/* *************************************** */

bool Radius::authenticate(const char *user, const char *password,
                          bool *has_unprivileged_capabilities, bool *is_admin) {
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL, *received = NULL;

  if (!buildConfiguration(&rh)) {
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

  if(use_chap) {
    char buf[64], c_buf[32];
    const char *challenge;
    u_int8_t challenge_id = (u_int8_t)time(NULL); /* Random challenge id */
    char remotemd[256];
    unsigned char digest[16] = { 0 };

    /* Create random challenge */
    challenge = Utils::createRandomString(c_buf, sizeof(c_buf)-1);

    if (rc_avpair_add(rh, &send, PW_CHAP_CHALLENGE, challenge, -1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set CHAP challenge");
      goto radius_auth_out;
    }

    snprintf(remotemd, sizeof(remotemd), "%c%s%s", challenge_id, password, challenge);

    ndpi_md5((const u_char*)remotemd, strlen(remotemd), digest);

    buf[0] = challenge_id;
    memcpy(&buf[1], digest, CHAP_VALUE_LENGTH);

    if (rc_avpair_add(rh, &send, PW_CHAP_PASSWORD, buf, CHAP_VALUE_LENGTH+1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set password");
      goto radius_auth_out;
    }
  } else {
    if (rc_avpair_add(rh, &send, PW_USER_PASSWORD, password, -1, 0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set password");
      goto radius_auth_out;
    }
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Radius: performing auth for user %s", user);

  /* ****************************** */

  /* Check the authentication */
  result = rc_auth(rh, 0 /* any client */, send, &received, NULL);

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

            //break; /* We care only about "Filter-Id" */
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
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Radius Authentication rejected for user \"%s\"",
				     user);
	break;
      default:
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Radius Authentication failure[%d]: user \"%s\"",
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

bool Radius::startSession(RadiusTraffic *info) {
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL;

  if (!buildConfiguration(&rh)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Configuration Failed");
    goto radius_auth_out;
  }
  
  if (!addBasicConfigurationAcct(rh, &send, PW_STATUS_START, info)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Radius: performing accounting start for: %s", info->username);

  /* ****************************** */

  /* Check the accounting */
  result = rc_acct(rh, 0 /* any port */, send);

  if (result == OK_RC) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Radius: Accounting start Succedeed");
    radius_ret = true;
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Radius: Accounting start failed with result: %d", result);
  }

 radius_auth_out:
  if (rh) rc_destroy(rh);
  if (send) rc_avpair_free(send);

  return radius_ret;
}

/* *************************************** */

bool Radius::updateSession(RadiusTraffic *info) {
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL;

  /* Init the configuration */
  if (!buildConfiguration(&rh)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Configuration Failed");
    goto radius_auth_out;
  }

  /* Create the basic configuration, used by the accounting */
  if (!addBasicConfigurationAcct(rh, &send, PW_STATUS_ALIVE, info)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  /* Add to the dictionary the interim-update data (needed even in the stop) */
  if (!addUpdateConfigurationAcct(rh, &send, info)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Radius: performing accounting interim-update for: %s",
			       info->username);

  /* ****************************** */

  /* Check the accounting */
  result = rc_acct(rh, 0 /* any port */, send);

  if (result == OK_RC) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG,
                                 "Radius: Accounting Update Succedeed");
    radius_ret = true;
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting update failed with result: %d", result);
  }

 radius_auth_out:
  if (rh) rc_destroy(rh);
  if (send) rc_avpair_free(send);

  return radius_ret;
}

/* *************************************** */

bool Radius::stopSession(RadiusTraffic *info) {
  /* Reset the return */
  bool radius_ret = false;
  rc_handle *rh = NULL;
  VALUE_PAIR *send = NULL;

  /* Init the configuration */
  if (!buildConfiguration(&rh)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Configuration Failed");
    goto radius_auth_out;
  }

  /* Create the basic configuration, used by the accounting */
  if (!addBasicConfigurationAcct(rh, &send, PW_STATUS_STOP, info)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Radius: Accounting Configuration Failed");
    goto radius_auth_out;
  }

  /* Add to the dictionary the interim-update data (needed even in the stop) */
  addUpdateConfigurationAcct(rh, &send, info);

  if(info->terminate_cause) {
    if (rc_avpair_add(rh, &send, PW_ACCT_TERMINATE_CAUSE, &(info->terminate_cause), -1,
                      0) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                  "Radius: unable to set Bytes Sent");
      return false;
    }
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Radius: performing accounting stop for: %s", info->username);

  /* ****************************** */

  /* Check the accounting */
  result = rc_acct(rh, 0 /* any port */, send);

  if (result == OK_RC) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG,
                                 "Radius: Accounting stop Succedeed");
    radius_ret = true;
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Accounting stop failed with result: %d", result);

 radius_auth_out:
  if (rh) rc_destroy(rh);
  if (send) rc_avpair_free(send);

  return radius_ret;
}

/* *************************************** */

#endif
