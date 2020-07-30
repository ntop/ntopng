/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef _HTTP_SERVER_H_
#define _HTTP_SERVER_H_

#include "ntop_includes.h"

/* Global used for enabling/disabling user authentication */
extern bool enable_users_login;

class HTTPserver {
 private:
  bool use_http, can_accept_requests;
  char *docs_dir, *scripts_dir;
  struct mg_context *httpd_v4;
  bool ssl_enabled, gui_access_restricted;
  char *captive_redirect_addr;
  char *wispr_captive_data;
  bool check_ssl_cert(char *ssl_cert_path, size_t ssl_cert_path_len);
  char ports[256], acl_management[64], ssl_cert_path[MAX_PATH], access_log_path[MAX_PATH];
  char plugins_httpdocs_rewrite[MAX_PATH];
  const char *http_binding_addr1, *http_binding_addr2;
  const char *https_binding_addr1, *https_binding_addr2;
  const char *http_options[32];
  int cur_http_options;

  void addHTTPOption(const char *k, const char*v);
  void startHttpServer();
  
  static void parseACL(char * const acl, u_int acl_len);
#ifdef HAVE_NEDGE
  struct mg_context *httpd_captive_v4;
#endif

 public:
  HTTPserver(const char *_docs_dir, const char *_scripts_dir);
  ~HTTPserver();

  bool valid_user_pwd(char *user, char *pass);
  static bool authorized_localhost_user_login(const struct mg_connection *conn);
  static void traceLogin(const char *user, bool authorized);

  bool authorize_noconn(char *username, char *session_id, u_int session_id_size);

  inline char*     get_docs_dir()    { return(docs_dir);         };
  inline char*     get_scripts_dir() { return(scripts_dir);      };
  inline bool      is_ssl_enabled()  { return(ssl_enabled);      };
  inline bool      is_gui_access_restricted() { return(gui_access_restricted); };
  inline void      start_accepting_requests() { can_accept_requests = true; };
  bool accepts_requests();

  inline const char* getWisprCaptiveData() { return(wispr_captive_data ? wispr_captive_data : ""); }
  inline const char* getCaptiveRedirectAddress() { return(captive_redirect_addr ? captive_redirect_addr : ""); }
  void setCaptiveRedirectAddress(const char*addr);

#ifdef HAVE_NEDGE
  void startCaptiveServer();
  void stopCaptiveServer();
#endif
};

extern int send_error(struct mg_connection *conn, int status, const char *reason, const char *fmt, ...);
extern int redirect_to_error_page(struct mg_connection *conn,
				  const struct mg_request_info *request_info,
				  const char *i18n_message,
				  char *script_path, char *error_message);

const char *get_secure_cookie_attributes(const struct mg_request_info *request_info);

/* mongoose */
extern int url_decode(const char *src, int src_len, char *dst, int dst_len, int is_form_url_encoded);

#endif /* _HTTP_SERVER_H_ */
