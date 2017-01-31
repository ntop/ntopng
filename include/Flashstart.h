/*
 *
 * (C) 2016-17 - ntop.org
 *
 *
 * This program is free software; you can addresstribute it and/or modify
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

#ifndef _FLASHSTART_H_
#define _FLASHSTART_H_

#include "ntop_includes.h"

struct site_categories {
  u_int8_t categories[MAX_NUM_CATEGORIES];
};

struct category_mapping {
  char *name;   /* key */
  u_int8_t category; /* value */
  UT_hash_handle hh;         /* makes this structure hashable */
};

class Flashstart {
  int sock;
  struct sockaddr_in dnsServer[NUM_FLASHSTART_SERVERS];
  u_int32_t num_flashstart_categorizations, num_flashstart_fails;
  char *user, *pwd;
  u_int8_t dnsServerIdx;
  struct category_mapping *mapping;
  pthread_t flashstartThreadLoop;
  u_int8_t numCategories;
  bool syncClassification;
  
  void initMapping();
  void purgeMapping();
  void addMapping(const char *label, u_int8_t id);
  int parseDNSResponse(unsigned char *rsp, int rsp_len, struct sockaddr_in *from);
  u_int recvResponses(u_int msecTimeout);
  void queryDomain(int sock, char *domain, u_int queryId,
		   const struct sockaddr *to, socklen_t tolen);     
  void setCategory(struct site_categories *category, char *rsp);

 public:
  Flashstart(char *_user, char *_pwd, bool synchronousClassification);
  ~Flashstart();

  inline u_int8_t getNumCategories() { return(numCategories); }
  int findMapping(char *label);
  void startLoop();
  void queryFlashstart(char *symbolic_name);
  void* flashstartLoop(void* ptr);
  bool findCategory(char *name, struct site_categories *category, bool add_if_needed); 
  void dumpCategories(lua_State* vm, struct site_categories *category);
  void dumpCategories(struct site_categories *category, char *buf, u_int buf_len);
  char* getCategoryName(u_int8_t id);
};

#endif /* _FLASHSTART_H_ */
