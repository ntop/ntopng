/*
 *
 * (C) 2013-16 - ntop.org
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

#include <curl/curl.h>
#include <string.h>

// A simple struct for strings.
typedef struct {
  char *s;
  size_t l;
} String;

typedef struct {
  char outbuf[65536];
  u_int num_bytes;
} DownloadState;

/* ****************************************************** */

char* Utils::jsonLabel(int label, const char *label_str,char *buf, u_int buf_len){
  if(ntop->getPrefs()->json_labels_as_strings()) {
    snprintf(buf, buf_len, "%s", label_str);
  } else
    snprintf(buf, buf_len, "%d", label);

  return(buf);
}

/* ****************************************************** */

char* Utils::formatTraffic(float numBits, bool bits, char *buf, u_int buf_len) {
  char unit;

  if(bits)
    unit = 'b';
  else
    unit = 'B';

  if(numBits < 1024) {
    snprintf(buf, buf_len, "%lu %c", (unsigned long)numBits, unit);
  } else if(numBits < 1048576) {
    snprintf(buf, buf_len, "%.2f K%c", (float)(numBits)/1024, unit);
  } else {
    float tmpMBits = ((float)numBits)/1048576;

    if(tmpMBits < 1024) {
      snprintf(buf, buf_len, "%.2f M%c", tmpMBits, unit);
    } else {
      tmpMBits /= 1024;

      if(tmpMBits < 1024) {
	snprintf(buf, buf_len, "%.2f G%c", tmpMBits, unit);
      } else {
	snprintf(buf, buf_len, "%.2f T%c", (float)(tmpMBits)/1024, unit);
      }
    }
  }

  return(buf);
}

/* ****************************************************** */

char* Utils::formatPackets(float numPkts, char *buf, u_int buf_len) {
  if(numPkts < 1000) {
    snprintf(buf, buf_len, "%.2f", numPkts);
  } else if(numPkts < 1000000) {
    snprintf(buf, buf_len, "%.2f K", numPkts/(float)1000);
  } else {
    numPkts /= 1000000;
    snprintf(buf, buf_len, "%.2f M", numPkts);
  }

  return(buf);
}

/* ****************************************************** */

char* Utils::l4proto2name(u_int8_t proto) {
  static char proto_string[8];

  /* NOTE: keep in sync with /lua/pro/db_explorer_data.lua */

  switch(proto) {
  case 0:   return((char*)"IP");
  case 1:   return((char*)"ICMP");
  case 2:   return((char*)"IGMP");
  case 6:   return((char*)"TCP");
  case 17:  return((char*)"UDP");
  case 41:  return((char*)"IPv6");
  case 46:  return((char*)"RSVP");
  case 47:  return((char*)"GRE");
  case 50:  return((char*)"ESP");
  case 58:  return((char*)"IPv6-ICMP");
  case 89:  return((char*)"OSPF");
  case 103: return((char*)"PIM");
  case 112: return((char*)"VRRP");
  case 139: return((char*)"HIP");

  default:
    snprintf(proto_string, sizeof(proto_string), "%u", proto);
    return(proto_string);
  }
}

/* ****************************************************** */

#ifdef NOTUSED
bool Utils::isIPAddress(char *ip) {
  struct in_addr addr4;
  struct in6_addr addr6;

  if((ip == NULL) || (ip[0] == '\0'))
    return(false);

  if(strchr(ip, ':') != NULL) { /* IPv6 */
    if(inet_pton(AF_INET6, ip, &addr6) == 1)
      return(true);
  } else {
    if(inet_pton(AF_INET, ip, &addr4) == 1)
      return(true);
  }

  return(false);
}
#endif

/* ****************************************************** */

int Utils::setThreadAffinity(pthread_t thread, int core_id) {
  if(core_id < 0)
    return(0);
  else {
    int ret = -1;
#ifdef linux
    u_int num_cores = ntop->getNumCPUs();
    u_long core = core_id % num_cores;
    cpu_set_t cpu_set;

    if(num_cores > 1) {
      CPU_ZERO(&cpu_set);
      CPU_SET(core, &cpu_set);
      ret = pthread_setaffinity_np(thread, sizeof(cpu_set_t), &cpu_set);
    }

#endif
    return ret;
  }
}

/* ****************************************************** */

char *Utils::trim(char *s) {
  char *end;

  while(isspace(s[0]) || (s[0] == '"') || (s[0] == '\'')) s++;
  if(s[0] == 0) return s;

  end = &s[strlen(s) - 1];
  while(end > s
	&& (isspace(end[0])|| (end[0] == '"') || (end[0] == '\'')))
    end--;
  end[1] = 0;

  return s;
}

/* ****************************************************** */

u_int32_t Utils::hashString(char *key) {
	u_int32_t hash = 0, len = (u_int32_t)strlen(key);

  for(u_int32_t i=0; i<len; i++)
    hash += ((u_int32_t)key[i])*i;

  return(hash);
}

/* ****************************************************** */

float Utils::timeval2ms(struct timeval *tv) {
  return((float)tv->tv_sec*1000+(float)tv->tv_usec/1000);
}

/* ****************************************************** */

u_int32_t Utils::timeval2usec(const struct timeval *tv) {
  return(tv->tv_sec*1000000+tv->tv_usec);
}

/* ****************************************************** */

float Utils::msTimevalDiff(struct timeval *end, struct timeval *begin) {
  if((end->tv_sec == 0) && (end->tv_usec == 0))
    return(0);
  else {
    float f = (end->tv_sec-begin->tv_sec)*1000+((float)(end->tv_usec-begin->tv_usec))/(float)1000;

    return((f < 0) ? 0 : f);
  }
}

/* ****************************************************** */

bool Utils::file_exists(const char *path) {
  std::ifstream infile(path);

 /*  ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(): %s", __FUNCTION__, path); */
  bool ret = infile.good();
  infile.close();
  return ret;
}

/* ****************************************************** */

bool Utils::mkdir_tree(char *path) {
  int rc;
  struct stat s;

  ntop->fixPath(path);

  if(stat(path, &s) != 0) {
    int permission = 0777;

    /* Start at 1 to skip the root */
    for(int i=1; path[i] != '\0'; i++)
      if(path[i] == CONST_PATH_SEP) {
#ifdef WIN32
	/* Do not create devices directory */
	if((i > 1) && (path[i-1] == ':')) continue;
#endif

        /*
         * If we are already handling the final portion
         * of a path, e.g. because the path has a trailing
         * CONST_PATH_SEP, do not create the final
         * directory: it will be created later.
         */
        if(path[i+1] == '\0')
          break;
	path[i] = '\0';
	rc = ntop_mkdir(path, permission);
	path[i] = CONST_PATH_SEP;
      }

    rc = ntop_mkdir(path, permission);

	return(((rc == 0) || (errno == EEXIST/* Already existing */)) ? true : false);
  } else
    return(true); /* Already existing */
}

/* **************************************************** */

const char* Utils::flowStatus2str(FlowStatus s, AlertType *aType) {
  *aType = alert_flow_misbehaviour; /* Default */
  
  switch(s) {
  case status_normal:
    *aType = alert_none;
    return("Normal");
    break;
  case status_slow_tcp_connection:
    return("Slow TCP Connection");
    break;
  case status_slow_application_header:
    return("Slow Application Header");
    break;
  case status_slow_data_exchange:
    return("Slow Data Exchange (Slowloris?)");
    break;
  case status_low_goodput:
    return("Low Goodput");
    break;
  case status_suspicious_tcp_syn_probing:
    *aType = alert_suspicious_activity;
    return("Suspicious TCP SYN Probing (or server port down)");
    break;
  case status_tcp_connection_issues:
    return("TCP Connection Issues");
    break;
  case status_suspicious_tcp_probing:
    *aType = alert_suspicious_activity;
    return("Suspicious TCP Probing");
  case status_flow_when_interface_alerted:
    *aType = alert_interface_alerted;
    return("Flow emitted during alerted interface");
  case status_tcp_connection_refused:
    *aType = alert_suspicious_activity;
    return("TCP connection refused");
  default:
    return("Unknown status");
    break;
  }
}

/* **************************************************** */

const char* Utils::trend2str(ValueTrend t) {
  switch(t) {
  case trend_up:
    return("Up");
    break;

  case trend_down:
    return("Down");
    break;

  case trend_stable:
    return("Stable");
    break;

  default:
  case trend_unknown:
    return("Unknown");
    break;
  }
}

/* **************************************************** */

int Utils::dropPrivileges() {
#ifndef WIN32
  struct passwd *pw = NULL;
  const char *username;

  if(getgid() && getuid()) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Privileges are not dropped as we're not superuser");
    return -1;
  }

  username = ntop->getPrefs()->get_user();
  pw = getpwnam(username);

  if(pw == NULL) {
    username = "anonymous";
    pw = getpwnam(username);
  }

  if(pw != NULL) {
    /* Drop privileges */
    if((setgid(pw->pw_gid) != 0) || (setuid(pw->pw_uid) != 0)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to drop privileges [%s]",
				   strerror(errno));
      return -1;
    }
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "User changed to %s", username);
  } else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate user %s", username);
    return -1;
  }
  umask(0);
#endif
  return 0;
}


/* **************************************************** */

/* http://www.adp-gmbh.ch/cpp/common/base64.html */
static const std::string base64_chars =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  "abcdefghijklmnopqrstuvwxyz"
  "0123456789+/";


static inline bool is_base64(unsigned char c) {
  return (isalnum(c) || (c == '+') || (c == '/'));
}

/* **************************************************** */

#ifdef NOTUSED
std::string Utils::base64_encode(unsigned char const* bytes_to_encode, unsigned int in_len) {
  std::string ret;
  int i = 0;
  unsigned char char_array_3[3];
  unsigned char char_array_4[4];

  while (in_len--) {
    char_array_3[i++] = *(bytes_to_encode++);
    if(i == 3) {
      char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
      char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
      char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
      char_array_4[3] = char_array_3[2] & 0x3f;

      for(i = 0; (i <4) ; i++)
        ret += base64_chars[char_array_4[i]];
      i = 0;
    }
  }

  if(i) {
    for(int j = i; j < 3; j++)
      char_array_3[j] = '\0';

    char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
    char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
    char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
    char_array_4[3] = char_array_3[2] & 0x3f;

    for(int j = 0; (j < i + 1); j++)
      ret += base64_chars[char_array_4[j]];

    while((i++ < 3))
      ret += '=';

  }

  return ret;
}
#endif

/* **************************************************** */

std::string Utils::base64_decode(std::string const& encoded_string) {
  int in_len = encoded_string.size();
  int i = 0, in_ = 0;
  unsigned char char_array_4[4], char_array_3[3];
  std::string ret;

  while (in_len-- && ( encoded_string[in_] != '=') && is_base64(encoded_string[in_])) {
    char_array_4[i++] = encoded_string[in_]; in_++;

    if(i == 4) {
      for(i = 0; i <4; i++)
        char_array_4[i] = base64_chars.find(char_array_4[i]);

      char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
      char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
      char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

      for(i = 0; (i < 3); i++)
        ret += char_array_3[i];
      i = 0;
    }
  }

  if(i) {
    int j;

    for(j = i; j <4; j++)
      char_array_4[j] = 0;

    for(j = 0; j <4; j++)
      char_array_4[j] = base64_chars.find(char_array_4[j]);

    char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
    char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
    char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

    for(j = 0; (j < i - 1); j++) ret += char_array_3[j];
  }

  return ret;
}

/* **************************************************** */

bool Utils::dumpHostToDB(IpAddress *host, LocationPolicy policy) {
  bool do_dump = false;
  int16_t network_id;

  switch(policy) {
  case location_local_only:
    if(host->isLocalHost(&network_id)) do_dump = true;
    break;
  case location_remote_only:
    if(!host->isLocalHost(&network_id)) do_dump = true;
    break;
  case location_all:
    do_dump = true;
    break;
  case location_none:
    do_dump = false;
    break;
  }

  return(do_dump);
}

/* *************************************** */

double Utils::pearsonValueCorrelation(activity_bitmap *x, activity_bitmap *y) {
  double ex = 0, ey = 0, sxx = 0, syy = 0, sxy = 0, tiny_value = 1e-2;

  for(size_t i = 0; i < NUM_MINUTES_PER_DAY; i++) {
    /* Find the means */
    ex += x->counter[i], ey += y->counter[i];
  }

  ex /= NUM_MINUTES_PER_DAY, ey /= NUM_MINUTES_PER_DAY;

  for(size_t i = 0; i < NUM_MINUTES_PER_DAY; i++) {
    /* Compute the correlation coefficient */
    double xt = x->counter[i] - ex, yt = y->counter[i] - ey;

    sxx += xt * xt, syy += yt * yt, sxy += xt * yt;
  }

  return (sxy/(sqrt(sxx*syy)+tiny_value));
}

/* *************************************** */
/* XXX: it assumes that the vectors are bitmaps */
double Utils::JaccardSimilarity(activity_bitmap *x, activity_bitmap *y) {
  size_t inter_card = 0, union_card = 0;

  for(size_t i = 0; i < NUM_MINUTES_PER_DAY; i++) {
    union_card += x->counter[i] | y->counter[i];
    inter_card += x->counter[i] & y->counter[i];
  }

  if(union_card == 0)
    return(1e-2);

  return ((double)inter_card/union_card);
}

/* *************************************** */

#ifdef WIN32
const char *strcasestr(const char *haystack, const char *needle) {
  int i=-1;

  while (haystack[++i] != '\0') {
    if(tolower(haystack[i]) == tolower(needle[0])) {
      int j=i, k=0, match=0;
      while (tolower(haystack[++j]) == tolower(needle[++k])) {
	match=1;
	// Catch case when they match at the end
	//printf("j:%d, k:%d\n",j,k);
	if(haystack[j] == '\0' && needle[k] == '\0') {
	  //printf("Mj:%d, k:%d\n",j,k);
	  return &haystack[i];
	}
      }
      // Catch normal case
      if(match && needle[k] == '\0'){
	// printf("Norm j:%d, k:%d\n",j,k);
	return &haystack[i];
      }
    }
  }

  return NULL;
}
#endif

/* **************************************************** */

int Utils::ifname2id(const char *name) {
  char rsp[256];

  if(name == NULL)                    return(-1);
  else if(!strncmp(name, "dummy", 5)) return(DUMMY_IFACE_ID);
  else if(!strncmp(name, "stdin", 5) || !strncmp(name, "-", 1)) return(STDIN_IFACE_ID);

  if(ntop->getRedis()->hashGet((char*)CONST_IFACE_ID_PREFS, (char*)name, rsp, sizeof(rsp)) == 0) {
    /* Found */
    return(atoi(rsp));
  } else {
    for(int idx=0; idx<255; idx++) {
      char key[256];

      snprintf(key, sizeof(key), "%d", idx);
      if(ntop->getRedis()->hashGet((char*)CONST_IFACE_ID_PREFS, key, rsp, sizeof(rsp)) < 0) {
	/* Free Id */

	snprintf(rsp, sizeof(rsp), "%d", idx);
	ntop->getRedis()->hashSet((char*)CONST_IFACE_ID_PREFS, (char*)name, rsp);
	ntop->getRedis()->hashSet((char*)CONST_IFACE_ID_PREFS, rsp, (char*)name);
	return(idx);
      }
    }
  }

  return(DUMMY_IFACE_ID); /* This can't happen, hopefully */
}

/* **************************************************** */

/* http://en.wikipedia.org/wiki/Hostname */

char* Utils::sanitizeHostName(char *str) {
  int i;

  for(i=0; str[i] != '\0'; i++) {
    if(((str[i] >= 'a') && (str[i] <= 'z'))
       || ((str[i] >= 'A') && (str[i] <= 'Z'))
       || ((str[i] >= '0') && (str[i] <= '9'))
       || (str[i] == '-')
       || (str[i] == '_')
       || (str[i] == '.')
       || (str[i] == ':') /* Used in HTTP host:port */
       || (str[i] == '@') /* Used by DNS but not a valid char */)
      ;
    else if(str[i] == '_') {
      str[i] = '\0';
      break;
    } else
      str[i] = '_';
  }

  return(str);
}

/* **************************************************** */

char* Utils::stripHTML(const char * const str) {
    if (!str) return NULL;
    int len = strlen(str), j = 0;
    char *stripped_str = NULL;
    try {
        stripped_str = new char[len + 1];
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;
      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }
      return NULL;
    }

    // scan string
    for (int i = 0; i < len; i++) {
        // found an open '<', scan for its close
        if (str[i] == '<') {
            // charge ahead in the string until it runs out or we find what we're looking for
            for (; i < len && str[i] != '>'; i++);
        } else {
            stripped_str[j] = str[i];
            j++;
        }
    }
    stripped_str[j] = 0;
    return stripped_str;
}

/* **************************************************** */

char* Utils::urlDecode(const char *src, char *dst, u_int dst_len) {
  char *ret = dst;
  u_int i = 0;

  dst_len--; /* Leave room for \0 */
  dst[dst_len] = 0;

  while((*src) && (i < dst_len)) {
    char a, b;

    if((*src == '%') &&
       ((a = src[1]) && (b = src[2]))
       && (isxdigit(a) && isxdigit(b))) {
      char h[3] = { a, b, 0 };
      char hexval = (char)strtol(h, (char **)NULL, 16);

      //      if(iswprint(hexval))
	*dst++ = hexval;

      src += 3;
    } else
      *dst++ = *src++;

    i++;
  }

  *dst++ = '\0';
  return(ret);
}

/* **************************************************** */

/**
 * @brief Check if the current user is an administrator
 *
 * @param vm   The lua state.
 * @return true if the current user is an administrator, false otherwise.
 */
bool Utils::isUserAdministrator(lua_State* vm) {
  char *username;
  char key[64], val[64];

  lua_getglobal(vm, "user");
  if((username = (char*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%s): NO", __FUNCTION__, "???");
    return(false); /* Unknown */
  }

  if(!strncmp(username, NTOP_NOLOGIN_USER, strlen(username)))
    return(true);

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0) {
    return(!strcmp(val, NTOP_NOLOGIN_USER) ||
           !strcmp(val, CONST_ADMINISTRATOR_USER));
  } else {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%s): NO", __FUNCTION__, username);
    return(false); /* Unknown */
  }
}

/* **************************************************** */


/**
 * @brief Purify the HTTP parameter
 *
 * @param param   The parameter to purify (remove unliked chars with _)
 */

static const char* xssAttempts[] = {
  "<?import",
  "<applet",
  "<base",
  "<embed",
  "<frame",
  "<iframe",
  "<implementation",
  "<import",
  "<link",
  "<meta",
  "<object",
  "<script",
  "<style",
  "charset",
  "classid",
  "code",
  "codetype",
  /* "data", */
  "href",
  "http-equiv",
  "javascript:",
  "vbscript:",
  "vmlframe",
  "xlink:href",
  "=",
  NULL
};

/* ************************************************************ */

/* http://www.ascii-code.com */

bool Utils::isPrintableChar(u_char c) {
  if(isprint(c)) return(true);

  if((c >= 192) && (c <= 255))
    return(true);

  return(false);
}

/* ************************************************************ */

void Utils::purifyHTTPparam(char *param, bool strict, bool allowURL) {
  if(strict) {
    for(int i=0; xssAttempts[i] != NULL; i++) {
      if(strstr(param, xssAttempts[i])) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Found possible XSS attempt: %s [%s]", param, xssAttempts[i]);
	param[0] = '\0';
	return;
      }
    }
  }

  for(int i=0; param[i] != '\0'; i++) {
    bool is_good;

    if(strict) {
      is_good =
        ((param[i] >= 'a') && (param[i] <= 'z'))
	|| ((param[i] >= 'A') && (param[i] <= 'Z'))
	|| ((param[i] >= '0') && (param[i] <= '9'))
	// || (param[i] == ':')
	// || (param[i] == '-')
	|| (param[i] == '_')
	// || (param[i] == '/')
	|| (param[i] == '@')
	// || (param[i] == ',')
	// || (param[i] == '.')
	;
    } else {
      is_good = Utils::isPrintableChar(param[i])
	&& (param[i] != '<')
	&& (param[i] != '>');
    }

    if(is_good)
      ; /* Good: we're on the whitelist */
    else
      param[i] = '_'; /* Invalid char: we discard it */

    if((i > 0)
       && (((param[i] == '.') && (param[i-1] == '.'))
	   || ((!allowURL) && ((param[i] == '/') && (param[i-1] == '/')))
	   || ((param[i] == '\\') && (param[i-1] == '\\'))
	   )) {
      /* Make sure we do not have .. in the variable that can be used for future hacking */
      param[i-1] = '_', param[i] = '_'; /* Invalidate the path */
    }
  }
}

/* **************************************************** */

/**
 * @brief Implement HTTP POST of JSON data
 *
 * @param username  Username to be used on post or NULL if missing
 * @param password  Password to be used on post or NULL if missing
 * @param url       URL where to post data to
 * @param json      The content of the POST
 * @return true if post was successfull, false otherwise.
 */

static int curl_writefunc(void *ptr, size_t size, size_t nmemb, void *stream) {
  char *str = (char*)ptr;

  ntop->getTrace()->traceEvent(TRACE_INFO, "[JSON] %s", str);
  return(size*nmemb);
}

/* **************************************** */

bool Utils::postHTTPJsonData(char *username, char *password, char *url, char *json) {
  CURL *curl;
  bool ret = true;

  curl = curl_easy_init();
  if(curl) {
    CURLcode res;
    struct curl_slist* headers = NULL;

    curl_easy_setopt(curl, CURLOPT_URL, url);

    if((username && (username[0] != '\0'))
       || (password && (password[0] != '\0'))) {
      char auth[64];

      snprintf(auth, sizeof(auth), "%s:%s",
	       username ? username : "",
	       password ? password : "");
      curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
    }

    if(!strncmp(url, "https", 5)) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(json));
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc);

    res = curl_easy_perform(curl);

    if(res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Unable to post data to (%s): %s",
				   url, curl_easy_strerror(res));
      ret = false;
    } else
      ntop->getTrace()->traceEvent(TRACE_INFO, "Posted JSON to %s", url);

    /* always cleanup */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  return(ret);
}

/* **************************************** */

/* curl calls this routine to get more data */
static size_t curl_get_writefunc(char *buffer, size_t size,
				 size_t nitems, void *userp) {
  DownloadState *state = (DownloadState*)userp;
  int len = size*nitems;
  int diff = sizeof(state->outbuf) - state->num_bytes - 1;

  if(diff > 0) {
    int buff_diff = min(diff, len);

    if(buff_diff > 0) {
      strncpy(&state->outbuf[state->num_bytes], buffer, buff_diff);
      state->num_bytes += buff_diff;
      state->outbuf[state->num_bytes] = '\0';
    }
  }

  return(len);
}

/* **************************************** */

bool Utils::httpGet(lua_State* vm, char *url, char *username,
		    char *password, int timeout,
		    bool return_content) {
  CURL *curl;
  bool ret = true;

  curl = curl_easy_init();

  if(curl) {
    DownloadState *state = NULL;
    long response_code;
    char *content_type, *redirection;
    char ua[64];

    curl_easy_setopt(curl, CURLOPT_URL, url);

    if(username || password) {
      char auth[64];

      snprintf(auth, sizeof(auth), "%s:%s",
	       username ? username : "",
	       password ? password : "");
      curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
    }

    if(!strncmp(url, "https", 5)) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    if(return_content) {
      state = (DownloadState*)malloc(sizeof(DownloadState));
      if(state != NULL) {
	memset(state, 0, sizeof(DownloadState));

	curl_easy_setopt(curl, CURLOPT_WRITEDATA, state);
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_get_writefunc);
      } else {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
	curl_easy_cleanup(curl);
	return(false);
      }
    }
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);

#ifdef CURLOPT_CONNECTTIMEOUT_MS
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout*1000);
#endif

    snprintf(ua, sizeof(ua), "%s [%s][%s]",
	     PACKAGE_STRING, PACKAGE_MACHINE, PACKAGE_OS);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, ua);

    if(vm) lua_newtable(vm);

    if(curl_easy_perform(curl) == CURLE_OK) {
      if(return_content && vm) {
	lua_push_str_table_entry(vm, "CONTENT", state->outbuf);
	lua_push_int_table_entry(vm, "CONTENT_LEN", state->num_bytes);
      }

      ret = true;
    } else
      ret = false;

    if(vm) {
      if(curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) == CURLE_OK)
	lua_push_int_table_entry(vm, "RESPONSE_CODE", response_code);

      if((curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &content_type) == CURLE_OK) && content_type)
	lua_push_str_table_entry(vm, "CONTENT_TYPE", content_type);

      if(curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &redirection) == CURLE_OK)
	lua_push_str_table_entry(vm, "EFFECTIVE_URL", redirection);
    }

    if(return_content && state)
      free(state);

    /* always cleanup */
    curl_easy_cleanup(curl);
  }

  return(ret);
}

/* **************************************** */

char* Utils::getURL(char *url, char *buf, u_int buf_len) {
  struct stat s;

  if(!ntop->getPrefs()->is_pro_edition())
    return(url);

  snprintf(buf, buf_len, "%s/lua/pro%s",
	   ntop->get_HTTPserver()->get_scripts_dir(),
	   &url[4]);

  ntop->fixPath(buf);
  if((stat(buf, &s) == 0) && (S_ISREG(s.st_mode))) {
    u_int l = strlen(ntop->get_HTTPserver()->get_scripts_dir());
    char *new_url = &buf[l];

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "===>>> %s", new_url);
    return(new_url);
  } else
    return(url);
}

/* **************************************** */

// Support functions for 'urlEncode'.

#ifdef NOTUSED
static char to_hex(char code) {
  static char hex[] = "0123456789ABCDEF";
  return hex[code & 15];
}
#endif

/* **************************************************** */

#ifdef NOTUSED
static int alphanum(char code) {
  int i;
  static char alnum[] = "0123456789abcdefghijklmnopqrstuvwxyz";
  for (i = 0; i < 36; i++) {
    if(code == alnum[i]) return 1;
  }
  return 0;
}
#endif

/* **************************************************** */

// Encodes a URL to hexadecimal format.
#ifdef NOTUSED
char* Utils::urlEncode(char *url) {
  char *pstr = url;
  char *buf = (char *) malloc(strlen(url) * 3 + 1);
  char *pbuf = buf;
  while (*pstr) {
    if(alphanum(*pstr) || *pstr == '-' || *pstr == '_' || *pstr == '.' || *pstr == '~') {
      *pbuf++ = *pstr;
    }
    else {
      if(*pstr == ' ') *pbuf++ = '+';
      else {
        *pbuf++ = '%';
        *pbuf++ = to_hex(*pstr >> 4);
        *pbuf++ = to_hex(*pstr & 15);
      }
    }
    pstr++;
  }
  *pbuf = '\0';
  return buf;
}
#endif

/* **************************************** */

// The following one initializes a new string.
#ifdef NOTUSED
static void newString(String *str) {
  str->l = 0;
  str->s = (char *) malloc((str->l) + 1);
  if(str->s == NULL) {
    fprintf(stderr, "ERROR: malloc() failed!\n");
    exit(EXIT_FAILURE);
  }
  else {
    str->s[0] = '\0';
  }
  return;
}
#endif

/* **************************************************** */

// This callback function will be passed to 'curl_easy_setopt' in order to write curl output to a variable.
#ifdef NOTUSED
static size_t writeFunc(void *ptr, size_t size, size_t nmemb, String *str) {
  size_t new_len = str->l + (size * nmemb);
  str->s = (char *) realloc(str->s, new_len + 1);
  if(str->s == NULL) {
    fprintf(stderr, "ERROR: realloc() failed!\n");
    exit(EXIT_FAILURE);
  }
  memcpy(str->s+str->l, ptr, size * nmemb);
  str->s[new_len] = '\0';
  str->l = new_len;

  return (size * nmemb);
}
#endif

/* **************************************************** */

#ifdef NOTUSED
// Adding this function that performs a simple HTTP GET request using libcurl.
// The function returns a string that contains the reply.
char* Utils::curlHTTPGet(char *url, long *http_code) {
  CURL *curl;
  CURLcode res;
  String replyString;
  long replyCode = 0;

  curl = curl_easy_init();
  if(curl) {
    newString(&replyString);
    curl_easy_setopt(curl, CURLOPT_URL, url);
    // Uncomment the following line for redirection support.
    //curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeFunc);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &replyString);
    res = curl_easy_perform(curl);
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &replyCode);
    if(res != CURLE_OK) {
      fprintf(stderr, "ERROR: curl_easy_perform failed with code %s.\n", curl_easy_strerror(res));
    }
    *http_code = replyCode;
    curl_easy_cleanup(curl);
    return replyString.s;
  }
  return NULL;
}
#endif

/* **************************************** */

bool Utils::httpGet(char *url, char *ret_buf, u_int ret_buf_len) {
  CURL *curl;
  bool ret = true;

  curl = curl_easy_init();
  if(curl) {
    curl_version_info_data *v;
    DownloadState *state;
    char ua[64];

    curl_easy_setopt(curl, CURLOPT_URL, url);

    if(!strncmp(url, "https", 5)) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    state = (DownloadState*)malloc(sizeof(DownloadState));
    if(state != NULL) {
      memset(state, 0, sizeof(DownloadState));

      curl_easy_setopt(curl, CURLOPT_WRITEDATA, state);
      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_get_writefunc);
    } else {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
      curl_easy_cleanup(curl);
      return(false);
    }

    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10 /* sec */);

    v = curl_version_info(CURLVERSION_NOW);
    snprintf(ua, sizeof(ua), "ntopng v.%s (curl %s)", PACKAGE_VERSION, v->version);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, ua);

    if(curl_easy_perform(curl) == CURLE_OK)
      snprintf(ret_buf, ret_buf_len, "%s", state->outbuf);
    else
      ret_buf[0] = '\0';

    free(state);

    /* always cleanup */
    curl_easy_cleanup(curl);
  }

  return(ret);
}

/* **************************************** */

#ifdef WIN32
ticks Utils::getticks() {
  struct timeval tv;
  gettimeofday (&tv, 0);

  return (((ticks)tv.tv_usec) + (((ticks)tv.tv_sec) * 1000000LL));
}

#else
ticks Utils::getticks() {
#if defined(__i386__)
  ticks x;

  __asm__ volatile (".byte 0x0f, 0x31" : "=A" (x));
  return x;
#elif defined(__x86_64__)
  u_int32_t a, d;

  asm volatile("rdtsc" : "=a" (a), "=d" (d));
  return (((ticks)a) | (((ticks)d) << 32));

  /*
    __asm __volatile("rdtsc" : "=A" (x));
    return (x);
  */
#else /* ARM, MIPS.... (not very fast) */
  struct timeval tv;
  gettimeofday (&tv, 0);

  return (((ticks)tv.tv_usec) + (((ticks)tv.tv_sec) * 1000000LL));
#endif
}
#endif

/* **************************************** */

bool scan_dir(const char * dir_name, list<dirent *> *dirlist,
              unsigned long *total) {
  DIR *d;
  struct stat file_stats;

  d = opendir (dir_name);
  if(!d) return false;

  while (1) {
    struct dirent *entry;
    const char *d_name;

    entry = readdir (d);
    if(!entry) break;
    d_name = entry->d_name;
    if(!(entry->d_type & DT_DIR)) {
      if(!stat(entry->d_name, &file_stats)) {
        struct dirent *temp = (struct dirent *)malloc(sizeof(struct dirent));
        memcpy(temp, entry, sizeof(struct dirent));
        dirlist->push_back(entry);
        total += file_stats.st_size;
      }
    }

    if(entry->d_type & DT_DIR) {
      if(strncmp (d_name, "..", 2) != 0 &&
          strncmp (d_name, ".", 1) != 0) {
        int path_length;
        char path[MAX_PATH];

        path_length = snprintf (path, MAX_PATH,
                                "%s/%s", dir_name, d_name);
        if(path_length >= MAX_PATH)
          return false;
        scan_dir(path, dirlist, total);
      }
    }
  }
  if(closedir (d)) return false;

  return true;
}

/* **************************************** */

bool dir_size_compare(const struct dirent *d1, const struct dirent *d2) {
  struct stat sa, sb;
  if(stat(d1->d_name, &sa) || stat(d2->d_name, &sb)) return false;
  if(S_ISDIR(sa.st_mode) && S_ISDIR(sb.st_mode)) {
    if(sa.st_mtime < sb.st_mtime) return false;
    else return true;
  }
  return false;
}

/* **************************************** */

bool Utils::discardOldFilesExceeding(const char *path, const unsigned long max_size) {
  unsigned long total = 0;
  list<struct dirent *> dirlist;
  list<struct dirent *>::iterator it;
  struct stat st;

  if(path == NULL || !strncmp(path, "", MAX_PATH))
    return false;

  /* First, get a list of all non-dir dirents and compute total size */
  if(!scan_dir(path, &dirlist, &total)) return false;

  if(total < max_size) return true;

  /* Second, sort the list by file size */
  dirlist.sort(dir_size_compare);

  /* Third, trasverse list and delete until we go below quota */
  for (it = dirlist.begin(); it != dirlist.end(); ++it) {
    stat((*it)->d_name, &st);
    unlink((*it)->d_name);
    total -= st.st_size;
    if(total < max_size) break;
  }
  for (it = dirlist.begin(); it != dirlist.end(); ++it)
    free(*it);

  return true;
}

/* **************************************** */

char* Utils::formatMac(u_int8_t *mac, char *buf, u_int buf_len) {
  if(mac == NULL)
    snprintf(buf, buf_len, "00:00:00:00:00:00");
  else
    snprintf(buf, buf_len, "%02X:%02X:%02X:%02X:%02X:%02X",
	   mac[0] & 0xFF, mac[1] & 0xFF,
	   mac[2] & 0xFF, mac[3] & 0xFF,
	   mac[4] & 0xFF, mac[5] & 0xFF);    
  return(buf);
}

/* **************************************** */

u_int64_t Utils::macaddr_int(const u_int8_t *mac) {
  if(mac == NULL)
    return(0);
  else {
    u_int64_t mac_int = 0;

    for(u_int8_t i=0; i<6; i++){
      mac_int |= (mac[i] & 0xFF) << (5-i)*8;
    }
    
    return mac_int;
  }
}

/* **************************************** */

#ifdef linux

void Utils::readMac(char *_ifname, dump_mac_t mac_addr) {
  int _sock, res;
  struct ifreq ifr;
  macstr_t mac_addr_buf;
  char *colon, *at;
  char ifname[32];

  memset (&ifr, 0, sizeof(struct ifreq));

  /* Handle PF_RING interfaces zc:ens2f1@3 */
  colon = strchr(_ifname, ':');
  if (colon != NULL) /* removing pf_ring module prefix (e.g. zc:ethX) */
    _ifname = colon+1;

  snprintf(ifname, sizeof(ifname), "%s", _ifname);
  at = strchr(ifname, '@');
  if(at != NULL)
    at[0] = '\0';

  /* Dummy socket, just to make ioctls with */
  _sock = socket(PF_INET, SOCK_DGRAM, 0);
  strncpy(ifr.ifr_name, ifname, IFNAMSIZ-1);
  res = ioctl(_sock, SIOCGIFHWADDR, &ifr);
  if(res < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot get hw addr for %s", ifname);
  } else
    memcpy(mac_addr, ifr.ifr_ifru.ifru_hwaddr.sa_data, 6);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Interface %s has MAC %s",
			       ifname,
			       formatMac((u_int8_t *)mac_addr, mac_addr_buf, sizeof(mac_addr_buf)));
  close(_sock);
}
#else
void Utils::readMac(char *ifname, dump_mac_t mac_addr) {
  memset(mac_addr, 0, 6);
}
#endif

/* **************************************** */

u_int16_t Utils::getIfMTU(const char *ifname) {
#ifdef WIN32
  return(CONST_DEFAULT_MAX_PACKET_SIZE);
#else
  struct ifreq ifr;
  u_int32_t max_packet_size = CONST_DEFAULT_MAX_PACKET_SIZE; /* default */
  int fd;

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
  ifr.ifr_addr.sa_family = AF_INET;

  if((fd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
  } else {
    if(ioctl(fd, SIOCGIFMTU, &ifr) == -1)
      ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read MTU for device %s", ifname);
    else {
      max_packet_size = ifr.ifr_mtu + sizeof(struct ndpi_ethhdr) + sizeof(Ether80211q);

      if(max_packet_size > ((u_int16_t)-1))
	max_packet_size = ((u_int16_t)-1);
    }

    closesocket(fd);
  }

  return((u_int16_t) max_packet_size);
#endif
}

/* **************************************** */

u_int32_t Utils::getMaxIfSpeed(const char *ifname) {
#if defined(linux) && (!defined(__GNUC_RH_RELEASE__) || (__GNUC_RH_RELEASE__ != 44))
  int sock, rc;
  struct ifreq ifr;
  struct ethtool_cmd edata;
  u_int32_t ifSpeed = 1000;

  if(strncmp(ifname, "zc:", 3) == 0) ifname = &ifname[3];

  memset(&ifr, 0, sizeof(struct ifreq));

  sock = socket(PF_INET, SOCK_DGRAM, 0);
  if(sock < 0) {
    // ntop->getTrace()->traceEvent(TRACE_ERROR, "Socket error [%s]", ifname);
    return(ifSpeed);
  }

  strncpy(ifr.ifr_name, ifname, IFNAMSIZ-1);
  ifr.ifr_data = (char *) &edata;

  // Do the work
  edata.cmd = ETHTOOL_GSET;

  rc = ioctl(sock, SIOCETHTOOL, &ifr);
  if(rc < 0) {
    // ntop->getTrace()->traceEvent(TRACE_ERROR, "I/O Control error [%s]", ifname);
    return(ifSpeed);
  }

  // Set the speed to edata.speed
  ethtool_cmd_speed(&edata);

  ifSpeed = edata.speed;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Interface %s has MAC Speed = %u",
			       ifname, edata.speed);

  closesocket(sock);

  return(ifSpeed);
#else
  return(1000);
#endif
}

/* **************************************** */

bool Utils::isGoodNameToCategorize(char *name) {
  if((name[0] == '\0')
     || (strchr(name, '.') == NULL) /* Missing domain */
     || (!strcmp(name, "Broadcast"))
     || (!strcmp(name, "localhost"))
     || strchr((const char*)name, ':') /* IPv6 */
     || (strstr(name, "in-addr.arpa"))
     || (strstr(name, "ip6.arpa"))
     || (strstr(name, "_dns-sd._udp"))
     )
    return(false);
  else
    return(true);
}

/* **************************************** */

char* Utils::get2ndLevelDomain(char *_domainname) {
  int i, found = 0;

  for(i=(int)strlen(_domainname)-1, found = 0; (found != 2) && (i > 0); i--) {
    if(_domainname[i] == '.') {
      found++;

      if(found == 2) {
	return(&_domainname[i+1]);
      }
    }
  }

  return(_domainname);
}

/* ****************************************************** */

char* Utils::tokenizer(char *arg, int c, char **data) {
  char *p = NULL;

  if((p = strchr(arg, c)) != NULL) {
    *p = '\0';
    if(data) {
      if(strlen(arg))
        *data = strdup(arg);
      else
        *data = strdup("");
    }

    arg = &(p[1]);
  } else if(data) {
    if(arg)
      *data = strdup(arg);
    else
      *data = NULL;
  }

  return (arg);
}

/* ****************************************************** */

char* Utils::intoaV4(unsigned int addr, char* buf, u_short bufLen) {
  char *cp, *retStr;
  int n;

  cp = &buf[bufLen];
  *--cp = '\0';

  n = 4;
  do {
    u_int byte = addr & 0xff;

    *--cp = byte % 10 + '0';
    byte /= 10;
    if(byte > 0) {
      *--cp = byte % 10 + '0';
      byte /= 10;
      if(byte > 0)
	*--cp = byte + '0';
    }
    *--cp = '.';
    addr >>= 8;
  } while (--n > 0);

  /* Convert the string to lowercase */
  retStr = (char*)(cp+1);

  return(retStr);
}

/* ****************************************************** */

char* Utils::intoaV6(struct ndpi_in6_addr ipv6, u_int8_t bitmask, char* buf, u_short bufLen) {
  char *ret;

  for(int32_t i = bitmask, j = 0; i > 0; i -= 8, ++j)
    ipv6.u6_addr.u6_addr8[j] &= i >= 8 ? 0xff : (u_int32_t)(( 0xffU << ( 8 - i ) ) & 0xffU );

  ret = (char*)inet_ntop(AF_INET6, &ipv6, buf, bufLen);

  if(ret == NULL) {
    /* Internal error (buffer too short) */
    buf[0] = '\0';
    return(buf);
  } else
    return(ret);
}

/* ****************************************************** */

void Utils::xor_encdec(u_char *data, int data_len, u_char *key) {
  int i, y;

  for(i = 0, y = 0; i < data_len; i++) {
    data[i] ^= key[y++];
    if(key[y] == 0) y = 0;
  }
}

/* ****************************************************** */

u_int32_t Utils::macHash(u_int8_t *mac) {
  if(mac == NULL)
    return(0);
  else {
    u_int32_t hash = 0; 
    
    for(int i=0; i<6; i++)
      hash += mac[i] << (i+1);
    
    return(hash);
  }
}

/* ****************************************************** */

/* https://en.wikipedia.org/wiki/Multicast_address */
bool Utils::isSpecialMac(u_int8_t *mac) {
  u_int16_t v2 = (mac[0] << 8) + mac[1];
  u_int32_t v3 = (mac[0] << 16) + (mac[1] << 8) + mac[2];

  switch(v3) {
  case 0x01000C:
  case 0x0180C2:
  case 0x01005E:
  case 0x010CCD:
  case 0x011B19:
    return(true);
  }

  switch(v2) {
  case 0xFFFF:
  case 0x3333:
    return(true);
    break;
  }

  return(false);
}

/* ****************************************************** */

void Utils::parseMac(u_int8_t *mac, const char *symMac) {
  sscanf(symMac, "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx",
	 &mac[0], &mac[1], &mac[2],
	 &mac[3], &mac[4], &mac[5]);  
}

/* *********************************************** */

static int fill_prefix_v4(prefix_t *p, struct in_addr *a, int b, int mb) {
  do {
    if(b < 0 || b > mb)
      return(-1);

    memcpy(&p->add.sin, a, (mb+7)/8);
    p->family = AF_INET;
    p->bitlen = b;
    p->ref_count = 0;
  } while (0);

  return(0);
}

/* ******************************************* */

static int fill_prefix_v6(prefix_t *prefix, struct in6_addr *addr, int bits, int maxbits) {
  if(bits < 0 || bits > maxbits)
    return -1;

  memcpy(&prefix->add.sin6, addr, (maxbits + 7) / 8);
  prefix->family = AF_INET6;
  prefix->bitlen = bits;
  prefix->ref_count = 0;

  return 0;
}

/* ******************************************* */

static patricia_node_t* add_to_ptree(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;
  patricia_node_t *node;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  node = patricia_lookup(tree, &prefix);

  return(node);
}

/* ******************************************* */

static int remove_from_ptree(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;
  patricia_node_t *node;
  int rc;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  node = patricia_lookup(tree, &prefix);

  if((patricia_node_t *)0 != node)
    rc = 0, free(node);
  else
    rc = -1;
  
  return(rc);
}

/* ******************************************* */

patricia_node_t* Utils::ptree_match(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  return(patricia_search_best(tree, &prefix));
}

/* ******************************************* */

patricia_node_t* Utils::ptree_add_rule(patricia_tree_t *ptree, char *line) {
  char *ip, *bits, *slash = NULL;
  struct in_addr addr4;
  struct in6_addr addr6;
  patricia_node_t *node = NULL;
  
  ip = line;
  bits = strchr(line, '/');
  if(bits == NULL)
    bits = (char*)"/32";
  else {
    slash = bits;
    slash[0] = '\0';
  }

  bits++;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Rule %s/%s", ip, bits);

  if(strchr(ip, ':') != NULL) { /* IPv6 */
    if(inet_pton(AF_INET6, ip, &addr6) == 1)
      node = add_to_ptree(ptree, AF_INET6, &addr6, atoi(bits));
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv6 %s\n", ip);
  } else { /* IPv4 */
    /* inet_aton(ip, &addr4) fails parsing subnets */
    int num_octets;
    u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
    u_char *ip4 = (u_char *) &addr4;
    
    if((num_octets = sscanf(ip, "%u.%u.%u.%u",
			    &ip4_0, &ip4_1, &ip4_2, &ip4_3)) >= 1) {
      int num_bits = atoi(bits);

      ip4[0] = ip4_0, ip4[1] = ip4_1, ip4[2] = ip4_2, ip4[3] = ip4_3;

      if(num_bits > 32) num_bits = 32;

      if(num_octets * 8 < num_bits)
	ntop->getTrace()->traceEvent(TRACE_INFO,
				     "Found IP smaller than netmask [%s]", line);

      //addr4.s_addr = ntohl(addr4.s_addr);
      node = add_to_ptree(ptree, AF_INET, &addr4, num_bits);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv4 %s\n", ip);
    }
  }

  if(slash) slash[0] = '/';

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Added IPv%d rule %s/%s [%p]", isV4 ? 4 : 6, ip, bits, node);
  
  return(node);
}

/* ******************************************* */

int Utils::ptree_remove_rule(patricia_tree_t *ptree, char *line) {
  char *ip, *bits, *slash = NULL;
  struct in_addr addr4;
  struct in6_addr addr6;
  int rc = -1;
  
  ip = line;
  bits = strchr(line, '/');
  if(bits == NULL)
    bits = (char*)"/32";
  else {
    slash = bits;
    slash[0] = '\0';
  }

  bits++;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Rule %s/%s", ip, bits);

  if(strchr(ip, ':') != NULL) { /* IPv6 */
    if(inet_pton(AF_INET6, ip, &addr6) == 1)
      rc = remove_from_ptree(ptree, AF_INET6, &addr6, atoi(bits));
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv6 %s\n", ip);
  } else { /* IPv4 */
    /* inet_aton(ip, &addr4) fails parsing subnets */
    int num_octets;
    u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
    u_char *ip4 = (u_char *) &addr4;

    if((num_octets = sscanf(ip, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3)) >= 1) {
      int num_bits = atoi(bits);

      ip4[0] = ip4_0, ip4[1] = ip4_1, ip4[2] = ip4_2, ip4[3] = ip4_3;

      if(num_bits > 32) num_bits = 32;

      if(num_octets * 8 < num_bits)
	ntop->getTrace()->traceEvent(TRACE_INFO, "Found IP smaller than netmask [%s]", line);

      //addr4.s_addr = ntohl(addr4.s_addr);
      rc = remove_from_ptree(ptree, AF_INET, &addr4, num_bits);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv4 %s\n", ip);
    }
  }

  if(slash) slash[0] = '/';

  return(rc);
}

