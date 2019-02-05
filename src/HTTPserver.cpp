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

#include "ntop_includes.h"

#define USE_LUA
#include "../third-party/mongoose/mongoose.c"
#undef USE_LUA

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
};

static HTTPserver *httpserver;

/* ****************************************** */

/*
 * Send error message back to a client.
 */
int send_error(struct mg_connection *conn, int status, const char *reason, const char *fmt, ...) {
  va_list ap;

  conn->status_code = status;

  (void) mg_printf(conn,
		   "HTTP/1.1 %d %s\r\n"
		   "Content-Type: text/html\r\n"
		   "Connection: close\r\n"
		   "\r\n", status, reason);

  /* Errors 1xx, 204 and 304 MUST NOT send a body */
  if(status > 199 && status != 204 && status != 304) {
    char buf[BUFSIZ];
    int  len;

    conn->num_bytes_sent = 0;
    va_start(ap, fmt);
    len = mg_vsnprintf(conn, buf, sizeof(buf), fmt, ap);
    va_end(ap);
    conn->num_bytes_sent += mg_write(conn, buf, len);

    if(ntop->getTrace()->get_trace_level() >= TRACE_LEVEL_INFO)
      cry(conn, "%s", buf);
    else
      cry_connection(conn, buf);
  }

  return(1);
}

/* ****************************************** */

const char *get_secure_cookie_attributes(const struct mg_request_info *request_info) {
  if(request_info->is_ssl)
    return " HttpOnly; SameSite=lax; Secure";
  else
    return " HttpOnly; SameSite=lax";
}

/* ****************************************** */

#ifndef HAVE_NEDGE
static void redirect_to_ssl(struct mg_connection *conn,
                            const struct mg_request_info *request_info) {
  const char *host = mg_get_header(conn, "Host");
  //  u_int16_t port = ntop->get_HTTPserver()->get_port();

  if(host != NULL) {
    const char *p = strchr(host, ':');

    if(p)
      mg_printf(conn, "HTTP/1.1 302 Found\r\n"
		"Location: https://%.*s:%u/%s\r\n\r\n",
		(int) (p - host), host, ntop->getPrefs()->get_https_port(), request_info->uri);
    else
      mg_printf(conn, "HTTP/1.1 302 Found\r\n"
		"Location: https://%s:%u/%s\r\n\r\n",
		host, ntop->getPrefs()->get_https_port(), request_info->uri);
  } else {
    mg_printf(conn, "%s", "HTTP/1.1 500 Error\r\n\r\nHost: header is not set");
  }
}
#endif

/* ****************************************** */

// Generate session ID. buf must be 33 bytes in size.
// Note that it is easy to steal session cookies by sniffing traffic.
// This is why all communication must be SSL-ed.
static void generate_session_id(char *buf, const char *random, const char *user, const char *group) {
  mg_md5(buf, random, user, group, NULL);
}

/* ****************************************** */

bool HTTPserver::authorized_localhost_user_login(const struct mg_connection *conn) {
  if(ntop->getPrefs()->is_localhost_users_login_disabled()
     && (conn->request_info.remote_ip == 0x7F000001 /* 127.0.0.1 */))
    return true;
  return false;
}

/* ****************************************** */

void HTTPserver::traceLogin(const char *user, bool authorized) {
  NetworkInterface *ntop_interface;
  AlertsManager *am;
  const char *alert_json;
  time_t when = time(NULL);
  json_object *jobj;

  ntop_interface = ntop->getFirstInterface();

  if (ntop_interface == NULL)
    return;

  am = ntop_interface->getAlertsManager();

  if (am == NULL)
    return;

  jobj = json_object_new_object();
  if (jobj == NULL) return;

  json_object_object_add(jobj, "scope",  json_object_new_string("login"));
  json_object_object_add(jobj, "status", json_object_new_string(authorized ? "authorized" : "unauthorized"));

  alert_json = json_object_to_json_string(jobj);

  if (alert_json) {
    am->storeGenericAlert(alert_entity_user, user, alert_user_activity, 
      authorized ? alert_level_info : alert_level_warning, alert_json, when);
  }

  json_object_put(jobj);
}

/* ****************************************** */

static void set_cookie(const struct mg_connection * const conn,
                       const char * const user,
		       const char * const group,
		       bool localuser,
		       const char * const referer) {
  char key[256], session_id[64], random[64];
  char val[128];
  u_int session_duration = ntop->getPrefs()->get_auth_session_duration();

  if(!strcmp(mg_get_request_info((struct mg_connection*)conn)->uri, "/metrics")
     || !strncmp(mg_get_request_info((struct mg_connection*)conn)->uri, LIVE_TRAFFIC_URL, strlen(LIVE_TRAFFIC_URL))
     || !strncmp(mg_get_request_info((struct mg_connection*)conn)->uri, GRAFANA_URL, strlen(GRAFANA_URL))
     || !strncmp(mg_get_request_info((struct mg_connection*)conn)->uri, POOL_MEMBERS_ASSOC_URL, strlen(POOL_MEMBERS_ASSOC_URL)))
    return;

  if(HTTPserver::authorized_localhost_user_login(conn))
    return;
  
  // Authentication success:
  //   1. create new session
  //   2. set session ID token in the cookie
  //
  // The most secure way is to stay HTTPS all the time. However, just to
  // show the technique, we redirect to HTTP after the successful
  // authentication. The danger of doing this is that session cookie can
  // be stolen and an attacker may impersonate the user.
  // Secure application must use HTTPS all the time.

  snprintf(random, sizeof(random), "%d", rand());

  generate_session_id(session_id, random, user, group);

  // ntop->getTrace()->traceEvent(TRACE_ERROR, "==> %s\t%s", random, session_id);

  // do_auto_logout() is the getter for the command-line specified
  // preference that defaults to true (i.e., auto_logout is enabled by default)
  // If do_auto_logout() is disabled, then the runtime auto logout preference
  // is taken into account.
  // If do_auto_logout() is false, then the auto logout is disabled regardless
  // of runtime preferences.
  if(!ntop->getPrefs()->do_auto_logout() || !ntop->getPrefs()->do_auto_logout_at_runtime())
    session_duration = EXTENDED_HTTP_SESSION_DURATION;

  /* http://en.wikipedia.org/wiki/HTTP_cookie */
  mg_printf((struct mg_connection *)conn, "HTTP/1.1 302 Found\r\n"
	    "Set-Cookie: session=%s; path=/; max-age=%u;%s\r\n"  // Session ID
	    "Location: %s%s\r\n\r\n",
	    session_id, session_duration, get_secure_cookie_attributes(mg_get_request_info((struct mg_connection*)conn)),
	    ntop->getPrefs()->get_http_prefix(), referer ? referer : "/");

  /* Save session in redis */
  snprintf(key, sizeof(key), "sessions.%s", session_id);
  snprintf(val, sizeof(val), "%s|%s|%c", user, group, localuser ? '1' : '0');

  ntop->getRedis()->set(key, val, session_duration);
  ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] Set session sessions.%s", session_id);

  HTTPserver::traceLogin(user, true);
}

/* ****************************************** */

static void get_qsvar(const struct mg_request_info *request_info,
                      const char *name, char *dst, size_t dst_len) {
  const char *qs = request_info->query_string;
  mg_get_var(qs, strlen(qs == NULL ? "" : qs), name, dst, dst_len);
}

/* ****************************************** */

static int checkCaptive(const struct mg_connection *conn,
			const struct mg_request_info *request_info,
			char *username, char *password) {
#ifdef NTOPNG_PRO
  if(ntop->getPrefs()->isCaptivePortalEnabled()
     && ntop->isCaptivePortalUser(username)) {
    /*
      This user logged onto ntopng via the captive portal
    */
    u_int16_t host_pool_id;
    int32_t limited_lifetime = -1; /* Unlimited by default */
    char label[128];

    get_qsvar(request_info, "label", label, sizeof(label));

#ifdef DEBUG
    char buf[32];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[CAPTIVE] %s @ %s/%08X [Redirecting to %s%s]",
				 username, Utils::intoaV4((unsigned int)conn->request_info.remote_ip, buf, sizeof(buf)),
				 (unsigned int)conn->request_info.remote_ip,
				 mg_get_header(conn, "Host") ? mg_get_header(conn, "Host") : (char*)"",
				 request_info->uri);
#endif

    char bridge_interface[32];

    if(!ntop->getUserAllowedIfname(username, bridge_interface, sizeof(bridge_interface)))
      return(0);

    ntop->getUserHostPool(username, &host_pool_id);
    ntop->hasUserLimitedLifetime(username, &limited_lifetime);

    if(!ntop->addIPToLRUMatches(htonl((unsigned int)conn->request_info.remote_ip),
			    host_pool_id, label, limited_lifetime, bridge_interface))
      return(0);

    /* Success */
    return(1);
  }
#endif

  return(0);
}

/* ****************************************** */

static int checkInformativeCaptive(const struct mg_connection *conn,
				   const struct mg_request_info *request_info) {
#ifdef NTOPNG_PRO
#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[CAPTIVE] @ %s/%08X [Redirecting to %s%s]",
			       Utils::intoaV4((unsigned int)conn->request_info.remote_ip, buf, sizeof(buf)),
			       (unsigned int)conn->request_info.remote_ip,
			       mg_get_header(conn, "Host") ? mg_get_header(conn, "Host") : (char*)"",
			       request_info->uri);
#endif

  if(!ntop->addToNotifiedInformativeCaptivePortal(htonl((unsigned int)conn->request_info.remote_ip)))
    return(0);

  /* Success */
  return(1);
#endif

  return(0);
}

/* ****************************************** */

static int checkGrafana(const struct mg_connection *conn,
			const struct mg_request_info *request_info) {

  if(!strcmp(request_info->request_method, "OPTIONS") /* Allow for CORS inflight requests */
    && !strncmp(request_info->uri, GRAFANA_URL, strlen(GRAFANA_URL)))
    /* Success */
    return(1);

  return(0);
}

/* ****************************************** */

static int isWhitelistedURI(const char * const uri) {
  /* URL whitelist */
  if((!strcmp(uri,    LOGIN_URL))
     || (!strcmp(uri, AUTHORIZE_URL))
     || (!strcmp(uri, HOTSPOT_DETECT_URL))
     || (!strcmp(uri, HOTSPOT_DETECT_LUA_URL))
     || (!strcmp(uri, ntop->getPrefs()->getCaptivePortalUrl()))
     || (!strcmp(uri, KINDLE_WIFISTUB_URL))
     )
    return(1);
  else
    return(0);
}

/* ****************************************** */

static bool ssl_client_x509_auth(const struct mg_connection * const conn, const struct mg_request_info * const request_info,
				 char * const username, char * const group, bool * const localuser) {
  bool ret = false;
  X509 *cert = NULL;
  X509_NAME *subj = NULL;
  char subject[256];
  char key[CONST_MAX_LEN_REDIS_KEY];

  if((cert = SSL_get_peer_certificate(conn->ssl))) {
    if((subj = X509_get_subject_name(cert))) {
      X509_NAME_oneline(subj, subject, sizeof(subject));

      if(SSL_get_verify_result(conn->ssl) == X509_V_OK
	 && X509_NAME_get_text_by_NID(subj, NID_commonName, username, NTOP_USERNAME_MAXLEN) >= 0) {
	snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);

	bool group_exists = ntop->getRedis()->get(key, group, NTOP_GROUP_MAXLEN) >= 0;

	if(ntop->existsUser(username)
	   && group_exists) {
	  *localuser = true;
	  ntop->getTrace()->traceEvent(TRACE_INFO,"SSL user authenticated [username: %s][group: %s][subject: %s]", username, group, subject);

	  ret = true;
	} else
	  ntop->getTrace()->traceEvent(TRACE_INFO,"SSL user: not found [user: %s]", username);
      } else
	ntop->getTrace()->traceEvent(TRACE_INFO,"SSL user: unknow certificate or missing NID_commonName [subject: %s]", subject);
    }

    X509_free(cert);
  } else
    ntop->getTrace()->traceEvent(TRACE_INFO,"SSL user: could not get certificate");

  if(!ret)
    username[0] = '\0', group[0] = '\0';

  return ret;
};

/* ****************************************** */

// Return 1 if request is authorized, 0 otherwise.
// If 1 is returned, the username parameter will contain the authenticated user,
// which can also be "" or NTOP_NOLOGIN_USER .
static int getAuthorizedUser(struct mg_connection *conn,
                         const struct mg_request_info *request_info,
			 char *username, char *group, bool *localuser) {
  char session_id[NTOP_SESSION_ID_LENGTH];
  char key[64], val[128];
  char password[MAX_PASSWORD_LEN];
  char localuser_ch;
  const char *auth_header_p;
  string auth_type = "", auth_string = "";
  bool user_login_disabled = !ntop->getPrefs()->is_users_login_enabled() ||
    HTTPserver::authorized_localhost_user_login(conn);

  /* Default */
  username[0] = '\0';
  group[0] = '\0';
  *localuser = false;

#ifdef DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[AUTHORIZATION] [%s][%s]",
			       request_info->uri, request_info->query_string ? request_info->query_string : "");
#endif

  /*
    iOS / MacOS
    1. HOTSPOT_DETECT_URL        "/hotspot-detect.html"
    2. HOTSPOT_DETECT_LUA_URL    "/lua/hotspot-detect.lua"
    3. CAPTIVE_PORTAL_URL        "/lua/captive_portal.lua"
    4. AUTHORIZE_CAPTIVE_LUA_URL "/lua/authorize_captive.lua"
    5. logged in

    Kindle
    1. KINDLE_WIFISTUB_URL
  */
  if(!strcmp(request_info->uri, AUTHORIZE_CAPTIVE_LUA_URL)) {
    /* A captive portal request has been issued to the authorization url */

    if(ntop->getPrefs()->isInformativeCaptivePortalEnabled()) {
      /* If the captive portal is just informative, there's no need to check
	 any username or password. The request per se means the internet user
	 has accepted the 'terms of service'. */
      return(checkInformativeCaptive(conn, request_info));
    } else {
      /* Here the captive portal is not just informative; it requires authentication.
         For this reason it is necessary to check submitted username and password. */
        if(!strcmp(request_info->request_method, "POST")) {
          char post_data[1024];
          int post_data_len = mg_read(conn, post_data, sizeof(post_data));

          mg_get_var(post_data, post_data_len, "username", username, sizeof(username));
          mg_get_var(post_data, post_data_len, "password", password, sizeof(password));

	return(ntop->checkCaptiveUserPassword(username, password, group)
	     && checkCaptive(conn, request_info, username, password));
      }
    }
  }

  if(checkGrafana(conn, request_info) == 1) {
    return(1);
  }

  if(user_login_disabled) {
    strncpy(username, NTOP_NOLOGIN_USER, NTOP_USERNAME_MAXLEN);
    username[NTOP_USERNAME_MAXLEN - 1] = '\0';
    return(1);
  }

  /* Try to authenticate using client TLS/SSL certificate */
  if(request_info->is_ssl
     && ntop->getPrefs()->is_client_x509_auth_enabled()
     && ssl_client_x509_auth(conn, request_info, username, group, localuser))
    return(1);

  /* Try to decode Authorization header if present */
  auth_header_p = mg_get_header(conn, "Authorization");
  string auth_header = auth_header_p ? auth_header_p  : "";
  istringstream iss(auth_header);
  getline(iss, auth_type, ' ');
  if(auth_type == "Basic") {
    string decoded_auth, user_s = "", pword_s = "";
    /* In case auth type is Basic, info are encoded in base64 */
    getline(iss, auth_string, ' ');
    decoded_auth = Utils::base64_decode(auth_string);
    istringstream authss(decoded_auth);
    getline(authss, user_s, ':');
    getline(authss, pword_s, ':');

    strncpy(username, user_s.c_str(), NTOP_USERNAME_MAXLEN);
    username[NTOP_USERNAME_MAXLEN - 1] = '\0';
    return ntop->checkGuiUserPassword(conn, username, pword_s.c_str(), group, localuser);
  }

  /* NOTE: this is the only cookie needed for gui authentication */
  mg_get_cookie(conn, "session", session_id, sizeof(session_id));

  if(session_id[0] == '\0') {
    /* Explicit username + password */
    mg_get_cookie(conn, "user", username, NTOP_USERNAME_MAXLEN);
    mg_get_cookie(conn, "password", password, sizeof(password));

    if(username[0] && password[0])
      return(ntop->checkGuiUserPassword(conn, username, password, group, localuser));
  }

  /* Important: validate the session */
  snprintf(key, sizeof(key), "sessions.%s", session_id);

  val[0] = '\0';
  if((ntop->getRedis()->get(key, val, sizeof(val), true) < 0) || (!val[0])) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] Session %s is expired", session_id);
    return(0);
  }

  snprintf(key, sizeof(key), "%%%u[^|]|%%%u[^|]|%%c", NTOP_USERNAME_MAXLEN-1, NTOP_GROUP_MAXLEN-1);

  if(sscanf(val, key, username, group, &localuser_ch) != 3) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] Old Session format %s not supported", session_id);
    return(0);
  }

  username[NTOP_USERNAME_MAXLEN-1] = '\0';
  group[NTOP_GROUP_MAXLEN-1] = '\0';
  *localuser = (localuser_ch == '1' ? true : false);

  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "[HTTP] Session %s successfully authenticated for %s", session_id, username);

  // NOTE: no sense to extend the session here, since the user browser cookie will expire anyway!
  //ntop->getRedis()->expire(key, HTTP_SESSION_DURATION); /* Extend session */
  //ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] Session %s (for %s) is ok, extended for %u sec", session_id, username, HTTP_SESSION_DURATION);

  return(1);
}

/* ****************************************** */

static int isCaptiveConnection(struct mg_connection *conn) {
  return(ntop->getPrefs()->isCaptivePortalEnabled()
	 && (ntohs(conn->client.lsa.sin.sin_port) == CAPTIVE_PORTAL_PORT)
	 );
}

/* ****************************************** */

static int isCaptiveURL(char *url) {
  if((!strcmp(url, KINDLE_WIFISTUB_URL))
     || (!strcmp(url, HOTSPOT_DETECT_URL))
     || (!strcmp(url, HOTSPOT_DETECT_LUA_URL))
     || (!strcmp(url, ntop->getPrefs()->getCaptivePortalUrl()))
     || (!strcmp(url, AUTHORIZE_CAPTIVE_LUA_URL))
     || (!strcmp(url, "/"))
     )
    return(1);
  else
    return(0);
}

/* ****************************************** */

static bool isStaticResourceUrl(const struct mg_request_info *request_info, u_int len) {
  if((len >= 3 && (!strncmp(&request_info->uri[len - 3], ".js", 3)))
     || (len >= 4 && (!strncmp(&request_info->uri[len - 4], ".css", 4)
		      || !strncmp(&request_info->uri[len - 4], ".map", 4)
		      || !strncmp(&request_info->uri[len - 4], ".ttf", 4)))
     || (len >= 6 && (!strncmp(&request_info->uri[len - 6], ".woff2", 6))))
    return true;

  return false;
}

/* ****************************************** */

/* this corresponds to the LAN interface address */
void HTTPserver::setCaptiveRedirectAddress(const char *addr) {
#ifdef NTOPNG_PRO
  size_t max_wispr_size = 1024;

  if(captive_redirect_addr)
    free(captive_redirect_addr);
  captive_redirect_addr = strdup(addr);

  if(!wispr_captive_data)
    wispr_captive_data = (char *) malloc(max_wispr_size);

  const char *name =
#ifdef HAVE_NEDGE
    ntop->getPro()->get_product_name()
#else
  "ntopng"
#endif
    ;
  
  snprintf(wispr_captive_data, max_wispr_size, "<HTML>\n\
<!--\n\
<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<WISPAccessGatewayParam xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n\
  xsi:noNamespaceSchemaLocation=\"http://www.acmewisp.com/WISPAccessGatewayParam.xsd\">\n\
  <Redirect>\n\
    <AccessProcedure>1.0</AccessProcedure>\n\
    <AccessLocation>%s Network</AccessLocation>\n\
    <LocationName>%s</LocationName>\n\
    <LoginURL>http://%s:%u%s%s</LoginURL>\n\
    <MessageType>100</MessageType>\n\
    <ResponseCode>0</ResponseCode>\n\
  </Redirect>\n\
</WISPAccessGatewayParam>\n\
-->\n\
</HTML>", name, name, addr, CAPTIVE_PORTAL_PORT,
	ntop->getPrefs()->get_http_prefix(),
	ntop->getPrefs()->getCaptivePortalUrl());
#endif
}

/* ****************************************** */

static char* make_referer(struct mg_connection *conn, char *buf, int bufsize) {
  snprintf(buf, bufsize, "%s%s%s%s",
	  mg_get_header(conn, "Host") ? mg_get_header(conn, "Host") : (char*)"",
	  conn->request_info.uri,
	  conn->request_info.query_string ? "?" : "",
	  conn->request_info.query_string ? conn->request_info.query_string : "");

  return buf;
}

/* ****************************************** */

// Redirect user to the login form. In the cookie, store the original URL
// we came from, so that after the authorization we could redirect back.
static void redirect_to_login(struct mg_connection *conn,
                              const struct mg_request_info *request_info,
			      const char * const referer) {
  char session_id[NTOP_SESSION_ID_LENGTH], buf[128];
  char *referer_enc = NULL;

  if(isCaptiveConnection(conn)) {
    const char *wispr_data = ntop->get_HTTPserver()->getWisprCaptiveData();

    mg_printf(conn, "HTTP/1.1 302 Found\r\n"
	      "Expires: 0\r\n"
	      "Cache-Control: no-store, no-cache, must-revalidate\t\n"
	      "Pragma: no-cache\r\n"
	      "Content-Type: text/html; charset=UTF-8\r\n"
	      "Content-Length: %lu\r\n"
	      "Location: http://%s:%u%s%s%s%s\r\n\r\n%s",
              strlen(wispr_data),
              ntop->get_HTTPserver()->getCaptiveRedirectAddress(), // LAN address
              CAPTIVE_PORTAL_PORT,
	      ntop->getPrefs()->get_http_prefix(), ntop->getPrefs()->getCaptivePortalUrl(),
	      referer ? (char*)"?referer=" : "",
	      referer ? (referer_enc = Utils::urlEncode(referer)) : (char*)"",
              wispr_data);
  } else {
#ifdef DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[LOGIN] [Host: %s][URI: %s]",
				 mg_get_header(conn, "Host") ? mg_get_header(conn, "Host") : (char*)"",
				 request_info->uri);
#endif

    mg_get_cookie(conn, "session", session_id, sizeof(session_id));
    ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] %s(%s)", __FUNCTION__, session_id);

    mg_printf(conn,
	      "HTTP/1.1 302 Found\r\n"
	      "Set-Cookie: session=%s; path=/; expires=Thu, 01-Jan-1970 00:00:01 GMT; max-age=0;%s\r\n"  // Session ID
	      "Set-Cookie: user=; path=/; expires=Thu, 01-Jan-1970 00:00:01 GMT; max-age=0;\r\n"
	      "Set-Cookie: password=; path=/; expires=Thu, 01-Jan-1970 00:00:01 GMT; max-age=0;\r\n"
	      "Location: %s%s%s%s\r\n\r\n",
	      session_id,
	      get_secure_cookie_attributes(request_info),
	      ntop->getPrefs()->get_http_prefix(), Utils::getURL((char*)LOGIN_URL, buf, sizeof(buf)),
	      referer ? (char*)"?referer=" : "",
	      referer ? (referer_enc = Utils::urlEncode(referer)) : (char*)"");
  }

  if(referer_enc)
    free(referer_enc);
}

/* ****************************************** */

#ifdef HAVE_MYSQL
/* Redirect user to a courtesy page that is used when database schema is being updated.
   In the cookie, store the original URL we came from, so that after the authorization
   we could redirect back.
*/
static void redirect_to_please_wait(struct mg_connection *conn,
				    const struct mg_request_info *request_info) {
  char session_id[NTOP_SESSION_ID_LENGTH], buf[128];
  char referer[255];
  char *referer_enc = NULL;

  make_referer(conn, referer, sizeof(referer));
  mg_get_cookie(conn, "session", session_id, sizeof(session_id));
  ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] %s(%s)", __FUNCTION__, session_id);

  mg_printf(conn,
	    "HTTP/1.1 302 Found\r\n"
	    // "HTTP/1.1 401 Unauthorized\r\n"
	    // "WWW-Authenticate: Basic\r\n"
	    "Location: %s%s%s%s\r\n\r\n",
	    ntop->getPrefs()->get_http_prefix(), Utils::getURL((char*)PLEASE_WAIT_URL, buf, sizeof(buf)),
	    (referer[0] != '\0') ? (char*)"?referer=" : (char*)"",
	    (referer[0] != '\0') ? (referer_enc = Utils::urlEncode(referer)) : (char*)"");

  if(referer_enc)
    free(referer_enc);
}
#endif

/* ****************************************** */

static void redirect_to_password_change(struct mg_connection *conn,
				    const struct mg_request_info *request_info) {
  char session_id[NTOP_SESSION_ID_LENGTH], buf[128];
  char referer[255];
  char *referer_enc = NULL;

  make_referer(conn, referer, sizeof(referer));
  mg_get_cookie(conn, "session", session_id, sizeof(session_id));
  ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] %s(%s)", __FUNCTION__, session_id);

    mg_printf(conn,
	      "HTTP/1.1 302 Found\r\n"
	      "Set-Cookie: session=%s; path=/;%s\r\n"  // Session ID
	      "Location: %s%s%s%s\r\n\r\n", /* FIX */
	      session_id,
	      get_secure_cookie_attributes(request_info),
	      ntop->getPrefs()->get_http_prefix(), Utils::getURL((char*)CHANGE_PASSWORD_ULR, buf, sizeof(buf)),
	      (referer[0] != '\0') ? (char*)"?referer=" : (char*)"",
	      (referer[0] != '\0') ? (referer_enc = Utils::urlEncode(referer)) : (char*)"");

  if(referer_enc)
    free(referer_enc);
}

/* ****************************************** */

// A handler for the /authorize endpoint.
// Login page form sends user name and password to this endpoint.
static void authorize(struct mg_connection *conn,
                      const struct mg_request_info *request_info,
		      char *username, char *group, bool *localuser) {
  char user[32] = { '\0' }, password[32] = { '\0' }, referer[256] = { '\0' };


  if(!strcmp(request_info->request_method, "POST")) {
    char post_data[1024];
    int post_data_len = mg_read(conn, post_data, sizeof(post_data));

    mg_get_var(post_data, post_data_len, "user", user, sizeof(user));
    mg_get_var(post_data, post_data_len, "password", password, sizeof(password));
    mg_get_var(post_data, post_data_len, "referer", referer, sizeof(referer));
  } else {
    // Fetch user name and password.
    get_qsvar(request_info, "user", user, sizeof(user));
    get_qsvar(request_info, "password", password, sizeof(password));
    get_qsvar(request_info, "ref", referer, sizeof(referer));

    if(referer[0] == '\0') {
      for(int i=0; request_info->http_headers[i].name != NULL; i++) {
	if(strcmp(request_info->http_headers[i].name, "Referer") == 0) {
	  snprintf(referer, sizeof(referer), "%s", request_info->http_headers[i].value);
	  break;
	}
      }
    }
  }

  if(isCaptiveConnection(conn)
     || ntop->isCaptivePortalUser(user)
     || !ntop->checkGuiUserPassword(conn, user, password, group, localuser)) {
    // Authentication failure, redirect to login
    redirect_to_login(conn, request_info, (referer[0] == '\0') ? NULL : referer);
  } else {
    /* Referer url must begin with '/' */
    if((referer[0] != '/') || (strcmp(referer, AUTHORIZE_URL) == 0)) {
      char *r = strchr(referer, '/');

      if(r)
	memmove(referer, r, strlen(r)+1 /* with null terminator */);
      else
	strcpy(referer, "/");
    }

    /* Send session cookie and set user for the new session */
    set_cookie(conn, user, group, *localuser, referer);
    strncpy(username, user, NTOP_USERNAME_MAXLEN);
    username[NTOP_USERNAME_MAXLEN - 1] = '\0';
  }
}

/* ****************************************** */

static void uri_encode(const char *src, char *dst, u_int dst_len) {
  u_int i = 0, j = 0;

  memset(dst, 0, dst_len);

  while(src[i] != '\0') {
    if(src[i] == '<') {
      dst[j++] = '&'; if(j == (dst_len-1)) break;
      dst[j++] = 'l'; if(j == (dst_len-1)) break;
      dst[j++] = 't'; if(j == (dst_len-1)) break;
      dst[j++] = ';'; if(j == (dst_len-1)) break;
    } else if(src[i] == '>') {
      dst[j++] = '&'; if(j == (dst_len-1)) break;
      dst[j++] = 'g'; if(j == (dst_len-1)) break;
      dst[j++] = 't'; if(j == (dst_len-1)) break;
      dst[j++] = ';'; if(j == (dst_len-1)) break;
    } else {
      dst[j++] = src[i]; if(j == (dst_len-1)) break;
    }

    i++;
  }
}

/* ****************************************** */

static int handle_lua_request(struct mg_connection *conn) {
  struct mg_request_info *request_info = (struct mg_request_info *)mg_get_request_info(conn);
  char *crlf;
  u_int len;
  char username[NTOP_USERNAME_MAXLEN] = { 0 };
  char group[NTOP_GROUP_MAXLEN] = { 0 };
  bool localuser = false;
  char *referer = (char*)mg_get_header(conn, "Referer");
  u_int8_t whitelisted;

  strncpy(group, NTOP_UNKNOWN_GROUP, NTOP_GROUP_MAXLEN-1);
  group[NTOP_GROUP_MAXLEN - 1] = '\0';

  if(referer == NULL)
    referer = (char*)"";

  if((crlf = strstr(request_info->uri, "\r\n")))
    *crlf = '\0'; /* Prevents HTTP splitting attacks */

  len = (u_int)strlen(request_info->uri);

#ifdef HAVE_NEDGE
  if(!ntop->getPro()->has_valid_license()) {
    if (! ntop->getGlobals()->isShutdown()) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "License expired, shutting down...");
      ntop->getGlobals()->shutdown();
      ntop->shutdown();
    }
  }
#endif

#ifdef DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[Host: %s][URI: %s][%s][Referer: %s]",
			       mg_get_header(conn, "Host") ? mg_get_header(conn, "Host") : (char*)"",
			       request_info->uri,
			       request_info->query_string ? request_info->query_string : "",
			       (char*)mg_get_header(conn, "Referer"));
#endif

  if((ntop->getGlobals()->isShutdown())
     //|| (strcmp(request_info->request_method, "GET"))
     || (ntop->getRedis() == NULL /* Starting up... */)
     || (ntop->get_HTTPserver() == NULL))
    return(send_error(conn, 403 /* Forbidden */, request_info->uri,
		      "Unable to serve requests at this time, possibly starting up or shutting down."));

#ifdef DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "################# [HTTP] %s [%s]",
			       request_info->uri, referer);
#endif

#ifndef HAVE_NEDGE
  if(ntop->get_HTTPserver()->is_ssl_enabled()
     && (!request_info->is_ssl)
     && isCaptiveURL(request_info->uri)
     && (!strstr(referer, HOTSPOT_DETECT_LUA_URL))
     && (!strstr(referer, ntop->getPrefs()->getCaptivePortalUrl()))
     // && ((mg_get_header(conn, "Host") == NULL) || (mg_get_header(conn, "Host")[0] == '\0'))
     ) {
    redirect_to_ssl(conn, request_info);
    return(1);
  } else
#endif
  if(!strcmp(request_info->uri, HOTSPOT_DETECT_URL)) {
    mg_printf(conn, "HTTP/1.1 302 Found\r\n"
	      "Expires: 0\r\n"
	      "Cache-Control: no-store, no-cache, must-revalidate\t\n"
	      "Pragma: no-cache\r\n"
	      "Location: http://%s%s%s%s\r\n\r\n",
	      mg_get_header(conn, "Host") ? mg_get_header(conn, "Host") : (char*)"",
	      HOTSPOT_DETECT_LUA_URL,
	      request_info->query_string ? "?" : "",
	      request_info->query_string ? request_info->query_string : "");
    return(1);
  }
#if 0
 else if(!strcmp(request_info->uri, KINDLE_WIFISTUB_URL)) {
    mg_printf(conn, "HTTP/1.1 302 Found\r\n"
	      "Expires: 0\r\n"
	      "Cache-Control: no-store, no-cache, must-revalidate\t\n"
	      "Pragma: no-cache\r\n"
	      "Referer: %s\r\n"
	      "Location: http://%s:%u%s%s%s\r\n\r\n",
	      request_info->uri,
	      mg_get_header(conn, "Host") ? mg_get_header(conn, "Host") : (char*)"",
	      CAPTIVE_PORTAL_PORT,
	      ntop->getPrefs()->getCaptivePortalUrl(),
	      request_info->query_string ? "?" : "",
	      request_info->query_string ? request_info->query_string : "");
    return(1);
  }
#endif

  whitelisted = isWhitelistedURI(request_info->uri);

  if(!isStaticResourceUrl(request_info, len)) {
    /* Only check authorized for non-static resources */
    u_int8_t authorized = getAuthorizedUser(conn, request_info, username, group, &localuser);

    /* Make sure there are existing interfaces for username. */
    if(!ntop->checkUserInterfaces(username)) {
      char session_id[NTOP_SESSION_ID_LENGTH];
      mg_get_cookie(conn, "session", session_id, sizeof(session_id));

      ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] user %s cannot login due to non-existent allowed_interface", username);

      // send error and expire session cookie
      mg_printf(conn,
		"HTTP/1.1 403 Forbidden\r\n"
		"Content-Type: text/html\r\n"
		"Set-Cookie: session=%s; path=/; expires=Thu, 01-Jan-1970 00:00:01 GMT; max-age=0;%s\r\n"  // Session ID
		"Connection: close\r\n"
		"\r\n\r\n%s", session_id,
		get_secure_cookie_attributes(request_info),
		ACCESS_DENIED_INTERFACES);

      return(1);
    }

    if((!whitelisted) && (!authorized)) {
      if(strcmp(request_info->uri, INTERFACE_DATA_URL) == 0) {
        // avoid sending login redirect to allow js itself to redirect the user
        return(send_error(conn, 403 /* Forbidden */, request_info->uri, "Login Required"));
      } else {
        char referer[255];

        redirect_to_login(conn, request_info, make_referer(conn, referer, sizeof(referer)));
      }

      return(1);
    } else if ((strcmp(request_info->uri, CHANGE_PASSWORD_ULR) != 0)
        && (strcmp(request_info->uri, LOGOUT_URL) != 0)
         && authorized
        && ntop->mustChangePassword(username)) {
      redirect_to_password_change(conn, request_info);
      return(1);
#ifdef HAVE_MYSQL
    } else if(!whitelisted /* e.g. login.lua */
        && ntop->getPrefs()->do_dump_flows_on_mysql()
        && !MySQLDB::isDbCreated()
        && strcmp(request_info->uri, PLEASE_WAIT_URL)) {
      redirect_to_please_wait(conn, request_info);
      return(1);
#endif
    } else if(strcmp(request_info->uri, AUTHORIZE_URL) == 0) {
      authorize(conn, request_info, username, group, &localuser);
      return(1);
    }
  }

#ifdef DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Username = %s", username);
#endif

  if(strstr(request_info->uri, "//")
     || strstr(request_info->uri, "&&")
     || strstr(request_info->uri, "??")
     || strstr(request_info->uri, "..")
     || strstr(request_info->uri, "\r")
     || strstr(request_info->uri, "\n")
     ) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] The URL %s is invalid/dangerous",
				 request_info->uri);
    return(send_error(conn, 400 /* Bad Request */, request_info->uri,
		      "The URL specified contains invalid/dangerous characters"));
  }

  if((strncmp(request_info->uri, "/lua/", 5) == 0)
     || (strcmp(request_info->uri, "/metrics") == 0)
     || (strcmp(request_info->uri, "/") == 0)) {
    /* Lua Script */
    char path[255] = { 0 }, uri[2048];
#ifdef WIN32
	struct _stat64 buf;
#else
	struct stat buf;
#endif
    bool found;

    if(strstr(request_info->uri, "/lua/pro")
       && (!ntop->getPrefs()->is_pro_edition())) {
      return(send_error(conn, 403 /* Forbidden */, request_info->uri,
			"Professional edition license required"));
    }

    if(strstr(request_info->uri, "/lua/pro/enterprise")
       && (!ntop->getPrefs()->is_enterprise_edition())) {
      return(send_error(conn, 403 /* Forbidden */, request_info->uri,
			"Enterprise edition license required"));
    }

    if((!whitelisted)
       && isCaptiveConnection(conn)
       && (!isCaptiveURL(request_info->uri))) {
      redirect_to_login(conn, request_info, (referer[0] == '\0') ? NULL : referer);
      return(0);
    } else {
      if(strcmp(request_info->uri, "/metrics") == 0)
	snprintf(path, sizeof(path), "%s/lua/metrics.lua",
	  httpserver->get_scripts_dir());
      else
	snprintf(path, sizeof(path), "%s%s%s",
	       httpserver->get_scripts_dir(),
	       Utils::getURL(len == 1 ? (char*)"/lua/index.lua" : request_info->uri, uri, sizeof(uri)),
	       len > 1 && request_info->uri[len-1] == '/' ? (char*)"index.lua" : (char*)"");

      if(strlen(path) > 4 && strncmp(&path[strlen(path) - 4], ".lua", 4))
	snprintf(&path[strlen(path)], sizeof(path) - strlen(path) - 1, "%s", (char*)".lua");

      ntop->fixPath(path);
      found = ((stat(path, &buf) == 0) && (S_ISREG(buf.st_mode))) ? true : false;
    }

    if(found) {
      LuaEngine *l;

      ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] %s [%s]", request_info->uri, path);

      try {
	l = new LuaEngine();
      } catch(std::bad_alloc& ba) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "[HTTP] Unable to start Lua interpreter.");
	return(send_error(conn, 500 /* Internal server error */,
			  "Internal server error", "%s", "Unable to start Lua interpreter."));
      }

      bool attack_attempt;

      // NOTE: username is stored into the engine context, so we must guarantee
      // that LuaEngine is destroyed after username goes out of context! Indeeed we delete LuaEngine below.
      l->handle_script_request(conn, request_info, path, &attack_attempt, username, group, localuser);

      if(attack_attempt) {
	char buf[32];
	  
	ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] Potential attack from %s on %s",
				     Utils::intoaV4((unsigned int)conn->request_info.remote_ip, buf, sizeof(buf)),
				     request_info->uri);
      }

      delete l;
      return(1); /* Handled */
    }

    uri_encode(request_info->uri, uri, sizeof(uri)-1);

    return(send_error(conn, 404, "Not Found", PAGE_NOT_FOUND, uri));
  } else {
    /* Prevent short URI or .inc files to be served */
    if((len < 4) || (strncmp(&request_info->uri[len-4], ".inc", 4) == 0)) {
      return(send_error(conn, 403, "Forbidden",
			ACCESS_FORBIDDEN, request_info->uri));
    } else {
      ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] Serving file %s%s",
				   ntop->get_HTTPserver()->get_docs_dir(), request_info->uri);
      request_info->query_string = ""; /* Discard things like ?v=4.4.0 */
      return(0); /* This is a static document so let mongoose handle it */
    }
  }
}

/* ****************************************** */

static int handle_http_message(const struct mg_connection *conn, const char *message) {
  ntop->getTrace()->traceEvent(TRACE_ERROR, "[HTTP] %s", message);
  return 1;
}

/* ****************************************** */

bool HTTPserver::check_ssl_cert(char *ssl_cert_path, size_t ssl_cert_path_len) {
#ifdef WIN32
  struct _stat64 s;
#else
  struct stat s;
#endif
  int stat_rc;
  ssl_cert_path[0] = '\0';

  snprintf(ssl_cert_path, ssl_cert_path_len, "%s/ssl/%s",
	   docs_dir, CONST_HTTPS_CERT_NAME);

  stat_rc = stat(ssl_cert_path, &s);

  if(stat_rc == 0) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Found SSL certificate %s", ssl_cert_path);
    return true;
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "HTTPS Disabled: missing SSL certificate %s", ssl_cert_path);
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Please read https://github.com/ntop/ntopng/blob/dev/doc/README.SSL if you want to enable SSL.");

  return false;
}

/* ****************************************** */

void HTTPserver::parseACL(char * const acl, u_int acl_len) {
  char *net, *net_ctx, *slash, *sign, *acl_key;
  u_int32_t mask, bits, num = 0;
  struct in_addr ipaddr;
  const char * const comma = ",";

  if(!acl || !acl_len | !(acl_key = (char*)malloc(acl_len)))
    return;

  acl[0] = '\0';
  ntop->getRedis()->get((char*)HTTP_ACL_MANAGEMENT_PORT, acl_key, acl_len, true);

  if(acl_key[0] == '\0')
    snprintf(acl, acl_len, "+0.0.0.0/0");
  else {
    for(net = strtok_r(acl_key, comma, &net_ctx); net; net = strtok_r(NULL, comma, &net_ctx)) {
      sign = net++; /* Either a + or a - */

      if((slash = strchr(net, '/'))) {
	*slash++ = '\0';
	bits = atoi(slash);
	mask = 1 << (32 - bits);

	if(inet_pton(AF_INET, net, &ipaddr) == 1) {
	  ipaddr.s_addr = htonl(ntohl(ipaddr.s_addr) & ~(mask - 1));
	  snprintf(&acl[strlen(acl)], acl_len - strlen(acl) - 1,
		   "%s%c%s/%d",
		   num++ ? (char*)"," : (char*)"", *sign, inet_ntoa(ipaddr), bits);
	}
      }
    }
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Access Control List set to: %s", acl);
  }

  free(acl_key);
}

/* ****************************************** */

static unsigned char ssl_session_ctx_id[] = PACKAGE_NAME "-" NTOPNG_GIT_RELEASE;

int handle_ssl_verify(int ok, X509_STORE_CTX *ctx) {
  X509 *cert;
  char buf[256];
  int err, depth;

  cert = X509_STORE_CTX_get_current_cert(ctx);
  err = X509_STORE_CTX_get_error(ctx);
  depth = X509_STORE_CTX_get_error_depth(ctx);
  X509_NAME_oneline(X509_get_subject_name(cert), buf, sizeof(buf));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "ssl verify pre=%d cert=%s err=%i depth=%i",ok,buf,err,depth);
  // Never fail, continue SSL/TLS handshake, if client cert is invalid we want to fallback to explicit login 
  return 1;
};

int init_client_x509_auth(void *ctx) {
  char buf[256];
  char ssl_ca_path[MAX_PATH];
  char ssl_cert_path[MAX_PATH];
  STACK_OF(X509_NAME) *certnames;

  snprintf(ssl_cert_path, sizeof(ssl_cert_path), "%s/ssl/%s", ntop->getPrefs()->get_docs_dir(), CONST_HTTPS_CERT_NAME);
  snprintf(ssl_ca_path, sizeof(ssl_ca_path), "%s/ssl/%s", ntop->getPrefs()->get_docs_dir(),CONST_HTTPS_AUTHCA_FILE);

  ntop->fixPath(ssl_ca_path),
  ntop->fixPath(ssl_cert_path);

  if(!SSL_CTX_set_session_id_context((SSL_CTX*)ctx, ssl_session_ctx_id, sizeof(ssl_session_ctx_id)>SSL_MAX_SSL_SESSION_ID_LENGTH?SSL_MAX_SSL_SESSION_ID_LENGTH:sizeof(ssl_session_ctx_id))) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SSL session init failed: %s", ERR_reason_error_string(ERR_get_error()));
    return 0;
  }

  if(!SSL_CTX_load_verify_locations((SSL_CTX*)ctx, ssl_ca_path, NULL)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SSL load client CA from '%s' failed: %s",
				 ssl_ca_path,
				 ERR_reason_error_string(ERR_get_error()));
    return 0;
  }

  if(!SSL_CTX_use_certificate_file((SSL_CTX*)ctx, ssl_cert_path, 1)
     || !SSL_CTX_use_PrivateKey_file((SSL_CTX*)ctx, ssl_cert_path, 1))
    return 0;

  if((certnames = SSL_load_client_CA_file(ssl_ca_path))) {
    SSL_CTX_set_client_CA_list((SSL_CTX*)ctx, certnames);

    if((certnames = SSL_CTX_get_client_CA_list((SSL_CTX*)ctx))) {
      for(int i = 0; i < sk_X509_NAME_num(certnames); i++) {
	X509_NAME_oneline(sk_X509_NAME_value(certnames, i), buf, sizeof(buf));
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "SSL loaded CA #%i: %s", i, buf);
      }
    }
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "No SSL client loaded");

  SSL_CTX_set_verify((SSL_CTX*)ctx, SSL_VERIFY_PEER, handle_ssl_verify);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "SSL init [ssl_ca_path: %s][ssl_cert_path: %s]", ssl_ca_path, ssl_cert_path);

  return 1;
};

/* ****************************************** */

HTTPserver::HTTPserver(const char *_docs_dir, const char *_scripts_dir) {
  struct mg_callbacks callbacks;
  static char ports[256] = { 0 }, acl_management[64], ssl_cert_path[MAX_PATH], access_log_path[MAX_PATH] = { 0 };
  const char *http_binding_addr1, *http_binding_addr2;
  const char *https_binding_addr1, *https_binding_addr2;

  ntop->getPrefs()->get_http_binding_addresses(&http_binding_addr1, &http_binding_addr2);
  ntop->getPrefs()->get_https_binding_addresses(&https_binding_addr1, &https_binding_addr2);

  bool use_http = true;
  bool good_ssl_cert = false;
  wispr_captive_data = NULL;
  captive_redirect_addr = NULL;

  struct timeval tv;
  static char *http_options[] = {
    (char*)"listening_ports", ports,
    (char*)"enable_directory_listing", (char*)"no",
    (char*)"document_root",  (char*)_docs_dir,
    (char*)"access_control_list", acl_management,
    /* (char*)"extra_mime_types", (char*)"" */ /* see mongoose.c */
    (char*)"num_threads", (char*)"5",
    NULL, NULL, NULL, NULL,
    NULL
  };

  memset(&callbacks, 0, sizeof(callbacks));
  callbacks.begin_request = handle_lua_request;
  callbacks.log_message = handle_http_message;
  if(ntop->getPrefs()->is_client_x509_auth_enabled())
    callbacks.init_ssl = init_client_x509_auth;

  /* Randomize data */
  gettimeofday(&tv, NULL);
  srand(tv.tv_sec + tv.tv_usec);

  parseACL(acl_management, sizeof(acl_management));
  
  docs_dir = strdup(_docs_dir), scripts_dir = strdup(_scripts_dir);
  ssl_enabled = false;
  httpserver = this;
#ifdef HAVE_NEDGE
  httpd_captive_v4 = NULL;
#endif

  if(ntop->getPrefs()->get_http_port() == 0) use_http = false;

  if(use_http) {
    snprintf(ports, sizeof(ports), "%s%s%d",
	     http_binding_addr1,
	     (http_binding_addr1[0] == '\0') ? "" : ":",
	     ntop->getPrefs()->get_http_port());

    if(http_binding_addr2[0] && strcmp(http_binding_addr1, http_binding_addr2)) {
      snprintf(&ports[strlen(ports)],
	     sizeof(ports) - strlen(ports) - 1, ",%s:%d",
	     http_binding_addr2,
	     ntop->getPrefs()->get_http_port());
    }
  }

  good_ssl_cert = check_ssl_cert(ssl_cert_path, sizeof(ssl_cert_path));
  if(good_ssl_cert && ntop->getPrefs()->get_https_port() > 0) {
    ssl_enabled = true;
    int i;

    for(i = 0; http_options[i] != NULL; i++) ;
    http_options[i] = (char*)"ssl_certificate", http_options[i+1] = ssl_cert_path;

    snprintf(&ports[strlen(ports)],
	     sizeof(ports) - strlen(ports) - 1,
	     "%s%s%s%ds",
	     use_http ? (char*)"," : "",
	     https_binding_addr1,
	     (https_binding_addr1[0] == '\0') ? "" : ":",
	     ntop->getPrefs()->get_https_port());

    if(http_binding_addr2[0] && strcmp(https_binding_addr1, https_binding_addr2)) {
      snprintf(&ports[strlen(ports)],
	     sizeof(ports) - strlen(ports) - 1, ",%s:%d",
	     https_binding_addr2,
	     ntop->getPrefs()->get_https_port());
    }
  }

  if((!use_http) && (!ssl_enabled)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Starting the HTTP server on the default port");
    snprintf(ports, sizeof(ports), "%d", ntop->getPrefs()->get_http_port());
    use_http = true;
  }

  if(ntop->getPrefs()->is_access_log_enabled()) {
    int i;

    snprintf(access_log_path, sizeof(access_log_path), "%s/ntopng_access.log",
	     ntop->get_working_dir());

    for(i=0; http_options[i] != NULL; i++)
      ;

    http_options[i] = (char*)"access_log_file", http_options[i+1] = access_log_path;
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "HTTP logs will be stored on %s", access_log_path);
  }

  /* mongoose */
  http_prefix = ntop->getPrefs()->get_http_prefix(),
    http_prefix_len = strlen(ntop->getPrefs()->get_http_prefix());

  httpd_v4 = mg_start(&callbacks, NULL, (const char**)http_options);

  if(httpd_v4 == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to start HTTP server (IPv4) on ports %s",
				 ports);
    if(errno)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", strerror(errno));

    ntop->getTrace()->traceEvent(TRACE_ERROR, "Either port in use or another ntopng instance is running (using the same port)");
    exit(-1);
  }
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Web server dirs [%s][%s]", docs_dir, scripts_dir);

  if(use_http)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "HTTP server listening on %s%s%d",
				 http_binding_addr1[0] != '\0' ? http_binding_addr1 : (char*)"",
				 http_binding_addr1[0] != '\0' ? (char*)":" : (char*)"",
				 ntop->getPrefs()->get_http_port());

  if(ssl_enabled)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "HTTPS server listening on %s%s%d",
				 https_binding_addr1[0] != '\0' ? https_binding_addr1 : (char*)"",
				 https_binding_addr1[0] != '\0' ? (char*)":" : (char*)"",
				 ntop->getPrefs()->get_https_port());
};

/* ****************************************** */

HTTPserver::~HTTPserver() {
  if(httpd_v4)         mg_stop(httpd_v4);
#ifdef HAVE_NEDGE
  if(httpd_captive_v4) mg_stop(httpd_captive_v4);
#endif

  if(wispr_captive_data) free(wispr_captive_data);
  if(captive_redirect_addr) free(captive_redirect_addr);
  free(docs_dir), free(scripts_dir);
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "HTTP server terminated");
};

/* ****************************************** */

#ifdef HAVE_NEDGE

void HTTPserver::startCaptiveServer() {
  struct mg_callbacks captive_callbacks;
  char captive_port[64];
  char access_log_path[MAX_PATH] = {0};

  snprintf(captive_port, sizeof(captive_port), "%u", CAPTIVE_PORTAL_PORT);

  static const char * http_captive_options[] = {
    (char*)"listening_ports", captive_port,
    (char*)"enable_directory_listing", (char*)"no",
    (char*)"document_root",  (char*)docs_dir,
    (char*)"num_threads", (char*)"10",
    NULL, NULL, NULL, NULL,
    NULL
  };

  if(ntop->getPrefs()->is_access_log_enabled()) {
    int i;

    snprintf(access_log_path, sizeof(access_log_path), "%s/captive_access.log",
	     ntop->get_working_dir());

    for(i=0; http_captive_options[i] != NULL; i++)
      ;

    http_captive_options[i] = (char*)"access_log_file", http_captive_options[i+1] = access_log_path;
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Captive portal HTTP logs will be stored on %s", access_log_path);
  }

  if(httpd_captive_v4) {
    mg_stop(httpd_captive_v4);
    httpd_captive_v4 = NULL;
  }
  
  if(ntop->getPrefs()->isCaptivePortalEnabled()) {
    /* TODO: make simpler callbacks for the captive portal */
    memset(&captive_callbacks, 0, sizeof(captive_callbacks));
    captive_callbacks.begin_request = handle_lua_request;
    captive_callbacks.log_message = handle_http_message;

    httpd_captive_v4 = mg_start(&captive_callbacks, NULL, http_captive_options);
    
    if(httpd_captive_v4 == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to start HTTP (captive) server (IPv4) on port %s. "
				   "Captive portal needs port %s. Make sure this port"
				   "is not in use by ntopng (option -w) or by any other process.",
				   captive_port, captive_port);
      
      if(errno)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", strerror(errno));
      
      exit(-1);
    } else
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "HTTP (captive) server listening on port %s",
				   captive_port);
  }
}
#endif 

/* ****************************************** */
