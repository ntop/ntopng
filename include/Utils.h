/*
 *
 * (C) 2013-21 - ntop.org
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
  static bool validInterfaceName(const char *name);
  static bool validInterfaceDescription(const char *description);
  static bool validInterface(const pcap_if_t *pcap_if);

public:
  static char* jsonLabel(int label,const char *label_str, char *buf, u_int buf_len);
  static char* formatTraffic(float numBits, bool bits, char *buf, u_int buf_len);
  static char* formatPackets(float numPkts, char *buf, u_int buf_len);
  static const char* edition2name(NtopngEdition ntopng_edition);
  static char* l4proto2name(u_int8_t proto);
  static u_int8_t l4name2proto(const char *name);
  static u_int8_t queryname2type(const char *name);
  static bool  isIPAddress(char *name);
#ifdef __linux__ 
  static int   setAffinityMask(char *cores_list, cpu_set_t *mask);
  static int   setThreadAffinityWithMask(pthread_t thread, cpu_set_t *mask);
#endif
  static int   setThreadAffinity(pthread_t thread, int core_id);
  static void  setThreadName(const char *name);
  static char* trim(char *s);
  static u_int32_t hashString(const char * const s);
  static float timeval2ms(const struct timeval *tv);
  static float msTimevalDiff(const struct timeval *end, const struct timeval *begin);
  static u_int32_t usecTimevalDiff(const struct timeval *end, const struct timeval *begin);
  /* Returns the difference new_value - cur_value and then stores new_value in *cur_value */
  template<typename T> static inline T uintDiff(T *cur_value, T new_value) {
    T res = new_value > *cur_value ? new_value - *cur_value : 0;
    *cur_value = new_value;
    return res;
  };
  static size_t file_write(const char *path, const char *content, size_t content_len);
  static size_t file_read(const char *path, char **content);
  static bool file_exists(const char * const path);
  static bool dir_exists(const char * const path);
  static bool mkdir_tree(char * const path);
  static int mkdir(const char *pathname, mode_t mode);
  static int remove_recursively(const char * const path);
  static const char* trend2str(ValueTrend t);
  static int dropPrivileges();
  static char* base64_encode(unsigned char const* bytes_to_encode, ssize_t in_len);
  static std::string base64_decode(std::string const& encoded_string);
  static void sha1_hash(const u_int8_t message[], size_t len, uint32_t hash[STATE_LEN]);
  static double pearsonValueCorrelation(activity_bitmap *x, activity_bitmap *y);
  static double JaccardSimilarity(activity_bitmap *x, activity_bitmap *y);
  static int ifname2id(const char *name);
  static char* stringtolower(char *str);
  static char* sanitizeHostName(char *str);
  static char* urlDecode(const char *src, char *dst, u_int dst_len);
  static bool purifyHTTPparam(char * const param, bool strict, bool allowURL, bool allowDots);
  static char* stripHTML(const char * const str);
  static bool sendTCPData(char *host, int port, char *data, int timeout);
  static bool postHTTPJsonData(char *username, char *password, char *url,
			       char *json, int timeout, HTTPTranferStats *stats);
  static bool postHTTPJsonData(char *username, char *password, char *url,
			       char *json, int timeout,
			       HTTPTranferStats *stats, char *return_data,
			       int return_data_size, int *response_code);
  static bool sendMail(lua_State* vm, char *from, char *to, char *cc, char *message, char *smtp_server, char *username, char *password);
  static bool postHTTPTextFile(lua_State* vm, char *username, char *password,
			       char *url, char *path, int timeout, HTTPTranferStats *stats);
  static bool httpGetPost(lua_State* vm, char *url,
			  char *username, char *password, char *user_header_token,
			  int timeout, bool return_content,
			  bool use_cookie_authentication, HTTPTranferStats *stats, const char *form_data,
			  char *write_fname, bool follow_redirects, int ip_version);
  static long httpGet(const char * const url,
		      const char * const username, const char * const password, const char * const user_header_token,
		      int timeout,
		      char * const resp, const u_int resp_len);
  static bool progressCanContinue(ProgressState *progressState);
  static char* urlEncode(const char *url);
  static ticks getticks();
  static ticks gettickspersec();
  static char* getURL(char *url, char *buf, u_int buf_len);
  inline static u_int8_t getFlowRiskScore(ndpi_risk_enum risk) {
    ndpi_risk r = 0; u_int16_t c, s;
    ndpi_risk2score(NDPI_SET_BIT(r, risk), &c, &s);
    return c + s;
  }
  static bool discardOldFilesExceeding(const char *path, const unsigned long max_size);
  static u_int64_t macaddr_int(const u_int8_t *mac);
  static char *ifname2devname(const char *ifname, char *devname, int devname_size);
  static void readMac(char *ifname, dump_mac_t mac_addr);
  static u_int32_t readIPv4(char *ifname);
  static bool readIPv6(char *ifname, struct in6_addr *sin);
  static u_int32_t getMaxIfSpeed(const char *ifname);
  static u_int16_t getIfMTU(const char *ifname);
  static int ethtoolGet(const char *ifname, int cmd, uint32_t *v);
  static int ethtoolSet(const char *ifname, int cmd, uint32_t v);
  static int disableOffloads(const char *ifname);
  static bool isGoodNameToCategorize(char *name);
  static char* get2ndLevelDomain(char *_domainname);
  static char* tokenizer(char *arg, int c, char **data);
  static in_addr_t inet_addr(const char *cp);
  static char* intoaV4(unsigned int addr, char* buf, u_short bufLen);
  static char* intoaV6(struct ndpi_in6_addr ipv6, u_int8_t bitmask, char* buf, u_short bufLen);
  static u_int32_t timeval2usec(const struct timeval *tv);
  static void xor_encdec(u_char *data, int data_len, u_char *key);
  static bool isPrintableChar(u_char c);
  static char* formatMac(const u_int8_t * const mac, char *buf, u_int buf_len);
  static void  parseMac(u_int8_t *mac, const char *symMac);
  static u_int32_t macHash(const u_int8_t * const mac);
  static bool isEmptyMac(u_int8_t *mac);
  static bool isSpecialMac(u_int8_t *mac);
  static bool isBroadcastMac(u_int8_t *mac);
  static int numberOfSetBits(u_int32_t i);
  static void initRedis(Redis **r, const char *redis_host, const char *redis_password,
			u_int16_t redis_port, u_int8_t _redis_db_id, bool giveup_on_failure);
  static json_object *cloneJSONSimple(json_object *src);

  /* ScriptPeriodicity */
  static const char* periodicityToScriptName(ScriptPeriodicity p);
  static int periodicityToSeconds(ScriptPeriodicity p);

  /* eBPF-related */
  static int tcpStateStr2State(const char * const state_str);
  static const char * tcpState2StateStr(int state);
  static eBPFEventType eBPFEventStr2Event(const char * const event_str);
  static const char * eBPFEvent2EventStr(eBPFEventType event);

  static bool str2DetailsLevel(const char *details, DetailsLevel *out);
  static u_int32_t roundTime(u_int32_t now, u_int32_t rounder, int32_t offset_from_utc);
  static bool isCriticalNetworkProtocol(u_int16_t protocol_id);
  static u_int32_t stringHash(const char *s);
  static const char* policySource2Str(L7PolicySource_t policy_source);
  static const char* captureDirection2Str(pcap_direction_t dir);
  static bool readInterfaceStats(const char* ifname, ProtoStats *in_stats, ProtoStats *out_stats);
  static bool shouldResolveHost(const char *host_ip);
  static bool mg_write_retry(struct mg_connection *conn, u_char *b, int len);
  static bool parseAuthenticatorJson(HTTPAuthenticator *auth, char *content);
  static void freeAuthenticator(HTTPAuthenticator *auth);
  static DetailsLevel bool2DetailsLevel(bool max, bool higher,bool normal = false);

  /* Patricia Tree */
  static ndpi_patricia_node_t* add_to_ptree(ndpi_patricia_tree_t *tree, int family, void *addr, int bits);
  static ndpi_patricia_node_t* ptree_match(ndpi_patricia_tree_t *tree, int family, const void * const addr, int bits);
  static ndpi_patricia_node_t* ptree_add_rule(ndpi_patricia_tree_t *ptree, const char * const line);
  static bool ptree_prefix_print(ndpi_prefix_t *prefix, char *buffer, size_t bufsize);

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
  static time_t str2epoch(const char *str);
  static u_int64_t mac2int(u_int8_t *mac);
  static u_int8_t* int2mac(u_int64_t mac, u_int8_t *buf);
  static void listInterfaces(lua_State* vm); 
  static bool validInterface(const ntop_if_t *ntop_if);
  static void containerInfoLua(lua_State *vm, const ContainerInfo * const cont);
  static char *ntop_lookupdev(char *ifname_out, int ifname_size);
  /**
   * @brief Return all the available interfaces
   * @details Return all the available interfaces, unifying data from PF_RING and pcap, and excluding invalid interfaces
   *          Interfaces are returned as a linked-list in the **alldevsp parameter.
   *
   * @return returns 0 on success and -1 on failure
  */
  static int ntop_findalldevs(ntop_if_t **alldevsp);
  /**
   * @brief Free data returned with `Utils::ntop_findalldevs`
   * @details Frees data allocated during the call to `Utils::ntop_findalldevs`
   *
   * @return void
  */
  static void ntop_freealldevs(ntop_if_t *alldevs);

  /* System Host Montoring and Diagnose Functions */
  static bool getCPULoad(cpu_load_stats *out);
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

  /* Bitmap functions */
  static bool bitmapIsSet(u_int64_t bitmap, u_int8_t v);  
  static u_int64_t bitmapSet(u_int64_t bitmap, u_int8_t v);  
  static u_int64_t bitmapClear(u_int64_t bitmap, u_int8_t v);

  static inline u_int64_t bitmapOr(u_int64_t bitmap1, u_int64_t bitmap2) {
    return(bitmap1 | bitmap2);
  }

  static OSType getOSFromFingerprint(const char *fingerprint, const char*manuf, DeviceType devtype);
  static DeviceType getDeviceTypeFromOsDetail(const char *os_detail);
  static u_int32_t pow2(u_int32_t v);
  static int exec(const char * const command);
#ifdef __linux__
  static void deferredExec(const char * const command);
#endif
  static void tlv2lua(lua_State *vm, ndpi_serializer *serializer);
  static u_int16_t country2u16(const char *country_code);
  static bool isNumber(const char *s, unsigned int s_len, bool *is_float);
  static bool isPingSupported();
  static ScoreCategory mapAlertToScoreCategory(AlertCategory check_category);
  /* Map alert score to AlertLevel */
  static AlertLevel mapScoreToSeverity(u_int32_t score);
  /* Map AlertLevel to score */
  static u_int8_t mapSeverityToScore(AlertLevel alert_level);
  /*
    Maps an AlertLevel into the corresponding AlertLevelGroup. Alert level groups
    are used to 'compress' alert levels into a reduced number of (grouped) levels.
   */
  static AlertLevelGroup mapAlertLevelToGroup(AlertLevel alert_level);
  static bool hasExtension(const char *path, const char *ext);
#ifndef WIN32
  static int mapSyslogFacilityTextToValue(const char *facility_text);
#endif
  static void buildSqliteAllowedNetworksFilters(lua_State *vm);
  static void make_session_key(char *buf, u_int buf_len);
};

#endif /* _UTILS_H_ */
