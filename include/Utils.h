/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _UTILS_H_
#define _UTILS_H_

#include "ntop_includes.h"

typedef unsigned long long ticks;

#ifdef WIN32
#define _usleep(a) win_usleep(a)
#else
#define _usleep(a) usleep(a)
#endif

/* ******************************* */

class Utils {
 private:

 public:
  static char* jsonLabel(int label,const char *label_str, char *buf, u_int buf_len);
  static char* formatTraffic(float numBits, bool bits, char *buf, u_int buf_len);
  static char* formatPackets(float numPkts, char *buf, u_int buf_len);
  static char* l4proto2name(u_int8_t proto);
  static bool  isIPAddress(char *name);
  static int   setThreadAffinity(pthread_t thread, int core_id);
  static char* trim(char *s);
  static u_int32_t hashString(char *s);
  static float timeval2ms(struct timeval *tv);
  static bool file_exists(const char *path);
  static bool mkdir_tree(char *path);
  static const char* trend2str(ValueTrend t);
  static void dropPrivileges();
  static std::string base64_encode(unsigned char const* bytes_to_encode, unsigned int in_len);
  static std::string base64_decode(std::string const& encoded_string);
  static bool dumpHostToDB(IpAddress *host, LocationPolicy policy);
  static double pearsonValueCorrelation(activity_bitmap *x, activity_bitmap *y);
  static double JaccardSimilarity(activity_bitmap *x, activity_bitmap *y);
  static int ifname2id(const char *name);
  static char* sanitizeHostName(char *str);
  static char* urlDecode(const char *src, char *dst, u_int dst_len);
  static bool isUserAdministrator(lua_State* vm);
  static void purifyHTTPparam(char *param, bool strict);
  static char* stripHTML(const char * const str);
  static bool postHTTPJsonData(char *username, char *password, char *url, char *json);
  static bool httpGet(lua_State* vm, char *url, char *username, 
		      char *password, int timeout, bool return_content);
  static char* urlEncode(char *url);
  static char* curlHTTPGet(char *url, long *http_code);
  static bool httpGet(char *url, char *ret_buf, u_int ret_buf_len);
  static ticks getticks();
  static char* getURL(char *url, char *buf, u_int buf_len);
  static bool discardOldFilesExceeding(const char *path, const unsigned long max_size);
  static void readMac(char *ifname, dump_mac_t mac_addr);
  static u_int32_t getMaxIfSpeed(const char *ifname);
  static u_int16_t getIfMTU(const char *ifname);
  static bool isGoodNameToCategorize(char *name);
  static char* get2ndLevelDomain(char *_domainname);
  static char* tokenizer(char *arg, int c, char **data);
  static char* intoaV4(unsigned int addr, char* buf, u_short bufLen);
  static char* intoaV6(struct ndpi_in6_addr ipv6, u_int8_t bitmask, char* buf, u_short bufLen);
};

#endif /* _UTILS_H_ */
