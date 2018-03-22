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
  u_int16_t http_splash_port;
  
 public:
  HTTPserver(const char *_docs_dir, const char *_scripts_dir);
  ~HTTPserver();

  bool valid_user_pwd(char *user, char *pass);
  
  inline char*     get_docs_dir()    { return(docs_dir);         };
  inline char*     get_scripts_dir() { return(scripts_dir);      };
  inline bool      is_ssl_enabled()  { return(ssl_enabled);      };
  inline u_int16_t getSplashPort()   { return(http_splash_port); };
};

extern int send_error(struct mg_connection *conn, int status, const char *reason, const char *fmt, ...);

/* mongoose */
extern int url_decode(const char *src, int src_len, char *dst, int dst_len, int is_form_url_encoded);

#endif /* _HTTP_SERVER_H_ */
