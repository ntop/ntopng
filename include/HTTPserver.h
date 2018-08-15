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

#ifndef _HTTP_SERVER_H_
#define _HTTP_SERVER_H_

#include "ntop_includes.h"

/* Global used for enabling/disabling user authentication */
extern bool enable_users_login;

class HTTPserver {
 private:
  char *docs_dir, *scripts_dir;
  struct mg_context *httpd_v4;
  bool ssl_enabled;
  char *captive_redirect_addr;
  char *wispr_captive_data;
  bool check_ssl_cert(char *ssl_cert_path, size_t ssl_cert_path_len);

  static void parseACL(char * const acl, u_int acl_len);
#ifdef HAVE_NEDGE
  struct mg_context *httpd_captive_v4;
#endif

 public:
  HTTPserver(const char *_docs_dir, const char *_scripts_dir);
  ~HTTPserver();

  bool valid_user_pwd(char *user, char *pass);
  static bool authorized_localhost_user_login(const struct mg_connection *conn);

  inline char*     get_docs_dir()    { return(docs_dir);         };
  inline char*     get_scripts_dir() { return(scripts_dir);      };
  inline bool      is_ssl_enabled()  { return(ssl_enabled);      };

  inline const char* getWisprCaptiveData() { return(wispr_captive_data ? wispr_captive_data : ""); }
  inline const char* getCaptiveRedirectAddress() { return(captive_redirect_addr ? captive_redirect_addr : ""); }
  void setCaptiveRedirectAddress(const char*addr);

#ifdef HAVE_NEDGE
  void startCaptiveServer();
  void stopCaptiveServer();
#endif
};

extern int send_error(struct mg_connection *conn, int status, const char *reason, const char *fmt, ...);
const char *get_secure_cookie_attributes(const struct mg_request_info *request_info);

/* mongoose */
extern int url_decode(const char *src, int src_len, char *dst, int dst_len, int is_form_url_encoded);

#endif /* _HTTP_SERVER_H_ */
