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
  static float msTimevalDiff(const struct timeval *end, const struct timeval *begin);
  static size_t file_write(const char *path, const char *content, size_t content_len);
  static size_t file_read(const char *path, char **content);
  static bool file_exists(const char *path);
  static bool mkdir_tree(char *path);
  static int mkdir(const char *pathname, mode_t mode);
  static const char* trend2str(ValueTrend t);
  static int dropPrivileges();
  static std::string base64_encode(unsigned char const* bytes_to_encode, unsigned int in_len);
  static std::string base64_decode(std::string const& encoded_string);
  static bool dumpHostToDB(IpAddress *host, LocationPolicy policy);
  static double pearsonValueCorrelation(activity_bitmap *x, activity_bitmap *y);
  static double JaccardSimilarity(activity_bitmap *x, activity_bitmap *y);
  static int ifname2id(const char *name);
  static char* sanitizeHostName(char *str);
  static char* urlDecode(const char *src, char *dst, u_int dst_len);
  static bool isUserAdministrator(lua_State* vm);
  static bool purifyHTTPparam(char *param, bool strict, bool allowURL, bool allowDots);
  static char* stripHTML(const char * const str);
  static bool postHTTPJsonData(char *username, char *password, char *url, char *json, HTTPTranferStats *stats);
  static bool sendMail(char *from, char *to, char *message, char *smtp_server);
  static bool postHTTPTextFile(char *username, char *password, char *url, char *path, int timeout, HTTPTranferStats *stats);
  static bool httpGetPost(lua_State* vm, char *url, char *username,
		      char *password, int timeout, bool return_content,
		      bool use_cookie_authentication, HTTPTranferStats *stats, const char *form_data);
  static long httpGet(const char * const url,
		      const char * const username, const char * const password,
		      int timeout,
		      char * const resp, const u_int resp_len);
  static char* urlEncode(char *url);
  static ticks getticks();
  static char* getURL(char *url, char *buf, u_int buf_len);
  static bool discardOldFilesExceeding(const char *path, const unsigned long max_size);
  static bool discardOldFiles(char *path, int older_than_seconds);
  static u_int64_t macaddr_int(const u_int8_t *mac);
  static void readMac(char *ifname, dump_mac_t mac_addr);
  static u_int32_t readIPv4(char *ifname);
  static u_int32_t getMaxIfSpeed(const char *ifname);
  static u_int16_t getIfMTU(const char *ifname);
  static bool isGoodNameToCategorize(char *name);
  static char* get2ndLevelDomain(char *_domainname);
  static char* tokenizer(char *arg, int c, char **data);
  static in_addr_t inet_addr(const char *cp);
  static char* intoaV4(unsigned int addr, char* buf, u_short bufLen);
  static char* intoaV6(struct ndpi_in6_addr ipv6, u_int8_t bitmask, char* buf, u_short bufLen);
  static u_int32_t timeval2usec(const struct timeval *tv);
  static void xor_encdec(u_char *data, int data_len, u_char *key);
  static bool isPrintableChar(u_char c);
  static const char* flowStatus2str(FlowStatus s, AlertType *aType, AlertLevel *aLevel);
  static char* formatMac(u_int8_t *mac, char *buf, u_int buf_len);
  static void  parseMac(u_int8_t *mac, const char *symMac);
  static u_int32_t macHash(u_int8_t *mac);
  static bool isSpecialMac(u_int8_t *mac);
  static int numberOfSetBits(u_int32_t i);
  static void initRedis(Redis **r, const char *redis_host, const char *redis_password, u_int16_t redis_port, u_int8_t _redis_db_id);
  static bool str2DetailsLevel(const char *details, DetailsLevel *out);
  static u_int32_t roundTime(u_int32_t now, u_int32_t rounder, int32_t offset_from_utc);
  static bool isCriticalNetworkProtocol(u_int16_t protocol_id);
  static u_int32_t stringHash(const char *s);

  /* Patricia Tree */
  static patricia_node_t* ptree_match(patricia_tree_t *tree, int family, void *addr, int bits);
  static patricia_node_t* ptree_add_rule(patricia_tree_t *ptree, char *line);
  static int ptree_remove_rule(patricia_tree_t *ptree, char *line);

  static inline void update_ewma(u_int32_t sample, u_int32_t *ewma, u_int8_t alpha_percent) {
    if(alpha_percent > 100) alpha_percent = 100;
    if(!ewma) return;
    (*ewma) = (alpha_percent * sample + (100 - alpha_percent) * (*ewma)) / 100;
  }
  static inline u_int64_t toUs(struct timeval *t) { return(((u_int64_t)t->tv_sec)*1000000+((u_int64_t)t->tv_usec)); };
  static void replacestr(char *line, const char *search, const char *replace);
  static u_int32_t getHostManagementIPv4Address();
  static bool isInterfaceUp(char *ifname);
  static bool maskHost(bool isLocalIP);
  static char* getInterfaceDescription(char *ifname, char *buf, int buf_len);
  static int bindSockToDevice(int sock, int family, const char* devicename);
  static void maximizeSocketBuffer(int sock_fd, bool rx_buffer, u_int max_buf_mb);
  static u_int32_t parsetime(char *str);
  static u_int64_t mac2int(u_int8_t *mac);
  static u_int8_t* int2mac(u_int64_t mac, u_int8_t *buf);
  
  /* System Host Montoring and Diagnose Functions */
  static void luaCpuLoad(lua_State* vm);
  static void luaMeminfo(lua_State* vm);
  static int retainWriteCapabilities();
  static int gainWriteCapabilities();
  static int dropWriteCapabilities();
  static u_int32_t findInterfaceGatewayIPv4(const char* ifname);

  /* Data Format */
  static char* formatTraffic(float numBits, bool bits, char *buf);
  static char* formatPackets(float numPkts, char *buf);

  /* Pcap files utiles */
  static void init_pcap_header(struct pcap_file_header * const h, NetworkInterface * const iface);
};

#endif /* _UTILS_H_ */
