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

extern "C" {
#include "third-party/fast-sha1/sha1-fast.c"
}

#if defined(__OpenBSD__) || defined(__APPLE__)
#include <net/if_dl.h>
#include <ifaddrs.h>
#endif

// A simple struct for strings.
typedef struct {
  char *s;
  size_t l;
} String;

typedef struct {
  u_int8_t header_over;
  char outbuf[2*65536];
  u_int num_bytes;
  lua_State* vm;
} DownloadState;

#ifdef HAVE_LIBCAP
/* 
   The include below can be found in libcap-dev 
   
   sudo apt-get install libcap-dev
*/
#include <sys/capability.h>
#include <sys/prctl.h>

static cap_value_t cap_values[] = { 
				   CAP_DAC_OVERRIDE, /* Bypass file read, write, and execute permission checks  */
				   CAP_NET_RAW,      /* Use RAW and PACKET sockets */
				   CAP_NET_ADMIN     /* Perform various network-related operations */
};

int num_cap = sizeof(cap_values)/sizeof(cap_value_t);
#endif

static size_t curl_writefunc_to_lua(char *buffer, size_t size, size_t nitems, void *userp);
static size_t curl_hdf(char *buffer, size_t size, size_t nitems, void *userp);

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
  case 51:  return((char*)"AH");
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
#ifdef HAVE_LIBCAP
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

void Utils::setThreadName(const char *name) {
#if defined(__APPLE__) || defined(__linux__)
  // Mac OS X: must be set from within the thread (can't specify thread ID)
  char buf[16]; // NOTE: on linux there is a 16 char limit
  int rc;
  snprintf(buf, sizeof(buf), "%s", name);
#if defined(__APPLE__)
  if((rc = pthread_setname_np(buf)))
#else
  if((rc = pthread_setname_np(pthread_self(), buf)))
#endif
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set pthread name %s: %d", buf, rc);
#endif
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

float Utils::msTimevalDiff(const struct timeval *end, const struct timeval *begin) {
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

bool Utils::dir_exists(const char * const path) {
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif

  return !((stat(path, &buf) != 0) || (!S_ISDIR(buf.st_mode)));
}

/* ****************************************************** */

size_t Utils::file_write(const char *path, const char *content, size_t content_len) {
  size_t ret = 0;
  FILE *fd = fopen(path, "wb");

  if(fd == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to write file %s", path);
  } else {
    chmod(path, CONST_DEFAULT_FILE_MODE);
    ret = fwrite(content, content_len, 1, fd);
    fclose(fd);
  }

  return ret;
}

/* ****************************************************** */

size_t Utils::file_read(const char *path, char **content) {
  size_t ret = 0;
  char *buffer = NULL;
  u_int64_t length;
  FILE *f = fopen(path, "rb");

  if(f) {
    fseek (f, 0, SEEK_END);
    length = ftell(f);
    fseek (f, 0, SEEK_SET);

    buffer = (char*)malloc(length);
    if(buffer)
      ret = fread(buffer, 1, length, f);

    fclose(f);
  }

  if(buffer) {
    if(content && ret)
      *content = buffer;
    else
      free(buffer);
  }

  return ret;
}

/* ****************************************************** */

int Utils::remove_recursively(const char * const path) {
  DIR *d = opendir(path);
  size_t path_len = strlen(path);
  int r = -1;
  size_t len;
  char *buf;

  if(d) {
    struct dirent *p;

    r = 0;

    while ((r==0) && (p=readdir(d))) {
      /* Skip the names "." and ".." as we don't want to recurse on them. */
      if(!strcmp(p->d_name, ".") || !strcmp(p->d_name, ".."))
	continue;

      len = path_len + strlen(p->d_name) + 2;
      buf = (char *) malloc(len);

      if(buf) {
#ifdef WIN32
	struct _stat64 statbuf;
#else
	struct stat statbuf;
#endif

        snprintf(buf, len, "%s/%s", path, p->d_name);

        if(stat(buf, &statbuf) == 0) {
          if(S_ISDIR(statbuf.st_mode))
            r = remove_recursively(buf);
          else
            r = unlink(buf);
        }

        free(buf);
      }
    }

    closedir(d);
  }

  if(r == 0)
    r = rmdir(path);

  return r;  
}

/* ****************************************************** */

bool Utils::mkdir_tree(char * const path) {
  int rc;
#ifdef WIN32
  struct _stat64 s;
#else
  struct stat s;
#endif

  ntop->fixPath(path);

  if(stat(path, &s) != 0) {
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
	rc = Utils::mkdir(path, CONST_DEFAULT_DIR_MODE);
	
	path[i] = CONST_PATH_SEP;
      }

    rc = Utils::mkdir(path, CONST_DEFAULT_DIR_MODE);

    return(((rc == 0) || (errno == EEXIST/* Already existing */)) ? true : false);
  } else
    return(true); /* Already existing */
}

/* **************************************************** */

int Utils::mkdir(const char *path, mode_t mode) {
#ifdef WIN32
  return(_mkdir(path));
#else
  int rc = ::mkdir(path, mode);

  if(rc == -1) {
    if(errno != EEXIST)
      ntop->getTrace()->traceEvent(TRACE_WARNING, "mkdir(%s) failed [%d/%s]",
				   path, errno, strerror(errno));
  } else {
    if(chmod(path, CONST_DEFAULT_DIR_MODE) == -1) /* Ubuntu 18 */
      ntop->getTrace()->traceEvent(TRACE_WARNING, "chmod(%s) failed [%d/%s]",
				   path, errno, strerror(errno));
  }
  
  return(rc);
#endif
}

/* **************************************************** */

const char* Utils::flowStatus2str(FlowStatus s, AlertType *aType, AlertLevel *aLevel) {
  *aType = alert_flow_misbehaviour; /* Default */
  *aLevel = alert_level_warning;

  switch(s) {
  case status_normal:
    *aType = alert_none;
    *aLevel = alert_level_none;
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
  case status_ssl_certificate_mismatch:
    *aType = alert_suspicious_activity;
    return("SSL certificate mismatch");
  case status_dns_invalid_query:
    *aType = alert_suspicious_activity;
    return("Invalid DNS query");
  case status_remote_to_remote:
    *aType = alert_flow_remote_to_remote;
    return("Remote client and remote server");
  case status_web_mining_detected:
    *aType = alert_flow_web_mining;
    *aLevel = alert_level_warning;
    return("Web miner detected");
  case status_blacklisted:
    *aType = alert_flow_blacklisted;
    *aLevel = alert_level_error;
    return("Client or server blacklisted (or both)");
  case status_blocked:
    *aLevel = alert_level_info;
    *aType = alert_flow_blocked;
    return("Flow blocked");
  case status_device_protocol_not_allowed:
    *aType = alert_device_protocol_not_allowed;
    *aLevel = alert_level_warning;
    return("Protocol not allowed for this device type");
  case status_elephant_local_to_remote:
    return("Elephant flow (local to remote)");
    break;
  case status_elephant_remote_to_local:
    return("Elephant flow (remote to local)");
    break;
  case status_longlived:
    return("Long-lived flow");
    break;
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
  int rv;

  if(getgid() && getuid()) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Privileges are not dropped as we're not superuser");
    return -1;
  }

  if(Utils::retainWriteCapabilities() != 0) {
#ifdef HAVE_LIBCAP
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to retain privileges for privileged file writing");
#endif
  }

  username = ntop->getPrefs()->get_user();
  pw = getpwnam(username);

  if(pw == NULL) {
    /* if the user (e.g. 'ntopng') does not exists, falls back to 'nobody' */
    username = CONST_OLD_DEFAULT_NTOP_USER;
    pw = getpwnam(username);
  }

  if(pw != NULL) {
    if(ntop->getPrefs()->get_pid_path() != NULL) {
      /* Change PID file ownership to be able to delete it on shutdown */
      rv = chown(ntop->getPrefs()->get_pid_path(), pw->pw_uid, pw->pw_gid);
      if(rv != 0)
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to change owner to PID in file %s", ntop->getPrefs()->get_pid_path());
    }

    /* Drop privileges */
    /* Dear programmer, initgroups() is necessary as there may be extra groups for the user that we are going to
       drop privileges to that are not yet visible. This can happen for newely created groups, or when a user has
       been added to a new group.
       Don't remove it or you will waste hours of life.
     */
    if((initgroups(pw->pw_name, pw->pw_gid) != 0)
       || (setgid(pw->pw_gid) != 0)
       || (setuid(pw->pw_uid) != 0)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to drop privileges [%s]",
				   strerror(errno));
      return -1;
    }
    
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "User changed to %s", username);
#ifndef WIN32
    ntop->getTrace()->traceEvent(TRACE_INFO, "Umask: %#o", umask(0077));
#endif
  } else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate user %s", username);
    return -1;
  }
  // umask(0);
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

char* Utils::base64_encode(unsigned char const* bytes_to_encode, ssize_t in_len) {
  char *res = NULL;
  ssize_t res_len = 0;
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

  if((res = (char*)calloc(sizeof(char), ret.size() + 1))) {
    res_len = ret.copy(res, ret.size());
    res[res_len] = '\0';
  }

  return res;
}

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

void Utils::sha1_hash(const uint8_t message[], size_t len, uint32_t hash[STATE_LEN]) {
  hash[0] = UINT32_C(0x67452301);
  hash[1] = UINT32_C(0xEFCDAB89);
  hash[2] = UINT32_C(0x98BADCFE);
  hash[3] = UINT32_C(0x10325476);
  hash[4] = UINT32_C(0xC3D2E1F0);
    
#define LENGTH_SIZE 8  // In bytes
    
  size_t off;
  for (off = 0; len - off >= BLOCK_LEN; off += BLOCK_LEN)
    sha1_compress(hash, &message[off]);
    
  uint8_t block[BLOCK_LEN] = {0};
  size_t rem = len - off;
  memcpy(block, &message[off], rem);
    
  block[rem] = 0x80;
  rem++;
  if (BLOCK_LEN - rem < LENGTH_SIZE) {
    sha1_compress(hash, block);
    memset(block, 0, sizeof(block));
  }
    
  block[BLOCK_LEN - 1] = (uint8_t)((len & 0x1FU) << 3);
  len >>= 5;
  for (int i = 1; i < LENGTH_SIZE; i++, len >>= 8)
    block[BLOCK_LEN - 1 - i] = (uint8_t)(len & 0xFFU);
  sha1_compress(hash, block);
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
extern "C" {
  const char *strcasestr(const char *haystack, const char *needle) {
    int i = -1;

    while (haystack[++i] != '\0') {
      if(tolower(haystack[i]) == tolower(needle[0])) {
	int j = i, k = 0, match = 0;
	while (tolower(haystack[++j]) == tolower(needle[++k])) {
	  match = 1;
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
};
#endif

/* **************************************************** */

int Utils::ifname2id(const char *name) {
  char rsp[MAX_INTERFACE_NAME_LEN], ifidx[8];

  if(name == NULL) return(-1);
  else if(!strncmp(name, "-", 1)) name = (char*) "stdin";

  if(ntop->getRedis()->hashGet((char*)CONST_IFACE_ID_PREFS, (char*)name, rsp, sizeof(rsp)) == 0) {
    /* Found */
    return(atoi(rsp));
  } else {
    for(int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
      snprintf(ifidx, sizeof(ifidx), "%d", i);
      if(ntop->getRedis()->hashGet((char*)CONST_IFACE_ID_PREFS, ifidx, rsp, sizeof(rsp)) < 0) {
	snprintf(rsp, sizeof(rsp), "%s", name);
	ntop->getRedis()->hashSet((char*)CONST_IFACE_ID_PREFS, rsp, ifidx);
	ntop->getRedis()->hashSet((char*)CONST_IFACE_ID_PREFS, ifidx, rsp);
	return(i);
      }
    }

    ntop->getTrace()->traceEvent(TRACE_ERROR, "Interface ids exhausted. Flush redis to create new interfaces.");
  }

  return(-1); /* This can't happen, hopefully */
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
  if(!str) return NULL;
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
    if(str[i] == '<') {
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
    } else if(*src == '+') {
      *dst++ = ' '; src++;
    } else
      *dst++ = *src++;

    i++;
  }

  *dst++ = '\0';
  return(ret);
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

bool Utils::purifyHTTPparam(char * const param, bool strict, bool allowURL, bool allowDots) {
  if(strict) {
    for(int i=0; xssAttempts[i] != NULL; i++) {
      if(strstr(param, xssAttempts[i])) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Found possible XSS attempt: %s [%s]", param, xssAttempts[i]);
	param[0] = '\0';
	return(true);
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
      char c;
      int new_i;

      if((u_char)param[i] == 0xC3) {
        /* Latin-1 within UTF-8 - Align to ASCII encoding */
        c = param[i+1] | 0x40;
        new_i = i+1; /* We are actually validating two bytes */
      } else {
        c = param[i];
        new_i = i;
      }

      is_good = Utils::isPrintableChar(c)
        && (c != '<')
        && (c != '>')
        && (c != '"'); /* Prevents injections - single quotes are allowed and will be validated in http_lint.lua */

      if(is_good)
        i = new_i;
    }

    if(is_good)
      ; /* Good: we're on the whitelist */
    else
      param[i] = '_'; /* Invalid char: we discard it */

    if((i > 0)
       && (((!allowDots) && (param[i] == '.') && (param[i-1] == '.'))
	   || ((!allowURL) && ((param[i] == '/') && (param[i-1] == '/')))
	   || ((param[i] == '\\') && (param[i-1] == '\\'))
	   )) {
      /* Make sure we do not have .. in the variable that can be used for future hacking */
      param[i-1] = '_', param[i] = '_'; /* Invalidate the path */
    }
  }

  return(false);
}

/* **************************************************** */

/* holder for curl fetch */
struct curl_fetcher_t {
  char * const payload;
  size_t cur_size;
  const size_t max_size;
};

static size_t curl_get_writefunc(void *contents, size_t size, size_t nmemb, void *userp) {
  size_t realsize = size * nmemb;
  struct curl_fetcher_t *p = (struct curl_fetcher_t*)userp;

  if(!p->max_size)
    return realsize;

  /* Leave the last position for a '\0' */
  if(p->cur_size + realsize > p->max_size - 1)
    realsize = p->max_size - p->cur_size - 1;

  if(realsize) {
    memcpy(&(p->payload[p->cur_size]), contents, realsize);
    p->cur_size += realsize;
    p->payload[p->cur_size] = 0;
  }

  return realsize;
}

/* **************************************************** */

/**
 * @brief Implement HTTP POST of JSON data
 *
 * @param username  Username to be used on post or NULL if missing
 * @param password  Password to be used on post or NULL if missing
 * @param url       URL where to post data to
 * @param json      The content of the POST
 * @return true if post was successful, false otherwise.
 */

static int curl_post_writefunc(void *ptr, size_t size, size_t nmemb, void *stream) {
  char *str = (char*)ptr;

  ntop->getTrace()->traceEvent(TRACE_INFO, "[JSON] %s", str);
  return(size*nmemb);
}

/* **************************************** */

#ifdef HAVE_CURL_SMTP

struct snmp_upload_status {
  char *lines;
  char msg_log[1024];
};

static int curl_debugfunc(CURL *handle, curl_infotype type, char *data,
			  size_t size, void *userptr) {
  char dir = '\0';

  switch(type) {
  case CURLINFO_HEADER_IN:
  case CURLINFO_DATA_IN:
    dir = '<';
    break;
  case CURLINFO_DATA_OUT:
  case CURLINFO_HEADER_OUT:
    dir = '>';
    break;
  default:
    break;
  }

  if(dir) {
    char *msg = data;

    while(*msg) {
      char *end = strchr(msg, '\n');
      if(!end) break;

      *end = '\0';
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "[CURL] %c %s", dir, msg);
      *end = '\n';
      msg = end+1;
    }
  }

  return(size);
}

/* **************************************** */

static size_t curl_smtp_payload_source(void *ptr, size_t size, size_t nmemb, void *userp) {
  struct snmp_upload_status *upload_ctx = (struct snmp_upload_status *)userp;

  if((size == 0) || (nmemb == 0) || ((size*nmemb) < 1)) {
    return 0;
  }

  char *eol = strstr(upload_ctx->lines, "\r\n");

  if(eol) {
    size_t len = min(size, (size_t)(eol - upload_ctx->lines + 2));
    memcpy(ptr, upload_ctx->lines, len);
    upload_ctx->lines += len;

    return len;
  }

  return 0;
}

#endif

/* **************************************** */

static void readCurlStats(CURL *curl, HTTPTranferStats *stats, lua_State* vm) { 
  curl_easy_getinfo(curl, CURLINFO_NAMELOOKUP_TIME, &stats->namelookup);
  curl_easy_getinfo(curl, CURLINFO_CONNECT_TIME, &stats->connect);
  curl_easy_getinfo(curl, CURLINFO_APPCONNECT_TIME, &stats->appconnect);
  curl_easy_getinfo(curl, CURLINFO_PRETRANSFER_TIME, &stats->pretransfer);
  curl_easy_getinfo(curl, CURLINFO_REDIRECT_TIME, &stats->redirect);
  curl_easy_getinfo(curl, CURLINFO_STARTTRANSFER_TIME, &stats->start);
  curl_easy_getinfo(curl, CURLINFO_TOTAL_TIME, &stats->total);

  if(vm) {
    lua_newtable(vm);

    lua_push_float_table_entry(vm, "NAMELOOKUP_TIME", stats->namelookup);
    lua_push_float_table_entry(vm, "CONNECT_TIME", stats->connect);
    lua_push_float_table_entry(vm, "APPCONNECT_TIME", stats->appconnect);
    lua_push_float_table_entry(vm, "PRETRANSFER_TIME", stats->pretransfer);
    lua_push_float_table_entry(vm, "REDIRECT_TIME", stats->redirect);
    lua_push_float_table_entry(vm, "STARTTRANSFER_TIME", stats->start);
    lua_push_float_table_entry(vm, "TOTAL_TIME", stats->total);

    lua_pushstring(vm, "HTTP_STATS");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  ntop->getTrace()->traceEvent(TRACE_INFO,
			       "[NAMELOOKUP_TIME %.02f][CONNECT_TIME %.02f][APPCONNECT_TIME %.02f][PRETRANSFER_TIME %.02f]"
			       "[REDIRECT_TIME %.02f][STARTTRANSFER_TIME %.02f][TOTAL_TIME %.02f]",
			       stats->namelookup, stats->connect, stats->appconnect,
			       stats->pretransfer,stats->redirect, stats->start,
			       stats->total);
}

/* **************************************** */

bool Utils::postHTTPJsonData(char *username, char *password, char *url,
			     char *json, int timeout, HTTPTranferStats *stats) {
  CURL *curl;
  bool ret = true;

  curl = curl_easy_init();
  if(curl) {
    CURLcode res;
    struct curl_slist* headers = NULL;

    memset(stats, 0, sizeof(HTTPTranferStats));
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
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_post_writefunc);

    if (timeout) {
      curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
      curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);
#ifdef CURLOPT_CONNECTTIMEOUT_MS
      curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout*1000);
#endif
    }

    res = curl_easy_perform(curl);

    if(res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Unable to post data to (%s): %s",
				   url, curl_easy_strerror(res));
      ret = false;
    } else {
      ntop->getTrace()->traceEvent(TRACE_INFO, "Posted JSON to %s", url);
      readCurlStats(curl, stats, NULL);
    }
    
    /* always cleanup */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  return(ret);
}

/* **************************************** */

bool Utils::postHTTPJsonData(char *username, char *password, char *url,
                             char *json, int timeout, HTTPTranferStats *stats,
                             char *return_data, int return_data_size, int *response_code) {
  CURL *curl;
  bool ret = false;

  curl = curl_easy_init();
  if(curl) {
    CURLcode res;
    struct curl_slist* headers = NULL;
    curl_fetcher_t fetcher = {
			      /* .payload =  */ return_data,
			      /* .cur_size = */ 0,
			      /* .max_size = */ (size_t)return_data_size};

    memset(stats, 0, sizeof(HTTPTranferStats));
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
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &fetcher);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_get_writefunc);

    if (timeout) {
      curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
      curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);
#ifdef CURLOPT_CONNECTTIMEOUT_MS
      curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout*1000);
#endif
    }

    res = curl_easy_perform(curl);

    if(res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to post data to (%s): %s",
                                   url, curl_easy_strerror(res));
    } else {
      long rc;
      ntop->getTrace()->traceEvent(TRACE_INFO, "Posted JSON to %s", url);
      readCurlStats(curl, stats, NULL);
      curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &rc);
      *response_code = rc;
      ret = true;
    }

    /* always cleanup */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  return(ret);
}

/* **************************************** */

static size_t read_callback(void *ptr, size_t size, size_t nmemb, void *stream) {
  return(fread(ptr, size, nmemb, (FILE*)stream));
}

bool Utils::postHTTPTextFile(lua_State* vm, char *username, char *password, char *url,
			     char *path, int timeout, HTTPTranferStats *stats) {
  CURL *curl;
  bool ret = true;
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif
  size_t file_len;
  FILE *fd;

  if(stat(path, &buf) != 0)
    return(false);
  
  if((fd = fopen(path, "r")) == NULL)
    return(false);
  else
    file_len = (size_t)buf.st_size;
  
  curl = curl_easy_init();
  if(curl) {
    CURLcode res;
    DownloadState *state = NULL;
    struct curl_slist* headers = NULL;

    memset(stats, 0, sizeof(HTTPTranferStats));
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
    headers = curl_slist_append(headers, "Content-Type: text/plain; charset=utf-8");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    curl_easy_setopt(curl, CURLOPT_READDATA, fd);
    curl_easy_setopt(curl, CURLOPT_READFUNCTION, read_callback);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (curl_off_t)file_len);

    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);
    
#ifdef CURLOPT_CONNECTTIMEOUT_MS
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout*1000);
#endif

    state = (DownloadState*)malloc(sizeof(DownloadState));
    if(state != NULL) {
      memset(state, 0, sizeof(DownloadState));

      curl_easy_setopt(curl, CURLOPT_WRITEDATA, state);
      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_lua);
      curl_easy_setopt(curl, CURLOPT_HEADERDATA, state);
      curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curl_hdf);

      state->vm = vm, state->header_over = 0;
    } else {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
      curl_easy_cleanup(curl);
      if(vm) lua_pushnil(vm);
      return(false);
    }

    if(vm) lua_newtable(vm);

    res = curl_easy_perform(curl);

    if(res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Unable to post data to (%s): %s",
				   url, curl_easy_strerror(res));
      lua_push_str_table_entry(vm, "error_msg", curl_easy_strerror(res));
      ret = false;
    } else {
      ntop->getTrace()->traceEvent(TRACE_INFO, "Posted JSON to %s", url);
      readCurlStats(curl, stats, NULL);

      if(vm) {
        long response_code;
        lua_push_str_table_entry(vm, "CONTENT", state->outbuf);
        lua_push_uint64_table_entry(vm, "CONTENT_LEN", state->num_bytes);

        if(curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) == CURLE_OK)
          lua_push_uint64_table_entry(vm, "RESPONSE_CODE", response_code);
      }
    }

    if(state)
      free(state);

    fclose(fd);
    
    /* always cleanup */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  return(ret);
}

/* **************************************** */

bool Utils::sendMail(char *from, char *to, char *message, char *smtp_server) {
#ifdef HAVE_CURL_SMTP
  CURL *curl;
  CURLcode res;
  bool ret = true;
  struct curl_slist *recipients = NULL;
  struct snmp_upload_status *upload_ctx = (struct snmp_upload_status*) calloc(1, sizeof(struct snmp_upload_status));

  if(!upload_ctx) return false;

  upload_ctx->lines = message;
  curl = curl_easy_init();

  if(curl) {
    recipients = curl_slist_append(recipients, to);

    curl_easy_setopt(curl, CURLOPT_URL, smtp_server);
    curl_easy_setopt(curl, CURLOPT_MAIL_FROM, from);
    curl_easy_setopt(curl, CURLOPT_MAIL_RCPT, recipients);

    /* Try using SSL */
    curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_TRY);

    if(ntop->getTrace()->get_trace_level() >= TRACE_LEVEL_DEBUG) {
      /* Show verbose message trace */
      curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
      curl_easy_setopt(curl, CURLOPT_DEBUGFUNCTION, curl_debugfunc);
      curl_easy_setopt(curl, CURLOPT_DEBUGDATA, upload_ctx);
    }

    curl_easy_setopt(curl, CURLOPT_READFUNCTION, curl_smtp_payload_source);
    curl_easy_setopt(curl, CURLOPT_READDATA, upload_ctx);
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1L);

    res = curl_easy_perform(curl);

    if(res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Unable to send email to (%s): %s. Run ntopng with -v6 for more details.",
				   smtp_server, curl_easy_strerror(res));
      ret = false;
    }

    curl_slist_free_all(recipients);

    /* NOTE: connection could be reused */
    curl_easy_cleanup(curl);
  }

  free(upload_ctx);
  return ret;
#else
  ntop->getTrace()->traceEvent(TRACE_ERROR, "SMTP support is not available");
  return(false);
#endif
}

/* **************************************** */

/* curl calls this routine to get more data */
static size_t curl_writefunc_to_lua(char *buffer, size_t size,
				    size_t nitems, void *userp) {
  DownloadState *state = (DownloadState*)userp;
  int len = size*nitems, diff;
  
  if(state->header_over == 0) {
    /* We need to parse the header as this is the first call for the body */
    char *tmp, *element;

    state->outbuf[state->num_bytes] = 0;
    element = strtok_r(state->outbuf, "\r\n", &tmp);
    if(element) element = strtok_r(NULL, "\r\n", &tmp);

    lua_newtable(state->vm);
    
    while(element) {
      char *column = strchr(element, ':');

      if(!column) break;
      
      column[0] = '\0';

      /* Put everything in lowercase */
      for(int i=0; element[i] != '\0'; i++) element[i] = tolower(element[i]);
      lua_push_str_table_entry(state->vm, element, &column[1]);

      element = strtok_r(NULL, "\r\n", &tmp);
    }

    lua_pushstring(state->vm, "HTTP_HEADER");
    lua_insert(state->vm, -2);
    lua_settable(state->vm, -3);

    state->num_bytes = 0, state->header_over = 1;
  }


  diff = sizeof(state->outbuf) - state->num_bytes - 1;

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

static size_t curl_writefunc_to_file(void *ptr, size_t size, size_t nmemb, void *stream) {
  size_t written = fwrite(ptr, size, nmemb, (FILE *)stream);
  return written;
}

/* **************************************** */

/* Same as the above function but only for header */
static size_t curl_hdf(char *buffer, size_t size, size_t nitems, void *userp) {
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

bool Utils::progressCanContinue(ProgressState *progressState) {
  struct mg_connection *conn;
  time_t now = time(0);

  if(progressState->vm &&
     ((now - progressState->last_conn_check) >= 1) &&
     (conn = getLuaVMUserdata(progressState->vm, conn))) {
    progressState->last_conn_check = now;

    if(!mg_is_client_connected(conn))
      /* connection to the client was closed, should not continue */
      return(false);
  }

  return(true);
}

/* **************************************** */

static int progress_callback(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow) {
  ProgressState *progressState = (ProgressState*) clientp;

  return Utils::progressCanContinue(progressState) ? 0 /* continue */ : 1 /* stop transfer */;
}

/* **************************************** */

/* form_data is in format param=value&param1=&value1... */
bool Utils::httpGetPost(lua_State* vm, char *url, char *username,
			char *password, int timeout,
			bool return_content,
			bool use_cookie_authentication,
			HTTPTranferStats *stats, const char *form_data,
      char *write_fname) {
  CURL *curl;
  FILE *out_f = NULL;
  bool ret = true;

  curl = curl_easy_init();

  if(curl) {
    DownloadState *state = NULL;
    ProgressState progressState;
    long response_code;
    char *content_type, *redirection;
    char ua[64];

    memset(stats, 0, sizeof(HTTPTranferStats));
    curl_easy_setopt(curl, CURLOPT_URL, url);

    if(username || password) {
      char auth[64];

      if(use_cookie_authentication) {
	snprintf(auth, sizeof(auth),
		 "user=%s; password=%s",
		 username ? username : "",
		 password ? password : "");
	curl_easy_setopt(curl, CURLOPT_COOKIE, auth);
      } else {
	snprintf(auth, sizeof(auth), "%s:%s",
		 username ? username : "",
		 password ? password : "");
	curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
	curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
      }
    }

    if(!strncmp(url, "https", 5)) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    if(form_data) {
      /* This is a POST request */
      curl_easy_setopt(curl, CURLOPT_POST, 1L);
      curl_easy_setopt(curl, CURLOPT_POSTFIELDS, form_data);
      curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(form_data));
    }

    if(write_fname) {
      ntop->fixPath(write_fname);
      out_f = fopen(write_fname, "w");

      if(out_f == NULL) {
        char buf[64];
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Could not open %s for write", write_fname, strerror_r(errno, buf, sizeof(buf)));
        curl_easy_cleanup(curl);
        if(vm) lua_pushnil(vm);
        return(false);
      }

      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_file);
      curl_easy_setopt(curl, CURLOPT_WRITEDATA, out_f);
    } else if(return_content) {
      state = (DownloadState*)malloc(sizeof(DownloadState));
      if(state != NULL) {
	memset(state, 0, sizeof(DownloadState));

	curl_easy_setopt(curl, CURLOPT_WRITEDATA, state);
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_lua);
	curl_easy_setopt(curl, CURLOPT_HEADERDATA, state);
	curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curl_hdf);
	
	state->vm = vm, state->header_over = 0;
      } else {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
	curl_easy_cleanup(curl);
	if(vm) lua_pushnil(vm);
	return(false);
      }
    }

    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);

    if(!form_data) {
      /* A GET request, track client connection status */
      memset(&progressState, 0, sizeof(progressState));
      progressState.vm = vm;
      curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
      curl_easy_setopt(curl, CURLOPT_PROGRESSFUNCTION, progress_callback);
      curl_easy_setopt(curl, CURLOPT_PROGRESSDATA, &progressState);
    }
    
#ifdef CURLOPT_CONNECTTIMEOUT_MS
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout*1000);
#endif

    snprintf(ua, sizeof(ua), "%s [%s][%s]",
	     PACKAGE_STRING, PACKAGE_MACHINE, PACKAGE_OS);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, ua);

    if(vm) lua_newtable(vm);

    if(curl_easy_perform(curl) == CURLE_OK) {
      readCurlStats(curl, stats, vm);
	
      if(return_content && vm) {
	lua_push_str_table_entry(vm, "CONTENT", state->outbuf);
	lua_push_uint64_table_entry(vm, "CONTENT_LEN", state->num_bytes);
      }
      
      ret = true;
    } else
      ret = false;

    if(vm) {
      if(curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) == CURLE_OK)
	lua_push_uint64_table_entry(vm, "RESPONSE_CODE", response_code);

      if((curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &content_type) == CURLE_OK) && content_type)
	lua_push_str_table_entry(vm, "CONTENT_TYPE", content_type);

      if(curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &redirection) == CURLE_OK)
	lua_push_str_table_entry(vm, "EFFECTIVE_URL", redirection);

      if(!ret)
	lua_push_bool_table_entry(vm, "IS_PARTIAL", true);
    }

    if(return_content && state)
      free(state);

    /* always cleanup */
    curl_easy_cleanup(curl);
  }

  if(out_f)
    fclose(out_f);

  return(ret);
}

/* **************************************** */

long Utils::httpGet(const char * const url,
		    const char * const username, const char * const password,
		    int timeout,
		    char * const resp, const u_int resp_len) {
  CURL *curl;
  long response_code = 0;
  curl = curl_easy_init();

  if(curl) {
    char *content_type;
    char ua[64];
    curl_fetcher_t fetcher = {
			      /* .payload =  */ resp,
			      /* .cur_size = */ 0,
			      /* .max_size = */ resp_len};

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

    if(resp && resp_len) {
      curl_easy_setopt(curl, CURLOPT_WRITEDATA, &fetcher);
      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_get_writefunc);
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

    if(curl_easy_perform(curl) == CURLE_OK) {
      if((curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &content_type) != CURLE_OK)
	 || (curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) != CURLE_OK))
	response_code = 0;
    }

    /* always cleanup */
    curl_easy_cleanup(curl);
  }

  return response_code;
}

/* **************************************** */

char* Utils::getURL(char *url, char *buf, u_int buf_len) {
#ifdef WIN32
  struct _stat64 s;
#else
  struct stat s;
#endif

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

/* **************************************************** */

/* URL encodes the given string. The caller must free the returned string after use. */
char* Utils::urlEncode(const char *url) {
  CURL *curl;

  if(url) {
    curl = curl_easy_init();

    if(curl) {
      char *escaped = curl_easy_escape(curl, url, strlen(url));
      char *output = strdup(escaped);
      curl_free(escaped);
      curl_easy_cleanup(curl);

      return output;
    }
  }

  return NULL;
}

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

/* **************************************** */

ticks Utils::getticks() {
#ifdef WIN32
  struct timeval tv;
  gettimeofday (&tv, 0);

  return (((ticks)tv.tv_usec) + (((ticks)tv.tv_sec) * 1000000LL));
#else
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
#endif
}

/* **************************************** */

static bool scan_dir(const char * dir_name,
		     list<pair<struct dirent *, char * > > *dirlist,
		     unsigned long *total) {
  int path_length;
  char path[MAX_PATH+2];
  DIR *d;
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif

  d = opendir(dir_name);
  if(!d) return false;

  while (1) {
    struct dirent *entry;
    const char *d_name;

    entry = readdir(d);
    if(!entry) break;
    d_name = entry->d_name;

    if(entry->d_type & DT_REG) {
      snprintf(path, sizeof(path), "%s/%s", dir_name, entry->d_name);
      if(!stat(path, &buf)) {
        struct dirent *temp = (struct dirent *)malloc(sizeof(struct dirent));
        memcpy(temp, entry, sizeof(struct dirent));
        dirlist->push_back(make_pair(temp, strndup(path, MAX_PATH)));
	if(total)
	  *total += buf.st_size;
      }

    } else if(entry->d_type & DT_DIR) {
      if(strncmp (d_name, "..", 2) != 0 &&
	 strncmp (d_name, ".", 1) != 0) {
        path_length = snprintf (path, MAX_PATH,
                                "%s/%s", dir_name, d_name);

        if(path_length >= MAX_PATH)
          return false;

        scan_dir(path, dirlist, total);
      }
    }
  }

  if(closedir(d)) return false;

  return true;
}

/* **************************************** */

bool file_mtime_compare(const pair<struct dirent *, char * > &d1, const pair<struct dirent *, char * > &d2) {
#ifdef WIN32
  struct _stat64 sa, sb;
#else
  struct stat sa, sb;
#endif

  if(!d1.second || !d2.second)
    return false;

  if(stat(d1.second, &sa) || stat(d2.second, &sb))
    return false;

  return difftime(sa.st_mtime, sb.st_mtime) <= 0;
}

/* **************************************** */

bool Utils::discardOldFilesExceeding(const char *path, const unsigned long max_size) {
  unsigned long total = 0;
  list<pair<struct dirent *, char * > > fileslist;
  list<pair<struct dirent *, char * > >::iterator it;
#ifdef WIN32
  struct _stat64 st;
#else
  struct stat st;
#endif

  if(path == NULL || !strncmp(path, "", MAX_PATH))
    return false;

  /* First, get a list of all non-dir dirents and compute total size */
  if(!scan_dir(path, &fileslist, &total)) return false;

  //printf("path: %s, total: %u, max_size: %u\n", path, total, max_size);

  if(total < max_size) return true;

  fileslist.sort(file_mtime_compare);

  /* Third, traverse list and delete until we go below quota */
  for (it = fileslist.begin(); it != fileslist.end(); ++it) {
    //printf("[file: %s][path: %s]\n", it->first->d_name, it->second);
    if(!it->second) continue;

    stat(it->second, &st);
    unlink(it->second);

    total -= st.st_size;
    if(total < max_size)
      break;
  }

  for (it = fileslist.begin(); it != fileslist.end(); ++it) {
    if(it->first)
      free(it->first);
    if(it->second)
      free(it->second);
  }
  

  return true;
}

/* **************************************** */

char* Utils::formatMac(const u_int8_t * const mac, char *buf, u_int buf_len) {
  if((mac == NULL) || (ntop->getPrefs()->getHostMask() != no_host_mask))
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
      mac_int |= ((u_int64_t)(mac[i] & 0xFF)) << (5-i)*8;
    }

    return mac_int;
  }
}

/* **************************************** */

#if defined(linux) || defined(__FreeBSD__) || defined(__APPLE__)

void Utils::readMac(char *_ifname, dump_mac_t mac_addr) {
  char ifname[32];
  char *colon, *at;
  macstr_t mac_addr_buf;
  int res;

  /* Handle PF_RING interfaces zc:ens2f1@3 */
  colon = strchr(_ifname, ':');
  if(colon != NULL) /* removing pf_ring module prefix (e.g. zc:ethX) */
    _ifname = colon+1;

  snprintf(ifname, sizeof(ifname), "%s", _ifname);
  at = strchr(ifname, '@');
  if(at != NULL)
    at[0] = '\0';

#if defined(__FreeBSD__) || defined(__APPLE__)
  struct ifaddrs *ifap, *ifaptr;
  unsigned char *ptr;

  if((res = getifaddrs(&ifap)) == 0) {
    for(ifaptr = ifap; ifaptr != NULL; ifaptr = ifaptr->ifa_next) {
      if(!strcmp(ifaptr->ifa_name, ifname) && (ifaptr->ifa_addr->sa_family == AF_LINK)) {

	ptr = (unsigned char *)LLADDR((struct sockaddr_dl *)ifaptr->ifa_addr);
	memcpy(mac_addr, ptr, 6);

	break;

      }
    }
    freeifaddrs(ifap);
  }
#else
  int _sock;
  struct ifreq ifr;

  memset (&ifr, 0, sizeof(struct ifreq));

  /* Dummy socket, just to make ioctls with */
  _sock = socket(PF_INET, SOCK_DGRAM, 0);
  strncpy(ifr.ifr_name, ifname, IFNAMSIZ-1);

  if((res = ioctl(_sock, SIOCGIFHWADDR, &ifr)) >= 0)
    memcpy(mac_addr, ifr.ifr_ifru.ifru_hwaddr.sa_data, 6);

  close(_sock);
#endif

  if(res < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot get hw addr for %s", ifname);
  else
    ntop->getTrace()->traceEvent(TRACE_INFO, "Interface %s has MAC %s",
				 ifname,
				 formatMac((u_int8_t *)mac_addr, mac_addr_buf, sizeof(mac_addr_buf)));
}

#else
void Utils::readMac(char *ifname, dump_mac_t mac_addr) {
  memset(mac_addr, 0, 6);
}
#endif

/* **************************************** */

u_int32_t Utils::readIPv4(char *ifname) {
  u_int32_t ret_ip = 0;

#ifndef WIN32
  struct ifreq ifr;
  int fd;
  
  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name)-1);
  ifr.ifr_addr.sa_family = AF_INET;

  if((fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
  } else {
    if(ioctl(fd, SIOCGIFADDR, &ifr) == -1)
      ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read IPv4 for device %s", ifname);
    else
      ret_ip = (((struct sockaddr_in*)&ifr.ifr_addr)->sin_addr).s_addr;

    closesocket(fd);
  }
#endif

  return(ret_ip);
}

/* **************************************** */

u_int16_t Utils::getIfMTU(const char *ifname) {
#ifdef WIN32
  return(CONST_DEFAULT_MAX_PACKET_SIZE);
#else
  struct ifreq ifr;
  u_int32_t max_packet_size = CONST_DEFAULT_MAX_PACKET_SIZE; /* default */
  int fd;

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name)-1);
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

  if(strchr(ifname, ',')) {
    /* These are interfaces with , (e.g. eth0,eth1) */
    char ifaces[128], *iface, *tmp;
    u_int32_t speed = 0;

    snprintf(ifaces, sizeof(ifaces), "%s", ifname);
    iface = strtok_r(ifaces, ",", &tmp);

    while(iface) {
      u_int32_t thisSpeed = getMaxIfSpeed(iface);

      if(thisSpeed > speed) speed = thisSpeed;
      iface = strtok_r(NULL, ",", &tmp);
    }

    return(speed);
  }

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

  if((int32_t)ethtool_cmd_speed(&edata) != SPEED_UNKNOWN)
    ifSpeed = ethtool_cmd_speed(&edata);

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

in_addr_t Utils::inet_addr(const char *cp) {
  if((cp == NULL) || (cp[0] == '\0'))
    return(0);
  else
    return(::inet_addr(cp));
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
/* https://hwaddress.com/company/private */
bool Utils::isSpecialMac(u_int8_t *mac) {
  u_int8_t zero[6] = { 0, 0, 0, 0, 0, 0 };

  if(memcmp(mac, zero, 6) == 0)
    return(true);
  else {
    u_int16_t v2 = (mac[0] << 8) + mac[1];
    u_int32_t v3 = (mac[0] << 16) + (mac[1] << 8) + mac[2];

    switch(v3) {
    case 0x01000C:
    case 0x0180C2:
    case 0x01005E:
    case 0x010CCD:
    case 0x011B19:
    case 0x00006C:
    case 0x000101:
    case 0x000578:
    case 0x000B18:
    case 0x000BF4:
    case 0x000C53:
    case 0x000D58:
    case 0x000DA7:
    case 0x000DC2:
    case 0x000DF2:
    case 0x000E17:
    case 0x000E22:
    case 0x000E2A:
    case 0x000EEF:
    case 0x000F09:
    case 0x0016B4:
    case 0x001761:
    case 0x001825:
    case 0x002067:
    case 0x00221C:
    case 0x0022F1:
    case 0x00234A:
    case 0x00238C:
    case 0x0023F7:
    case 0x002419:
    case 0x0024FB:
    case 0x00259D:
    case 0x0025DF:
    case 0x00269F:
    case 0x005047:
    case 0x005079:
    case 0x0050C2:
    case 0x0050C7:
    case 0x0084ED:
    case 0x0086A0:
    case 0x00A054:
    case 0x00A085:
    case 0x00CB00:
    case 0x0418B6:
    case 0x0C8112:
    case 0x100000:
    case 0x10AE60:
    case 0x10B713:
    case 0x1100AA:
    case 0x111111:
    case 0x140708:
    case 0x146E0A:
    case 0x18421D:
    case 0x1CF4CA:
    case 0x205B2A:
    case 0x20D160:
    case 0x24336C:
    case 0x24BF74:
    case 0x28EF01:
    case 0x3CB87A:
    case 0x40A93F:
    case 0x40D855:
    case 0x487604:
    case 0x48D35D:
    case 0x48F317:
    case 0x50E14A:
    case 0x544E45:
    case 0x580943:
    case 0x586ED6:
    case 0x604BAA:
    case 0x609620:
    case 0x68E166:
    case 0x706F81:
    case 0x78F944:
    case 0x7CE4AA:
    case 0x8C8401:
    case 0x8CE748:
    case 0x906F18:
    case 0x980EE4:
    case 0x9C93E4:
    case 0xA0D86F:
    case 0xA468BC:
    case 0xA4A6A9:
    case 0xACDE48:
    case 0xACF85C:
    case 0xB025AA:
    case 0xB0ECE1:
    case 0xB0FEBD:
    case 0xB4E1EB:
    case 0xC02250:
    case 0xC8AACC:
    case 0xCC3ADF:
    case 0xD85DFB:
    case 0xDC7014:
    case 0xE0CB1D:
    case 0xE4F14C:
    case 0xE80410:
    case 0xE89E0C:
    case 0xF04F7C:
    case 0xF0A225:
    case 0xFCC233:
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
}

/* ****************************************************** */

void Utils::parseMac(u_int8_t *mac, const char *symMac) {
  int _mac[6] = { 0 };

  sscanf(symMac, "%x:%x:%x:%x:%x:%x",
	 &_mac[0], &_mac[1], &_mac[2],
	 &_mac[3], &_mac[4], &_mac[5]);
  
  for(int i = 0; i < 6; i++) mac[i] = (u_int8_t)_mac[i];
}

/* *********************************************** */

static int fill_prefix_v4(prefix_t *p, struct in_addr *a, int b, int mb) {
  if(b < 0 || b > mb)
    return(-1);
  
  memcpy(&p->add.sin, a, (mb+7)/8);
  p->family = AF_INET, p->bitlen = b, p->ref_count = 0;

  return(0);
}

/* ******************************************* */

static int fill_prefix_v6(prefix_t *prefix, struct in6_addr *addr, int bits, int maxbits) {
  if(bits < 0 || bits > maxbits)
    return -1;

  memcpy(&prefix->add.sin6, addr, (maxbits + 7) / 8);
  prefix->family = AF_INET6, prefix->bitlen = bits, prefix->ref_count = 0;

  return 0;
}

/* ******************************************* */

static int fill_prefix_mac(prefix_t *prefix, u_int8_t *mac, int bits, int maxbits) {
  if(bits < 0 || bits > maxbits)
    return -1;

  memcpy(prefix->add.mac, mac, 6);
  prefix->family = AF_MAC, prefix->bitlen = bits, prefix->ref_count = 0;

  return 0;
}

/* ******************************************* */

patricia_node_t* Utils::add_to_ptree(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;
  patricia_node_t *node;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else if(family == AF_INET6)
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_mac(&prefix, (u_int8_t*)addr, bits, tree->maxbits);

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

patricia_node_t* Utils::ptree_match(patricia_tree_t *tree, int family, const void * const addr, int bits) {
  prefix_t prefix;

  if(addr == NULL) return(NULL);
  
  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else if(family == AF_INET6)
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_mac(&prefix, (u_int8_t*)addr, bits, tree->maxbits);

  return(patricia_search_best(tree, &prefix));
}

/* ******************************************* */

patricia_node_t* Utils::ptree_add_rule(patricia_tree_t *ptree, char * const line) {
  char *ip, *bits, *slash = NULL;
  struct in_addr addr4;
  struct in6_addr addr6;
  u_int8_t mac[6];
  u_int32_t _mac[6];
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

  if(sscanf(ip, "%02X:%02X:%02X:%02X:%02X:%02X",
	    &_mac[0], &_mac[1], &_mac[2], &_mac[3], &_mac[4], &_mac[5]) == 6) {
    for(int i=0; i<6; i++) mac[i] = _mac[i];
    node = add_to_ptree(ptree, AF_MAC, mac, 48);
  } else if(strchr(ip, ':') != NULL) { /* IPv6 */
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
  u_int32_t  _mac[6];
  u_int8_t mac[6];
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

  if(sscanf(ip, "%02X:%02X:%02X:%02X:%02X:%02X",
	    &_mac[0], &_mac[1], &_mac[2], &_mac[3], &_mac[4], &_mac[5]) == 6) {
    for(int i=0; i<6; i++) mac[i] = _mac[i];
    rc = remove_from_ptree(ptree, AF_MAC, mac, 48);
  } else if(strchr(ip, ':') != NULL) { /* IPv6 */
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

/* ******************************************* */

int Utils::numberOfSetBits(u_int32_t i) {
  // Java: use >>> instead of >>
  // C or C++: use uint32_t
  i = i - ((i >> 1) & 0x55555555);
  i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
  return (((i + (i >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
}

/* ******************************************* */

void Utils::initRedis(Redis **r, const char *redis_host, const char *redis_password,
		      u_int16_t redis_port, u_int8_t _redis_db_id, bool giveup_on_failure) {
  if(r) {
    if(*r) delete(*r);
    (*r) = new Redis(redis_host, redis_password, redis_port, _redis_db_id, giveup_on_failure);
  }
}

/* ******************************************* */

/*
  IMPORTANT: line buffer is large enough to contain the replaced string
*/
void Utils::replacestr(char *line, const char *search, const char *replace) {
  char *sp;
  int search_len, replace_len, tail_len;

  if((sp = strstr(line, search)) == NULL) {
    return;
  }

  search_len = strlen(search), replace_len = strlen(replace);
  tail_len = strlen(sp+search_len);

  memmove(sp+replace_len,sp+search_len,tail_len+1);
  memcpy(sp, replace, replace_len);
}

/* ****************************************************** */

u_int32_t Utils::stringHash(const char *s) {
  u_int32_t hash = 0;
  const char *p = s;
  int pos = 0;

  while(*p) {
    hash += (*p) << pos;
    p++;
    pos += 8;
    if(pos == 32) pos = 0;
  }

  return hash;
}

/* ****************************************************** */

/* Note: the returned IP address is in network byte order */
u_int32_t Utils::getHostManagementIPv4Address() {
  int sock = socket(AF_INET, SOCK_DGRAM, 0);
  const char* kGoogleDnsIp = "8.8.8.8";
  u_int16_t kDnsPort = 53;
  struct sockaddr_in serv;
  struct sockaddr_in name;
  socklen_t namelen = sizeof(name);
  u_int32_t me;

  memset(&serv, 0, sizeof(serv));
  serv.sin_family = AF_INET;
  serv.sin_addr.s_addr = inet_addr(kGoogleDnsIp);
  serv.sin_port = htons(kDnsPort);

  if((connect(sock, (const struct sockaddr*) &serv, sizeof(serv)) == 0)
     && (getsockname(sock, (struct sockaddr*) &name, &namelen) == 0)) {
    me = name.sin_addr.s_addr;
  } else
    me = inet_addr("127.0.0.1");

  closesocket(sock);

  return(me);
}

/* ****************************************************** */

bool Utils::isInterfaceUp(char *ifname) {
#ifdef WIN32
  return(true);
#else
  struct ifreq ifr;
  char *colon;
  int sock;

  sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);

  if (sock == -1)
    return(false);

  /* Handle PF_RING interfaces zc:ens2f1@3 */
  colon = strchr(ifname, ':');
  if(colon != NULL) /* removing pf_ring module prefix (e.g. zc:ethX) */
    ifname = colon+1;

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, IFNAMSIZ-1);

  if (ioctl(sock, SIOCGIFFLAGS, &ifr) < 0) {
    close(sock);
    return(false);
  }

  close(sock);

  return(!!(ifr.ifr_flags & IFF_UP) ? true : false);
#endif
}

/* ****************************************************** */

bool Utils::maskHost(bool isLocalIP) {
  bool mask_host = false;

  switch(ntop->getPrefs()->getHostMask()) {
  case mask_local_hosts:
    if(isLocalIP) mask_host = true;
    break;

  case mask_remote_hosts:
    if(!isLocalIP) mask_host = true;
    break;

  default:
    break;
  }

  return(mask_host);
}

/* ****************************************************** */

void Utils::luaCpuLoad(lua_State* vm) {
#if !defined(__FreeBSD__) && !defined(__NetBSD__) & !defined(__OpenBSD__) && !defined(__APPLE__) && !defined(WIN32)
  long unsigned int user, nice, system, idle, iowait, irq, softirq;
  FILE *fp;

  if(vm) {
    if((fp = fopen("/proc/stat", "r"))) {
      fscanf(fp,"%*s %lu %lu %lu %lu %lu %lu %lu",
	     &user, &nice, &system, &idle, &iowait, &irq, &softirq);
      fclose(fp);

      lua_push_uint64_table_entry(vm, "cpu_load", user + nice + system + iowait + irq + softirq);
      lua_push_uint64_table_entry(vm, "cpu_idle", idle);
    }
  }
#endif
};

/* ****************************************************** */

void Utils::luaMeminfo(lua_State* vm) {
#if !defined(__FreeBSD__) && !defined(__NetBSD__) & !defined(__OpenBSD__) && !defined(__APPLE__) && !defined(WIN32)
  long unsigned int memtotal = 0, memfree = 0, buffers = 0, cached = 0, sreclaimable = 0, shmem = 0;
  long unsigned int mem_resident = 0, mem_virtual = 0;
  char *line = NULL;
  size_t len;
  int read;
  FILE *fp;

  if(vm) {
    if((fp = fopen("/proc/meminfo", "r"))) {
      while ((read = getline(&line, &len, fp)) != -1) {
	if(!strncmp(line, "MemTotal", strlen("MemTotal")) && sscanf(line, "%*s %lu kB", &memtotal))
	  lua_push_uint64_table_entry(vm, "mem_total", memtotal);
	else if(!strncmp(line, "MemFree", strlen("MemFree")) && sscanf(line, "%*s %lu kB", &memfree))
	  lua_push_uint64_table_entry(vm, "mem_free", memfree);
	else if(!strncmp(line, "Buffers", strlen("Buffers")) && sscanf(line, "%*s %lu kB", &buffers))
	  lua_push_uint64_table_entry(vm, "mem_buffers", buffers);
	else if(!strncmp(line, "Cached", strlen("Cached")) && sscanf(line, "%*s %lu kB", &cached))
	  lua_push_uint64_table_entry(vm, "mem_cached", cached);
	else if(!strncmp(line, "SReclaimable", strlen("SReclaimable")) && sscanf(line, "%*s %lu kB", &sreclaimable))
	  lua_push_uint64_table_entry(vm, "mem_sreclaimable", sreclaimable);
	else if(!strncmp(line, "Shmem", strlen("Shmem")) && sscanf(line, "%*s %lu kB", &shmem))
	  lua_push_uint64_table_entry(vm, "mem_shmem", shmem);
      }

      if(line) {
        free(line);
        line = NULL;
      }

      fclose(fp);

      /* Equivalent to top utility mem used */
      lua_push_uint64_table_entry(vm, "mem_used", memtotal - memfree - (buffers + cached + sreclaimable - shmem));
    }

    if((fp = fopen("/proc/self/status", "r"))) {
      while((read = getline(&line, &len, fp)) != -1) {
          if(!strncmp(line, "VmRSS", strlen("VmRSS")) && sscanf(line, "%*s %lu kB", &mem_resident))
            lua_push_uint64_table_entry(vm, "mem_ntopng_resident", mem_resident);
          else if(!strncmp(line, "VmSize", strlen("VmSize")) && sscanf(line, "%*s %lu kB", &mem_virtual))
            lua_push_uint64_table_entry(vm, "mem_ntopng_virtual", mem_virtual);
      }

      if(line) {
        free(line);
        line = NULL;
      }

      fclose(fp);
    }
  }
#endif
};

/* ****************************************************** */

char* Utils::getInterfaceDescription(char *ifname, char *buf, int buf_len) {
  char ebuf[PCAP_ERRBUF_SIZE];
  pcap_if_t *devs, *devpointer;

  snprintf(buf, buf_len, "%s", ifname);
  ebuf[0] = '\0';

  if(pcap_findalldevs(&devs, ebuf) == 0) {
    devpointer = devs;

    for(int i = 0; devpointer != NULL; i++) {
      if(strcmp(devpointer->name, ifname) == 0) {
	if(devpointer->description)
	  snprintf(buf, buf_len, "%s", devpointer->description);
	break;
      } else
	devpointer = devpointer->next;
    }

    pcap_freealldevs(devs);
  }

  return(buf);
}

/* ****************************************************** */

int Utils::bindSockToDevice(int sock, int family, const char* devicename) {
#ifdef WIN32
  return(-1);
#else
  struct ifaddrs* pList = NULL;
  struct ifaddrs* pAdapter = NULL;
  struct ifaddrs* pAdapterFound = NULL;
  int bindresult = -1;

  int result = getifaddrs(&pList);

  if(result < 0)
    return -1;

  pAdapter = pList;
  while(pAdapter) {
    if((pAdapter->ifa_addr != NULL) && (pAdapter->ifa_name != NULL) && (family == pAdapter->ifa_addr->sa_family)) {
      if(strcmp(pAdapter->ifa_name, devicename) == 0) {
	pAdapterFound = pAdapter;
	break;
      }
    }

    pAdapter = pAdapter->ifa_next;
  }

  if(pAdapterFound != NULL) {
    int addrsize = (family == AF_INET6) ? sizeof(sockaddr_in6) : sizeof(sockaddr_in);
    bindresult = ::bind(sock, pAdapterFound->ifa_addr, addrsize);
  }

  freeifaddrs(pList);
  return bindresult;
#endif
}

/* ****************************************************** */

int Utils::retainWriteCapabilities() {
  int rc = 0;

#ifdef HAVE_LIBCAP
  cap_t caps;

  /* Add the capability of interest to the permitted capabilities  */
  caps = cap_get_proc();
  cap_set_flag(caps, CAP_PERMITTED, num_cap, cap_values, CAP_SET);
  cap_set_flag(caps, CAP_EFFECTIVE, num_cap, cap_values, CAP_SET);
  rc = cap_set_proc(caps);

  if(rc == 0) {
    /* Tell the kernel to retain permitted capabilities */
    if(prctl(PR_SET_KEEPCAPS, 1, 0, 0, 0) != 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to retain permitted capabilities [%s]\n", strerror(errno));
      rc = -1;
    }
  }

  cap_free(caps);
#else
#ifndef __APPLE__
  rc = -1;
  ntop->getTrace()->traceEvent(TRACE_WARNING, "ntopng has not been compiled with libcap-dev");
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Network discovery and other privileged activities will fail");
#endif
#endif

  return(rc);
}

/* ****************************************************** */

#ifndef __APPLE__
static int _setWriteCapabilities(int enable) {
  int rc = 0;

#ifdef HAVE_LIBCAP
  cap_t caps;

  caps = cap_get_proc();
  if(caps) {
    cap_set_flag(caps, CAP_EFFECTIVE, num_cap, cap_values, enable ? CAP_SET : CAP_CLEAR);
    rc = cap_set_proc(caps);
    cap_free(caps);
  } else
    rc = -1;
#else
  rc = -1;
#endif

  return(rc);
}
#endif

/* ****************************************************** */

/*
  Usage example

  local path="/etc/test.lua"

  ntop.gainWriteCapabilities()

  file = io.open(path, "w")
  if(file ~= nil) then
  file:write("-- End of the test.lua file")
  file:close()
  else
  print("Unable to create file "..path.."<p>")
  end

  ntop.dropWriteCapabilities()
*/

int Utils::gainWriteCapabilities() {
#ifndef __APPLE__
  return(_setWriteCapabilities(true));
#else
  return(0);
#endif
}

/* ****************************************************** */

int Utils::dropWriteCapabilities() {
#ifndef __APPLE__
  return(_setWriteCapabilities(false));
#else
  return(0);
#endif
}

/* ******************************* */

/* Return IP is network byte order */
u_int32_t Utils::findInterfaceGatewayIPv4(const char* ifname) {
#ifndef WIN32
  char cmd[128];
  FILE *fp;

  sprintf(cmd, "netstat -rn | grep '%s' | grep 'UG' | awk '{print $2}'", ifname);

  if((fp = popen(cmd, "r")) != NULL) {
    char line[256];
    u_int32_t rc = 0;

    if(fgets(line, sizeof(line), fp) != NULL)
      rc = inet_addr(line);

    pclose(fp);
    return(rc);
  } else
#endif
    return(0);
}

/* ******************************* */

void Utils::maximizeSocketBuffer(int sock_fd, bool rx_buffer, u_int max_buf_mb) {
  int i, rcv_buffsize_base, rcv_buffsize, max_buf_size = 1024 * max_buf_mb * 1024, debug = 0;
  socklen_t len = sizeof(rcv_buffsize_base);
  int buf_type = rx_buffer ? SO_RCVBUF /* RX */ : SO_SNDBUF /* TX */;
    
  if(getsockopt(sock_fd, SOL_SOCKET, buf_type, (char*)&rcv_buffsize_base, &len) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read socket receiver buffer size [%s]",
				 strerror(errno));
    return;
  } else {
    if(debug) ntop->getTrace()->traceEvent(TRACE_INFO, "Default socket %s buffer size is %d",
					   buf_type == SO_RCVBUF ? "receive" : "send",
					   rcv_buffsize_base);
  }

  for(i=2;; i++) {
    rcv_buffsize = i * rcv_buffsize_base;
    if(rcv_buffsize > max_buf_size) break;

    if(setsockopt(sock_fd, SOL_SOCKET, buf_type, (const char*)&rcv_buffsize, sizeof(rcv_buffsize)) < 0) {
      if(debug) ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set socket %s buffer size [%s]",
					     buf_type == SO_RCVBUF ? "receive" : "send",
					     strerror(errno));
      break;
    } else
      if(debug) ntop->getTrace()->traceEvent(TRACE_INFO, "%s socket buffer size set %d",
					     buf_type == SO_RCVBUF ? "Receive" : "Send",
					     rcv_buffsize);
  }
}

/* ****************************************************** */

char* Utils::formatTraffic(float numBits, bool bits, char *buf) {
  char unit;

  if(bits)
    unit = 'b';
  else
    unit = 'B';

  if(numBits < 1024) {
    snprintf(buf, 32, "%lu %c", (unsigned long)numBits, unit);
  } else if(numBits < 1048576) {
    snprintf(buf, 32, "%.2f K%c", (float)(numBits)/1024, unit);
  } else {
    float tmpMBits = ((float)numBits)/1048576;

    if(tmpMBits < 1024) {
      snprintf(buf, 32, "%.2f M%c", tmpMBits, unit);
    } else {
      tmpMBits /= 1024;

      if(tmpMBits < 1024) {
	snprintf(buf, 32, "%.2f G%c", tmpMBits, unit);
      } else {
	snprintf(buf, 32, "%.2f T%c", (float)(tmpMBits)/1024, unit);
      }
    }
  }

  return(buf);
}

/* ****************************************************** */

char* Utils::formatPackets(float numPkts, char *buf) {
  if(numPkts < 1000) {
    snprintf(buf, 32, "%.2f", numPkts);
  } else if(numPkts < 1000000) {
    snprintf(buf, 32, "%.2f K", numPkts/1000);
  } else {
    numPkts /= 1000000;
    snprintf(buf, 32, "%.2f M", numPkts);
  }

  return(buf);
}

/* ****************************************************** */

bool Utils::str2DetailsLevel(const char *details, DetailsLevel *out) {
  bool rv = false;

  if(!strcmp(details, "normal")) {
    *out = details_normal;
    rv = true;
  } else if(!strcmp(details, "high")) {
    *out = details_high;
    rv = true;
  } else if(!strcmp(details, "higher")) {
    *out = details_higher;
    rv = true;
  } else if(!strcmp(details, "max")) {
    *out = details_max;
    rv = true;
  }

  return rv;
}

/* ****************************************************** */

bool Utils::isCriticalNetworkProtocol(u_int16_t protocol_id) {
  return (protocol_id == NDPI_PROTOCOL_DNS) || (protocol_id == NDPI_PROTOCOL_DHCP);
}

/* ****************************************************** */

u_int32_t Utils::roundTime(u_int32_t now, u_int32_t rounder, int32_t offset_from_utc) {
  now -= (now % rounder);
  now += rounder; /* Aligned to midnight UTC */

  if(offset_from_utc > 0)
    now += 86400 - offset_from_utc;
  else if(offset_from_utc < 0)
    now += -offset_from_utc;

  return(now);
}

/* ************************************************* */

/*
  now
  now+1h   (hour)
  now+1d   (day)
  now+1w   (week)
  now+1m   (month)
  now+1min (minute)
  now+1y   (year)
*/
u_int32_t Utils::parsetime(char *str) {
  if(!strncmp(str, "now", 3)) {
    char op = str[3];
    int v;
    char what[64];
    u_int32_t ret = time(NULL);

    if(op == '\0')
      return(ret);    
    else if(sscanf(&str[4], "%d%s", &v, what) == 2) {
      if(!strcmp(what, "h"))        v *= 3600;
      else if(!strcmp(what, "d"))   v *= 3600*24;
      else if(!strcmp(what, "w"))   v *= 3600*24*7;
      else if(!strcmp(what, "m"))   v *= 3600*24*7*30;
      else if(!strcmp(what, "min")) v *= 60;
      else if(!strcmp(what, "y"))   v *= 3600*24*7*365;

      if(op == '-')
	ret -= v;
      else
	ret += v;

      return(ret);
    } else
      return(0);
  } else
    return(atol(str));
}

/* ************************************************* */

u_int64_t Utils::mac2int(u_int8_t *mac) {
  u_int64_t m = 0;

  memcpy(&m, mac, 6);
  return(m);
}

/* ************************************************* */

u_int8_t* Utils::int2mac(u_int64_t mac, u_int8_t *buf) {
  memcpy(buf, &mac, 6);
  buf[6] = buf[7] = '\0';
  return(buf);
}


/* ************************************************* */

void Utils::init_pcap_header(struct pcap_file_header * const h, NetworkInterface * const iface) {
  /*
   * [0000000] c3d4 a1b2 0002 0004 0000 0000 0000 0000
   * [0000010] 05ea 0000 0001 0000
   */
  if(!h || !iface)
    return;

  memset(h, 0, sizeof(*h));

  h->magic = PCAP_MAGIC;
  h->version_major = 2;
  h->version_minor = 4;
  h->thiszone = 0;
  h->sigfigs  = 0;
  h->snaplen  = ntop->getGlobals()->getSnaplen();
  h->linktype = iface->isPacketInterface() ? iface->get_datalink() : DLT_EN10MB;
}

/* ****************************************************** */

void Utils::listInterfaces(lua_State* vm) {
  char ebuf[PCAP_ERRBUF_SIZE];
  pcap_if_t *pdevs, *pdev;
#ifdef HAVE_PF_RING
  pfring_if_t *pfdevs, *pfdev;
#endif

  if (pcap_findalldevs(&pdevs, ebuf) != 0) 
    return;

#ifdef HAVE_PF_RING
  pfdevs = pfring_findalldevs();

  pfdev = pfdevs;
  while (pfdev != NULL) {

    /* merge with info from pcap */
    pdev = pdevs;
    while (pdev != NULL) {
      if (pfdev->system_name && strcmp(pfdev->system_name, pdev->name) == 0)
        break;
      pdev = pdev->next;
    }

    if (pdev == NULL /* not a standard interface (e.g. fpga) */
        || (Utils::isInterfaceUp(pfdev->system_name) && Utils::validInterface(pdev->description))) {
      lua_newtable(vm);
      lua_push_str_table_entry(vm, "description", (pdev && pdev->description) ? pdev->description : (char *) "");
      lua_push_str_table_entry(vm, "module", pfdev->module);
      lua_push_bool_table_entry(vm, "license", !!pfdev->license);
      lua_pushstring(vm, pfdev->system_name ? pfdev->system_name : pfdev->name);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }

    pfdev = pfdev->next;
  }
#endif

  pdev = pdevs;
  while (pdev != NULL) {
    if (Utils::validInterface(pdev->description) && 
        Utils::isInterfaceUp(pdev->name)) {

#ifdef HAVE_PF_RING
      /* check if already listed */
      pfdev = pfdevs;
      while (pfdev != NULL) {
        if (strcmp(pfdev->system_name, pdev->name) == 0)
          break;
        pfdev = pfdev->next;
      }

      if (pfdev == NULL) {
#endif
        lua_newtable(vm);
        lua_push_str_table_entry(vm, "description", pdev->description ? pdev->description : (char *) "");
        lua_pushstring(vm, pdev->name);
        lua_insert(vm, -2);
        lua_settable(vm, -3);
#ifdef HAVE_PF_RING
      }
#endif
    }

    pdev = pdev->next;
  }

#ifdef HAVE_PF_RING 
  pfring_freealldevs(pfdevs);
#endif
  pcap_freealldevs(pdevs);
}

/* ****************************************************** */

bool Utils::validInterface(char *name) {
#ifdef HAVE_NEDGE
  return((name && (strncmp(name, "nf:", 3) == 0)) ? true : false);
#else
  if(name &&
     (strstr(name, "PPP")            /* Avoid to use the PPP interface              */
      || strstr(name, "dialup")      /* Avoid to use the dialup interface           */
      || strstr(name, "ICSHARE")     /* Avoid to use the internet sharing interface */
      || strstr(name, "NdisWan"))) { /* Avoid to use the internet sharing interface */
    return(false);
  }

  return(true);
#endif
}

/* ****************************************************** */

const char* Utils::policySource2Str(L7PolicySource_t policy_source) {
  switch(policy_source) {
  case policy_source_pool:
    return "policy_source_pool";
  case policy_source_protocol:
    return "policy_source_protocol";
  case policy_source_category:
    return "policy_source_category";
  case policy_source_device_protocol:
    return "policy_source_device_protocol";
  case policy_source_schedule:
    return "policy_source_schedule";
  default:
    return "policy_source_default";
  }
}

/* ****************************************************** */

const char* Utils::captureDirection2Str(pcap_direction_t dir) {
  switch(dir) {
  case PCAP_D_IN:
    return "in";
  case PCAP_D_OUT:
    return "out";
  case PCAP_D_INOUT:
  default:
    return "inout";
  }
}

/* ****************************************************** */

bool Utils::readInterfaceStats(const char *ifname, ProtoStats *in_stats, ProtoStats *out_stats) {
  bool rv = false;
#ifndef WIN32
  FILE *f = fopen("/proc/net/dev", "r");

  if(f) {
    char line[512];
    char to_find[IFNAMSIZ+2];
    snprintf(to_find, sizeof(to_find), "%s:", ifname);

    while(fgets(line, sizeof(line), f)) {
      long long unsigned int in_bytes, out_bytes, in_packets, out_packets;

      if(strstr(line, to_find) &&
         sscanf(line, "%*[^:]: %llu %llu %*u %*u %*u %*u %*u %*u %llu %llu",
           &in_bytes, &in_packets, &out_bytes, &out_packets) == 4) {
        ntop->getTrace()->traceEvent(TRACE_DEBUG,
          "iface_counters: in_bytes=%llu in_packets=%llu - out_bytes=%llu out_packets=%llu",
          in_bytes, in_packets, out_bytes, out_packets);
        in_stats->setBytes(in_bytes);
        in_stats->setPkts(in_packets);
        out_stats->setBytes(out_bytes);
        out_stats->setPkts(out_packets);
        rv = true;
        break;
      }
    }
  }

  if(f)
    fclose(f);
#endif

  return rv;
}

/* ****************************************************** */

bool Utils::shouldResolveHost(const char *host_ip) {
  if(!ntop->getPrefs()->is_dns_resolution_enabled())
    return false;

  if(!ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
    /*
      In case only local addresses need to be resolved, skip
      remote hosts
    */
    IpAddress ip;
    int16_t network_id;

    ip.set((char*)host_ip);
    if(!ip.isLocalHost(&network_id))
      return false;
  }

  return true;
}

/* ****************************************************** */

bool Utils::mg_write_retry(struct mg_connection *conn, u_char *b, int len) {
  int ret, sent = 0;
  time_t max_retry = 1000;

  while (!ntop->getGlobals()->isShutdown() && --max_retry) {
    ret = mg_write_async(conn, &b[sent], len-sent);
    if (ret < 0)
      return false;
    sent += ret;
    if (sent == len) return true;
    _usleep(100);
  }

  return false;
}

/* ****************************************************** */

bool Utils::parseAuthenticatorJson(HTTPAuthenticator *auth, char *content) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;

  o = json_tokener_parse_verbose(content, &jerr);
  if (o) {
    json_object *w;

    if(json_object_object_get_ex(o, "admin", &w))
      auth->admin  = (bool)json_object_get_boolean(w);

    if(json_object_object_get_ex(o, "allowedIfname", &w))
      auth->allowedIfname  = strdup((char *)json_object_get_string(w));

    if(json_object_object_get_ex(o, "allowedNets", &w))
      auth->allowedNets  = strdup((char *)json_object_get_string(w));

    if(json_object_object_get_ex(o, "language", &w))
      auth->language  = strdup((char *)json_object_get_string(w));

    json_object_put(o);
    return true;
  }
  return false;
}

void Utils::freeAuthenticator(HTTPAuthenticator *auth) {
  if(auth == NULL)
    return;
  if(auth->allowedIfname) free(auth->allowedIfname);
  if(auth->allowedNets) free(auth->allowedNets);
  if(auth->language) free(auth->language);
}

/* ****************************************************** */
