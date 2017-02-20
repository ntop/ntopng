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

#define IDLE_DOMAIN_USE 300

struct site_categories {
  u_int8_t categories[MAX_NUM_CATEGORIES];
};

struct category_mapping {
  char *name;         /* key */
  u_int8_t category;  /* value */
  UT_hash_handle hh;  /* makes this structure hashable */
};

struct domain_cache_entry {
  char *domain;      /* key */
  bool query_in_progress;
  struct site_categories categories;
  u_int32_t last_use;
  UT_hash_handle hh; /* makes this structure hashable */
};

class Flashstart {
  int sock;
  struct sockaddr_in dnsServer[NUM_FLASHSTART_SERVERS];
  u_int16_t num_cached_entries;
  u_int32_t num_flashstart_categorizations, num_flashstart_fails;
  char *user, *pwd, *rev_mapping[MAX_NUM_MAPPED_CATEGORIES];
  u_int8_t numDnsServers, dnsServerIdx;
  struct category_mapping *mapping;
  struct domain_cache_entry *domain_cache;
  pthread_t flashstartThreadLoop;
  u_int8_t numCategories;
  bool syncClassification;
  Mutex m;
  
  void initMapping();
  void purgeMapping();
  void addMapping(const char *label, u_int8_t id);
  int parseDNSResponse(unsigned char *rsp, int rsp_len, struct sockaddr_in *from);
  u_int recvResponses(u_int msecTimeout);
  void queryDomain(int sock, char *domain, u_int queryId,
		   const struct sockaddr *to, socklen_t tolen);
  void setCategory(struct site_categories *category, char *rsp);
  bool cacheDomainCategory(char *name, struct site_categories *category, bool check_if_present);
  void purgeCache(u_int32_t idle_purge_time);
  char* category2str(struct site_categories *category, char *buf, int buf_len);
  
 public:
  Flashstart(char *_user, char *_pwd,
	     char *alt_dns_ip, u_int16_t alt_dns_port,
	     bool synchronousClassification);
  ~Flashstart();

  inline u_int8_t getNumCategories() { return(numCategories); }
  int findMapping(char *label);
  void startLoop();
  void queryFlashstart(char *symbolic_name);
  void* flashstartLoop(void* ptr);
  bool findCategory(char *name, struct site_categories *category, bool add_if_needed);
  void dumpCategories(lua_State* vm, struct site_categories *category);
  void lua(lua_State* vm);
  void dumpCategories(struct site_categories *category, char *buf, u_int buf_len);
  char* getCategoryName(u_int8_t id);
};

#endif /* _FLASHSTART_H_ */
