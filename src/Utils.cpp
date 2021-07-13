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

#include "ntop_includes.h"

extern "C" {
#include "third-party/fast-sha1/sha1-fast.c"
}

#if defined(__OpenBSD__) || defined(__APPLE__) || defined(__FreeBSD__)
#include <net/if_dl.h>
#endif

#ifndef WIN32
#include <ifaddrs.h>
#endif

static const char *hex_chars = "0123456789ABCDEF";

static map<string, int> initTcpStatesStr2State() {
  map<string, int>states_map;

  states_map["ESTABLISHED"] = TCP_ESTABLISHED;
  states_map["SYN-SENT"] = TCP_SYN_SENT;
  states_map["SYN-RECV"] = TCP_SYN_RECV;
  states_map["FIN-WAIT-1"] = TCP_FIN_WAIT1;
  states_map["FIN-WAIT-2"] = TCP_FIN_WAIT2;
  states_map["TIME-WAIT"] = TCP_TIME_WAIT;
  states_map["CLOSE"] = TCP_CLOSE;
  states_map["CLOSE-WAIT"] = TCP_CLOSE_WAIT;
  states_map["LAST-ACK"] = TCP_LAST_ACK;
  states_map["LISTEN"] = TCP_LISTEN;
  states_map["CLOSING"] = TCP_CLOSING;

  return states_map;
}

static map<string, eBPFEventType> initeBPFEventTypeStr2Type() {
  map<string, eBPFEventType>events_map;

  /* TCP EVENTS */
  events_map["ACCEPT"] = ebpf_event_type_tcp_accept;
  events_map["CONNECT"] = ebpf_event_type_tcp_connect;
  events_map["CONNECT_FAILED"] = ebpf_event_type_tcp_connect_failed;
  events_map["CLOSE"] = ebpf_event_type_tcp_close;
  events_map["RETRANSMIT"] = epbf_event_type_tcp_retransmit;

  /* UDP EVENTS */
  events_map["SEND"] = ebpf_event_type_udp_send;
  events_map["RECV"] = ebpf_event_type_udp_recv;

  return events_map;
};

static map<int, string> initTcpStates2StatesStr(const map<string, int> &tcp_states_str_to_state) {
  map<int, string>states_map;
  map<string, int>::const_iterator it;

  for(it = tcp_states_str_to_state.begin(); it != tcp_states_str_to_state.end(); it++) {
    states_map[it->second] = it->first;
  }

  return states_map;
}

static map<eBPFEventType, string> initeBPFEventType2TypeStr(const map<string, eBPFEventType> &tcp_states_str_to_state) {
  map<eBPFEventType, string>events_map;
  map<string, eBPFEventType>::const_iterator it;

  for(it = tcp_states_str_to_state.begin(); it != tcp_states_str_to_state.end(); it++) {
    events_map[it->second] = it->first;
  }

  return events_map;
};

static const map<string, int> tcp_state_str_2_state = initTcpStatesStr2State();
static const map<int, string> tcp_state_2_state_str = initTcpStates2StatesStr(tcp_state_str_2_state);
static const map<string, eBPFEventType> ebpf_event_str_2_event = initeBPFEventTypeStr2Type();
static const map<eBPFEventType, string> ebpf_event_2_event_str = initeBPFEventType2TypeStr(ebpf_event_str_2_event);

// A simple struct for strings.
typedef struct {
  char *s;
  size_t l;
} String;

typedef struct {
  u_int8_t header_over;
  char outbuf[3*65536];
  u_int num_bytes;
  lua_State* vm;
  bool return_content;
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

char* Utils::jsonLabel(int label, const char *label_str,char *buf, u_int buf_len) {
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

const char* Utils::edition2name(NtopngEdition ntopng_edition) {
  switch(ntopng_edition) {
  case ntopng_edition_community:
    return "community";
  case ntopng_edition_pro:
    return "pro";
  case ntopng_edition_enterprise_m:
    return "enterprise_m";
  case ntopng_edition_enterprise_l:
    return "enterprise_l";
  default:
    return "unknown";
  }
}

/* ****************************************************** */

u_int8_t Utils::l4name2proto(const char *name) {
       if(strcmp(name, "IP") == 0) return 0;
  else if(strcmp(name, "ICMP") == 0) return 1;
  else if(strcmp(name, "IGMP") == 0) return 2;
  else if(strcmp(name, "TCP") == 0) return 6;
  else if(strcmp(name, "UDP") == 0) return 17;
  else if(strcmp(name, "IPv6") == 0) return 41;
  else if(strcmp(name, "RSVP") == 0) return 46;
  else if(strcmp(name, "GRE") == 0) return 47;
  else if(strcmp(name, "ESP") == 0) return 50;
  else if(strcmp(name, "AH") == 0) return 51;
  else if(strcmp(name, "IPv6-ICMP") == 0) return 58;
  else if(strcmp(name, "OSPF") == 0) return 89;
  else if(strcmp(name, "PIM") == 0) return 103;
  else if(strcmp(name, "VRRP") == 0) return 112;
  else if(strcmp(name, "HIP") == 0) return 139;
  else return 0;
}

/* ****************************************************** */

u_int8_t Utils::queryname2type(const char *name) {
       if(strcmp(name, "A") == 0) return 1;
  else if(strcmp(name, "NS") == 0) return 2;
  else if(strcmp(name, "MD") == 0) return 3;
  else if(strcmp(name, "MF") == 0) return 4;
  else if(strcmp(name, "CNAME") == 0) return 5;
  else if(strcmp(name, "SOA") == 0) return 6;
  else if(strcmp(name, "MB") == 0) return 7;
  else if(strcmp(name, "MG") == 0) return 8;
  else if(strcmp(name, "MR") == 0) return 9;
  else if(strcmp(name, "NULL") == 0) return 10;
  else if(strcmp(name, "WKS") == 0) return 11;
  else if(strcmp(name, "PTR") == 0) return 12;
  else if(strcmp(name, "HINFO") == 0) return 13;
  else if(strcmp(name, "MINFO") == 0) return 14;
  else if(strcmp(name, "MX") == 0) return 15;
  else if(strcmp(name, "TXT") == 0) return 16;
  else if(strcmp(name, "AAAA") == 0) return 28;
  else if(strcmp(name, "A6") == 0) return 38;
  else if(strcmp(name, "SPF") == 0) return 99;
  else if(strcmp(name, "AXFR") == 0) return 252;
  else if(strcmp(name, "MAILB") == 0) return 253;
  else if(strcmp(name, "MAILA") == 0) return 254;
  else if(strcmp(name, "ANY") == 0) return 255;
  else return 0;
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

#ifdef __linux__

int Utils::setAffinityMask(char *cores_list, cpu_set_t *mask) {
  int ret = 0;
#ifdef HAVE_LIBCAP
  char *core_id_s, *tmp = NULL;
  u_int num_cores = ntop->getNumCPUs();

  CPU_ZERO(mask);

  if(cores_list == NULL)
    return 0;

  if(num_cores <= 1)
    return 0;

  core_id_s = strtok_r(cores_list, ",", &tmp);

  while (core_id_s) {
    long core_id = atoi(core_id_s);
    u_long core = core_id % num_cores;

    CPU_SET(core, mask);

    core_id_s = strtok_r(NULL, ",", &tmp);
  }
#endif

  return ret;
}
#endif

/* ****************************************************** */

#ifdef __linux__
int Utils::setThreadAffinityWithMask(pthread_t thread, cpu_set_t *mask) {
  int ret = -1;

  if(mask == NULL || CPU_COUNT(mask) == 0)
    return(0);

#ifdef HAVE_LIBCAP
  ret = pthread_setaffinity_np(thread, sizeof(cpu_set_t), mask);
#endif

  return(ret);
}
#endif

/* ****************************************************** */

int Utils::setThreadAffinity(pthread_t thread, int core_id) {
#ifdef __linux__
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
      ret = setThreadAffinityWithMask(thread, &cpu_set);
    }
#endif

    return(ret);
  }
#else
  return(0);
#endif
}

/* ****************************************************** */

void Utils::setThreadName(const char *name) {
#if defined(__APPLE__) || defined(__linux__)
  // Mac OS X: must be set from within the thread (can't specify thread ID)
  char buf[16]; // NOTE: on linux there is a 16 char limit
  int rc;
  char *bname = NULL;

  if(Utils::file_exists(name)) {
    bname = strrchr((char*)name, '/');
    if(bname) bname++;
  }

  snprintf(buf, sizeof(buf), "%s", bname ? bname : name);

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

u_int32_t Utils::hashString(const char * const key) {
  if(!key)
    return 0;

  u_int32_t hash = 0, len = (u_int32_t)strlen(key);

  for(u_int32_t i = 0; i < len; i++)
    hash += ((u_int32_t)key[i]) * i;

  return hash;
}

/* ****************************************************** */

float Utils::timeval2ms(const struct timeval *tv) {
  return((float)tv->tv_sec*1000+(float)tv->tv_usec/1000);
}

/* ****************************************************** */

u_int32_t Utils::timeval2usec(const struct timeval *tv) {
  return(tv->tv_sec*1000000+tv->tv_usec);
}

/* ****************************************************** */

u_int32_t Utils::usecTimevalDiff(const struct timeval *end, const struct timeval *begin) {
  if((end->tv_sec == 0) && (end->tv_usec == 0))
    return(0);
  else {
    struct timeval res;

    res.tv_sec = end->tv_sec - begin->tv_sec;
    if(begin->tv_usec > end->tv_usec) {
      res.tv_usec = end->tv_usec + 1000000 - begin->tv_usec;
      res.tv_sec--;
    } else
      res.tv_usec = end->tv_usec - begin->tv_usec;

    return((res.tv_sec*1000000) + (res.tv_usec));
  }
}

/* ****************************************************** */

float Utils::msTimevalDiff(const struct timeval *end, const struct timeval *begin) {
  if((end->tv_sec == 0) && (end->tv_usec == 0))
    return(0);
  else {
    struct timeval res;

    res.tv_sec = end->tv_sec - begin->tv_sec;
    if(begin->tv_usec > end->tv_usec) {
      res.tv_usec = end->tv_usec + 1000000 - begin->tv_usec;
      res.tv_sec--;
    } else
      res.tv_usec = end->tv_usec - begin->tv_usec;

    return(((float)res.tv_sec*1000) + ((float)res.tv_usec/(float)1000));
  }
}

/* ****************************************************** */

/* Converts a ISO 8601 timestamp (exported by Suricata) to epoch.
 * Example: 2019-04-02T19:29:42.346861+0200 */
time_t Utils::str2epoch(const char *str) {
  struct tm tm;
  time_t t;
  const char *format = "%FT%T%Z";

  memset(&tm, 0, sizeof(tm));

  if(strptime(str, format, &tm) == NULL)
    return 0;

  t = mktime(&tm) + (3600 * tm.tm_isdst);

#ifndef WIN32
  t -= tm.tm_gmtoff;
#endif

  if(t == -1)
    return 0;

  return t;
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
  struct stat buf;

  return !((stat(path, &buf) != 0) || (!S_ISDIR(buf.st_mode)));
}

/* ****************************************************** */

size_t Utils::file_write(const char *path, const char *content, size_t content_len) {
  size_t ret = 0;
  FILE *fd = fopen(path, "wb");

  if(fd == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to write file %s", path);
  } else {
#ifndef WIN32
    chmod(path, CONST_DEFAULT_FILE_MODE);
#endif

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

    if(buffer) {
      if(content && ret)
        *content = buffer;
      else
        free(buffer);
    }
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
	    struct stat statbuf;

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
  struct stat s;

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
    if(chmod(path, mode) == -1) /* Ubuntu 18 */
      ntop->getTrace()->traceEvent(TRACE_WARNING, "chmod(%s) failed [%d/%s]",
				   path, errno, strerror(errno));
  }

  return(rc);
#endif
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
    /* Change the working dir ownership */
    rv = chown(ntop->get_working_dir(), pw->pw_uid, pw->pw_gid);
    if(rv != 0)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to change working dir '%s' owner", ntop->get_working_dir());

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

    if(ntop)
      ntop->setDroppedPrivileges();

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
  if(BLOCK_LEN - rem < LENGTH_SIZE) {
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

  if(name && !strcmp(name, SYSTEM_INTERFACE_NAME))
    return SYSTEM_INTERFACE_ID;

  if(name == NULL)
    return INVALID_INTERFACE_ID;

#ifdef WIN32
  else if(isdigit(name[0]))
      return(atoi(name));
#endif
  else if(!strncmp(name, "-", 1))
      name = (char*) "stdin";

  if(ntop->getRedis()) {
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
  }

  return INVALID_INTERFACE_ID; /* This can't happen, hopefully */
}

/* **************************************************** */

char* Utils::stringtolower(char *str) {
  int i = 0;

  while (str[i] != '\0') {
    str[i] = tolower(str[i]);
    i++;
  }

  return str;
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

  stripped_str = (char *) malloc(len + 1);

  if(!stripped_str)
    return(NULL);

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

/* ************************************************************ */

bool Utils::sendTCPData(char *host, int port, char *data, int timeout /* msec */) {
  struct hostent *server = NULL;
  struct sockaddr_in serv_addr;
  int sockfd = -1;
  int retval;
  bool rc = false;

  server = gethostbyname(host);
  if(server == NULL)
    return false;

  memset((char*)&serv_addr, 0, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  memcpy((char*)&serv_addr.sin_addr.s_addr, (char*)server->h_addr, server->h_length);
  serv_addr.sin_port = htons(port);

  sockfd = socket(AF_INET, SOCK_STREAM, 0);

  if(sockfd < 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
    return false;
  }

#ifndef WIN32
  if(timeout == 0) {
    retval = fcntl(sockfd, F_SETFL, fcntl(sockfd,F_GETFL,0) | O_NONBLOCK);
    if(retval == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Error setting NONBLOCK flag");
      closesocket(sockfd);
      return false;
    }
  } else {
    struct timeval tv_timeout;
    tv_timeout.tv_sec  = timeout/1000;
    tv_timeout.tv_usec = (timeout%1000)*1000;
    retval = setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &tv_timeout, sizeof(tv_timeout));
    if(retval == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Error setting send timeout: %s", strerror(errno));
      closesocket(sockfd);
      return false;
    }
  }
#endif

  if(connect(sockfd,(struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0
     && (errno == ECONNREFUSED || errno == EALREADY || errno == EAGAIN ||
	 errno == ENETUNREACH  || errno == ETIMEDOUT )) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,"Could not connect to remote party");
    closesocket(sockfd);
    return false;
  }

  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Sending '%s' to %s:%d",
  //  data, host, port);

  rc = true;
  retval = send(sockfd, data, strlen(data), 0);
  if(retval <= 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Send failed: %s (%d)",
      strerror(errno), errno);
    rc = false;
  }

  closesocket(sockfd);

  return rc;
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
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[CURL] %c %s", dir, msg);
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

static void fillcURLProxy(CURL *curl) {
  if (getenv("HTTP_PROXY")) {
    char proxy[1024];
    
    if(getenv("HTTP_PROXY_PORT"))
      sprintf(proxy, "%s:%s", getenv("HTTP_PROXY"), getenv("HTTP_PROXY_PORT"));
    else
      sprintf(proxy, "%s", getenv("HTTP_PROXY"));

    curl_easy_setopt(curl, CURLOPT_PROXY, proxy);
    curl_easy_setopt(curl, CURLOPT_PROXYTYPE, CURLPROXY_HTTP);
  }
}

/* **************************************** */

bool Utils::postHTTPJsonData(char *username, char *password, char *url,
			     char *json, int timeout, HTTPTranferStats *stats) {
  CURL *curl;
  bool ret = false;

  curl = curl_easy_init();
  if(curl) {
    CURLcode res;
    struct curl_slist* headers = NULL;

    fillcURLProxy(curl);
    
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
    headers = curl_slist_append(headers, "Expect:"); // Disable 100-continue as it may cause issues (e.g. in InfluxDB)
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(json));
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_post_writefunc);

    if(timeout) {
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
      long http_code = 0;

      ntop->getTrace()->traceEvent(TRACE_INFO, "Posted JSON to %s", url);
      readCurlStats(curl, stats, NULL);

      curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
      // Success if http_code is 2xx, failure otherwise
      if(http_code >= 200 && http_code <= 299)
	ret = true;
      else
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Unexpected HTTP response code received %u", http_code);
    }

    /* always cleanup */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to initialize curl");

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

    fillcURLProxy(curl);
    
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
    headers = curl_slist_append(headers, "Expect:"); // Disable 100-continue as it may cause issues (e.g. in InfluxDB)
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(json));
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &fetcher);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_get_writefunc);

    if(timeout) {
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
  struct stat buf;
  size_t file_len;
  FILE *fd;

  if(stat(path, &buf) != 0)
    return(false);

  if((fd = fopen(path, "rb")) == NULL)
    return(false);
  else
    file_len = (size_t)buf.st_size;

  curl = curl_easy_init();

  if(curl) {
    CURLcode res;
    DownloadState *state = NULL;
    struct curl_slist* headers = NULL;

    fillcURLProxy(curl);
    
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
    headers = curl_slist_append(headers, "Expect:"); // Disable 100-continue as it may cause issues (e.g. in InfluxDB)
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

      state->vm = vm, state->header_over = 0, state->return_content = true;
    } else {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
      curl_easy_cleanup(curl);
      if(vm) lua_pushnil(vm);
      return(false);
    }

    if(vm) lua_newtable(vm);

    res = curl_easy_perform(curl);

    if(res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_INFO,
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

bool Utils::sendMail(lua_State* vm, char *from, char *to, char *cc, char *message,
		     char *smtp_server, char *username, char *password) {
  bool ret = true;
  const char *ret_str = "";

#ifdef HAVE_CURL_SMTP
  CURL *curl;
  CURLcode res;
  struct curl_slist *recipients = NULL;
  struct snmp_upload_status *upload_ctx = (struct snmp_upload_status*) calloc(1, sizeof(struct snmp_upload_status));

  if(!upload_ctx) {
    ret = false;
    goto out;
  }

  upload_ctx->lines = message;
  curl = curl_easy_init();

  if(curl) {
    fillcURLProxy(curl);
    
    if(username != NULL && password != NULL) {
      curl_easy_setopt(curl, CURLOPT_USERNAME, username);
      curl_easy_setopt(curl, CURLOPT_PASSWORD, password);
    }

    curl_easy_setopt(curl, CURLOPT_URL, smtp_server);

    if(strncmp(smtp_server, "smtps://", 8) == 0)
      curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_ALL);
    else if(strncmp(smtp_server, "smtp://", 7) == 0)
      curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_NONE);
    else /* Try using SSL */
      curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_TRY);

    curl_easy_setopt(curl, CURLOPT_MAIL_FROM, from);

    recipients = curl_slist_append(recipients, to);
    if(cc && cc[0])
      recipients = curl_slist_append(recipients, cc);
    curl_easy_setopt(curl, CURLOPT_MAIL_RCPT, recipients);

    curl_easy_setopt(curl, CURLOPT_READFUNCTION, curl_smtp_payload_source);
    curl_easy_setopt(curl, CURLOPT_READDATA, upload_ctx);
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1L);

    if(ntop->getTrace()->get_trace_level() >= TRACE_LEVEL_DEBUG) {
      /* Show verbose message trace */
      curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
      curl_easy_setopt(curl, CURLOPT_DEBUGFUNCTION, curl_debugfunc);
      curl_easy_setopt(curl, CURLOPT_DEBUGDATA, upload_ctx);
    }

    res = curl_easy_perform(curl);
    ret_str = curl_easy_strerror(res);

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

 out:
#else
  ret = false;
  ret_str = "SMTP support is not available";
#endif

  if(vm) {
    /*
    If a lua VM has been passed as parameter, return code and return message are pushed into the lua stack.
    */
    lua_newtable(vm);
    lua_push_bool_table_entry(vm, "success", ret);
    lua_push_str_table_entry(vm, "msg", ret_str);
  } else if(!ret)
    /*
      If not lua VM has been passed, in case of error, a message is logged to stdout
     */
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to send email to (%s): %s. Run ntopng with -v6 for more details.",
				 smtp_server, ret_str);
  return ret;
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

  if(state->return_content) {
    diff = sizeof(state->outbuf) - state->num_bytes - 1;

    if(diff > 0) {
      int buff_diff = min(diff, len);

      if(buff_diff > 0) {
	strncpy(&state->outbuf[state->num_bytes], buffer, buff_diff);
	state->num_bytes += buff_diff;
	state->outbuf[state->num_bytes] = '\0';
      }
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

  progressState->bytes.download = (u_int32_t)dlnow,  progressState->bytes.upload = (u_int32_t)ulnow;

  return Utils::progressCanContinue(progressState) ? 0 /* continue */ : 1 /* stop transfer */;
}

/* **************************************** */

/* form_data is in format param=value&param1=&value1... */
bool Utils::httpGetPost(lua_State* vm, char *url,
			/* NOTE if user_header_token != NULL, username AND password are ignored, and vice-versa */
			char *username, char *password, char *user_header_token,
			int timeout, bool return_content,
			bool use_cookie_authentication,
			HTTPTranferStats *stats, const char *form_data,
			char *write_fname, bool follow_redirects, int ip_version) {
  CURL *curl = curl_easy_init();
  FILE *out_f = NULL;
  bool ret = true;
  char tokenBuffer[64];
  bool used_tokenBuffer = false;

  if(curl) {
    DownloadState *state = NULL;
    ProgressState progressState;
    CURLcode curlcode;
    struct curl_slist *headers = NULL;
    long response_code;
    char *content_type, *redirection;
    char ua[64];

    fillcURLProxy(curl);
    
    memset(stats, 0, sizeof(HTTPTranferStats));
    curl_easy_setopt(curl, CURLOPT_URL, url);

    if(user_header_token != NULL) {
      snprintf(tokenBuffer, sizeof(tokenBuffer), "Authorization: Token %s", user_header_token);
    } else {
      tokenBuffer[0] = '\0';

      if(username || password) {
	char auth[64];

	if(use_cookie_authentication) {
	  snprintf(auth, sizeof(auth),
		   "user=%s; password=%s",
		   username ? username : "",
		   password ? password : "");
	  curl_easy_setopt(curl, CURLOPT_COOKIE, auth);
	} else {
	  if(username && (username[0] != '\0')) {
	    snprintf(auth, sizeof(auth), "%s:%s",
		     username ? username : "",
		     password ? password : "");
	    curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
	    curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
	  }
	}
      }
    }

    if(!strncmp(url, "https", 5)) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);

#ifdef CURLOPT_SSL_ENABLE_ALPN
      curl_easy_setopt(curl, CURLOPT_SSL_ENABLE_ALPN, 1L); /* Enable ALPN */
#endif

#ifdef CURLOPT_SSL_ENABLE_NPN
      curl_easy_setopt(curl, CURLOPT_SSL_ENABLE_NPN, 1L);  /* Negotiate HTTP/2 if available */
#endif
    }

    if(form_data) {
      /* This is a POST request */
      curl_easy_setopt(curl, CURLOPT_POST, 1L);
      curl_easy_setopt(curl, CURLOPT_POSTFIELDS, form_data);
      curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(form_data));

      if(form_data[0] == '{' /* JSON */) {

	headers = curl_slist_append(headers, "Content-Type: application/json");

	if(tokenBuffer[0] != '\0') {
	  headers = curl_slist_append(headers, tokenBuffer);
	  used_tokenBuffer = true;
	}
      }
    }

    if((tokenBuffer[0] != '\0') && (!used_tokenBuffer)) {
      snprintf(tokenBuffer, sizeof(tokenBuffer), "Authorization: Token %s", user_header_token);
      headers = curl_slist_append(headers, tokenBuffer);
      used_tokenBuffer = true;
    }

    if (headers != NULL)
      curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    if(write_fname) {
      ntop->fixPath(write_fname);
      out_f = fopen(write_fname, "wb");

      if(out_f == NULL) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Could not open %s for write", write_fname, strerror(errno));
        curl_easy_cleanup(curl);
        if(vm) lua_pushnil(vm);
        return(false);
      }

      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_file);
      curl_easy_setopt(curl, CURLOPT_WRITEDATA, out_f);
    } else {
      state = (DownloadState*)malloc(sizeof(DownloadState));
      if(state != NULL) {
	memset(state, 0, sizeof(DownloadState));

	curl_easy_setopt(curl, CURLOPT_WRITEDATA, state);
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_lua);
	curl_easy_setopt(curl, CURLOPT_HEADERDATA, state);
	curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curl_hdf);

	state->vm = vm, state->header_over = 0, state->return_content = return_content;
      } else {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
	curl_easy_cleanup(curl);
	if(vm) lua_pushnil(vm);
	return(false);
      }
    }

    if(follow_redirects) {
      curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
      curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5);
    }

    if(ip_version == 4)
      curl_easy_setopt(curl, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
    else if(ip_version == 6)
      curl_easy_setopt(curl, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V6);

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

    if(ntop->getTrace()->get_trace_level() > TRACE_LEVEL_NORMAL)
      curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);

    snprintf(ua, sizeof(ua), "%s/%s/%s", PACKAGE_STRING, PACKAGE_MACHINE, PACKAGE_OS);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, ua);
    // curl_easy_setopt(curl, CURLOPT_USERAGENT, "libcurl/7.54.0");

    if(vm) lua_newtable(vm);

    if((curlcode = curl_easy_perform(curl)) == CURLE_OK) {
      readCurlStats(curl, stats, vm);

      if(return_content && vm) {
	lua_push_str_table_entry(vm, "CONTENT", state->outbuf);
	lua_push_uint64_table_entry(vm, "CONTENT_LEN", state->num_bytes);
      }

      if(vm) {
	char *ip = NULL;

	if(!curl_easy_getinfo(curl, CURLINFO_PRIMARY_IP, &ip) && ip)
	  lua_push_str_table_entry(vm, "RESOLVED_IP", ip);
      }

      ret = true;
    } else {
      if(vm)
        lua_push_str_table_entry(vm, "ERROR", curl_easy_strerror(curlcode));
      ret = false;
    }

    if(vm) {
      if(curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) == CURLE_OK)
	lua_push_uint64_table_entry(vm, "RESPONSE_CODE", response_code);

      if((curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &content_type) == CURLE_OK) && content_type)
	lua_push_str_table_entry(vm, "CONTENT_TYPE", content_type);

      if(curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &redirection) == CURLE_OK)
	lua_push_str_table_entry(vm, "EFFECTIVE_URL", redirection);

      if(!form_data) {
	lua_push_uint64_table_entry(vm, "BYTES_DOWNLOAD", progressState.bytes.download);
	lua_push_uint64_table_entry(vm, "BYTES_UPLOAD", progressState.bytes.upload);
      }

      if(!ret)
	lua_push_bool_table_entry(vm, "IS_PARTIAL", true);
    }

    if(state)
      free(state);

    /* always cleanup */
    if (headers != NULL)
      curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  if(out_f)
    fclose(out_f);

  return(ret);
}

/* **************************************** */

long Utils::httpGet(const char * const url,
		    /* NOTE if user_header_token != NULL, username AND password are ignored, and vice-versa */
		    const char * const username, const char * const password, const char * const user_header_token,
		    int timeout, char * const resp, const u_int resp_len) {
  CURL *curl = curl_easy_init();
  long response_code = 0;
  char tokenBuffer[64];

  if(curl) {
    struct curl_slist *headers = NULL;
    char *content_type;
    char ua[64];
    curl_fetcher_t fetcher = {
			      /* .payload =  */ resp,
			      /* .cur_size = */ 0,
			      /* .max_size = */ resp_len};

    fillcURLProxy(curl);
    
    curl_easy_setopt(curl, CURLOPT_URL, url);

    if(user_header_token == NULL) {
      if(username || password) {
	char auth[64];

	snprintf(auth, sizeof(auth), "%s:%s",
		 username ? username : "",
		 password ? password : "");
	curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
	curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
      }
    } else {
      snprintf(tokenBuffer, sizeof(tokenBuffer), "Authorization: Token %s", user_header_token);
      headers = curl_slist_append(headers, tokenBuffer);
    }

    if (headers != NULL)
      curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

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
    if (headers != NULL)
      curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  return response_code;
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

ticks Utils::gettickspersec() {
#if !(defined(__arm__) || defined(__mips__))
  ticks tick_start, tick_delta, ret;

  /* computing usleep delay */
  tick_start = Utils::getticks();
  _usleep(1000);
  tick_delta = (Utils::getticks() - tick_start) / 1000;

  /* computing CPU freq */
  tick_start = Utils::getticks();
  _usleep(1001);

  ret = (Utils::getticks() - tick_start - tick_delta) * 1000; /*kHz -> Hz*/
  if(ret == 0) ret = 1; /* Avoid invalid values */

  return(ret);
#else
  return CLOCKS_PER_SEC;
#endif
}

/* **************************************** */

static bool scan_dir(const char * dir_name,
		     list<pair<struct dirent *, char * > > *dirlist,
		     unsigned long *total) {
  int path_length;
  char path[MAX_PATH+2];
  DIR *d;
  struct stat buf;

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
  struct stat sa, sb;

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
  struct stat st;

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

#if defined(__linux__) || defined(__FreeBSD__) || defined(__APPLE__)

void Utils::readMac(char *_ifname, dump_mac_t mac_addr) {
  char ifname[32];
  macstr_t mac_addr_buf;
  int res;

  ifname2devname(_ifname, ifname, sizeof(ifname));

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

bool Utils::readIPv6(char *ifname, struct in6_addr *sin) {
  bool rc = false;
#ifdef __linux__
  FILE *f;
  int scope, prefix;
  unsigned char ipv6[16];
  char dname[IFNAMSIZ];

  f = fopen("/proc/net/if_inet6", "r");
  if (f == NULL)
    return(false);  

  while (19 == fscanf(f,
		      " %2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx %*x %x %x %*x %s",
		      &ipv6[0],
		      &ipv6[1],
		      &ipv6[2],
		      &ipv6[3],
		      &ipv6[4],
		      &ipv6[5],
		      &ipv6[6],
		      &ipv6[7],
		      &ipv6[8],
		      &ipv6[9],
		      &ipv6[10],
		      &ipv6[11],
		      &ipv6[12],
		      &ipv6[13],
		      &ipv6[14],
		      &ipv6[15],
		      &prefix,
		      &scope,
		      dname)) {

    if (strcmp(ifname, dname) != 0)
      continue;    
    
    if(scope == 0x0000U /* IPV6_ADDR_GLOBAL */) {
      memcpy(sin, ipv6, sizeof(ipv6));
      rc = true;
      break;
    }
  }
  
  fclose(f);
#endif

  return rc;
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

u_int32_t Utils::getMaxIfSpeed(const char *_ifname) {
#if defined(__linux__) && (!defined(__GNUC_RH_RELEASE__) || (__GNUC_RH_RELEASE__ != 44))
  int sock, rc;
  struct ifreq ifr;
  struct ethtool_cmd edata;
  u_int32_t ifSpeed = 1000;
  char ifname[32];

  if(strchr(_ifname, ',')) {
    /* These are interfaces with , (e.g. eth0,eth1) */
    char ifaces[128], *iface, *tmp;
    u_int32_t speed = 0;

    snprintf(ifaces, sizeof(ifaces), "%s", _ifname);
    iface = strtok_r(ifaces, ",", &tmp);

    while(iface) {
      u_int32_t thisSpeed;

      ifname2devname(iface, ifname, sizeof(ifname));

      thisSpeed = getMaxIfSpeed(ifname);
      if(thisSpeed > speed) speed = thisSpeed;

      iface = strtok_r(NULL, ",", &tmp);
    }

    return(speed);
  } else {
    ifname2devname(_ifname, ifname, sizeof(ifname));
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
  closesocket(sock);

  if(rc < 0) {
    // ntop->getTrace()->traceEvent(TRACE_ERROR, "I/O Control error [%s]", ifname);
    return(ifSpeed);
  }

  if((int32_t)ethtool_cmd_speed(&edata) != SPEED_UNKNOWN)
    ifSpeed = ethtool_cmd_speed(&edata);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Interface %s has MAC Speed = %u",
			       ifname, edata.speed);

  return(ifSpeed);
#else
  return(1000);
#endif
}

/* **************************************** */

int Utils::ethtoolGet(const char *ifname, int cmd, uint32_t *v) {
#if defined(__linux__)
  struct ifreq ifr;
  struct ethtool_value ethv;
  int fd;

  memset(&ifr, 0, sizeof(ifr));

  fd = socket(AF_INET, SOCK_DGRAM, 0);

  if(fd == -1)
    return -1;

  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));

  ethv.cmd = cmd;
  ifr.ifr_data = (char *) &ethv;

  if(ioctl(fd, SIOCETHTOOL, (char *) &ifr) < 0) {
    close(fd);
    return -1;
  }

  *v = ethv.data;
  close(fd);

  return 0;
#else
  return -1;
#endif
}

/* **************************************** */

int Utils::ethtoolSet(const char *ifname, int cmd, uint32_t v) {
#if defined(__linux__)
  struct ifreq ifr;
  struct ethtool_value ethv;
  int fd;

  memset(&ifr, 0, sizeof(ifr));

  fd = socket(AF_INET, SOCK_DGRAM, 0);

  if(fd == -1)
    return -1;

  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));

  ethv.cmd = cmd;
  ethv.data = v;
  ifr.ifr_data = (char *) &ethv;

  if(ioctl(fd, SIOCETHTOOL, (char *) &ifr) < 0) {
    close(fd);
    return -1;
  }

  close(fd);

  return 0;
#else
  return -1;
#endif
}

/* **************************************** */

int Utils::disableOffloads(const char *ifname) {
#if defined(__linux__)
  uint32_t v = 0;

#ifdef ETHTOOL_GGRO
  if(Utils::ethtoolGet(ifname, ETHTOOL_GGRO, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_SGRO, 0);
#endif

#ifdef ETHTOOL_GGSO
  if(Utils::ethtoolGet(ifname, ETHTOOL_GGSO, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_SGSO, 0);
#endif

#ifdef ETHTOOL_GTSO
  if(Utils::ethtoolGet(ifname, ETHTOOL_GTSO, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_STSO, 0);
#endif

#ifdef ETHTOOL_GSG
  if(Utils::ethtoolGet(ifname, ETHTOOL_GSG, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_SSG, 0);
#endif

#ifdef ETHTOOL_GFLAGS
  if(Utils::ethtoolGet(ifname, ETHTOOL_GFLAGS, &v) == 0 && (v & ETH_FLAG_LRO))
    Utils::ethtoolSet(ifname, ETHTOOL_SFLAGS, v & ~ETH_FLAG_LRO);
#endif

  return 0;
#else
  return -1;
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
  char *cp;
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
    if(n > 1)
      *--cp = '.';
    addr >>= 8;
  } while (--n > 0);

  return(cp);
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

u_int32_t Utils::macHash(const u_int8_t * const mac) {
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

bool Utils::isEmptyMac(u_int8_t *mac) {
  u_int8_t zero[6] = { 0, 0, 0, 0, 0, 0 };

  return (memcmp(mac, zero, 6) == 0);
}

/* ****************************************************** */

/* https://en.wikipedia.org/wiki/Multicast_address */
/* https://hwaddress.com/company/private */
bool Utils::isSpecialMac(u_int8_t *mac) {
  if(isEmptyMac(mac))
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

bool Utils::isBroadcastMac(u_int8_t *mac) {
  u_int8_t broad[6] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

  return(memcmp(mac, broad, 6) == 0);

}

/* ****************************************************** */

void Utils::parseMac(u_int8_t *mac, const char *symMac) {
  int _mac[6] = { 0 };

  if(symMac)
    sscanf(symMac, "%x:%x:%x:%x:%x:%x",
	   &_mac[0], &_mac[1], &_mac[2],
	   &_mac[3], &_mac[4], &_mac[5]);
  
  for(int i = 0; i < 6; i++) mac[i] = (u_int8_t)_mac[i];
}

/* *********************************************** */

ndpi_patricia_node_t* Utils::add_to_ptree(ndpi_patricia_tree_t *tree, int family, void *addr, int bits) {
  ndpi_prefix_t prefix;
  ndpi_patricia_node_t *node;
  u_int16_t maxbits = ndpi_patricia_get_maxbits(tree);

  if(family == AF_INET)
    ndpi_fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, maxbits);
  else if(family == AF_INET6)
    ndpi_fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, maxbits);
  else
    ndpi_fill_prefix_mac(&prefix, (u_int8_t*)addr, bits, maxbits);

  node = ndpi_patricia_lookup(tree, &prefix);

  return(node);
}

/* ******************************************* */

ndpi_patricia_node_t* Utils::ptree_match(ndpi_patricia_tree_t *tree, int family, const void * const addr, int bits) {
  ndpi_prefix_t prefix;
  u_int16_t maxbits = ndpi_patricia_get_maxbits(tree);

  if(addr == NULL) return(NULL);

  if(family == AF_INET)
    ndpi_fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, maxbits);
  else if(family == AF_INET6)
    ndpi_fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, maxbits);
  else
    ndpi_fill_prefix_mac(&prefix, (u_int8_t*)addr, bits, maxbits);

  if(prefix.bitlen > maxbits) { /* safety check */
    char buf[128];
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Bad radix tree lookup for %s "
      "(prefix family = %u, len = %u (%u), tree max len = %u)",
      Utils::ptree_prefix_print(&prefix, buf, sizeof(buf)) ? buf : "-",
      family, prefix.bitlen, bits, maxbits);
    return NULL;
  }

  return(ndpi_patricia_search_best(tree, &prefix));
}

/* ******************************************* */

ndpi_patricia_node_t* Utils::ptree_add_rule(ndpi_patricia_tree_t *ptree, const char * const addr_line) {
  char *ip, *bits, *slash = NULL, *line = NULL;
  struct in_addr addr4;
  struct in6_addr addr6;
  u_int8_t mac[6];
  u_int32_t _mac[6];
  ndpi_patricia_node_t *node = NULL;

  line = strdup(addr_line);
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

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Added IPv%d rule %s/%s [%p]", isV4 ? 4 : 6, ip, bits, node);

  if(line) free(line);
  return(node);
}

/* ******************************************* */

bool Utils::ptree_prefix_print(ndpi_prefix_t *prefix, char *buffer, size_t bufsize) {
  char *a, ipbuf[64];

  switch(prefix->family) {
  case AF_INET:
    a = Utils::intoaV4(ntohl(prefix->add.sin.s_addr), ipbuf, sizeof(ipbuf));
    snprintf(buffer, bufsize, "%s/%d", a, prefix->bitlen);
    return(true);

  case AF_INET6:
    a = Utils::intoaV6(*((struct ndpi_in6_addr*)&prefix->add.sin6), prefix->bitlen, ipbuf, sizeof(ipbuf));
    snprintf(buffer, bufsize, "%s/%d", a, prefix->bitlen);
    return(true);
  }

  return(false);
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
    (*r) = new (std::nothrow) Redis(redis_host, redis_password, redis_port, _redis_db_id, giveup_on_failure);
  }
}

/* ******************************************* */

int Utils::tcpStateStr2State(const char * const state_str) {
  map<string, int>::const_iterator it;

  if((it = tcp_state_str_2_state.find(state_str)) != tcp_state_str_2_state.end())
    return it->second;

  return 0;
}

/* ******************************************* */

const char * Utils::tcpState2StateStr(int state) {
  map<int, string>::const_iterator it;

  if((it = tcp_state_2_state_str.find(state)) != tcp_state_2_state_str.end())
    return it->second.c_str();

  return "UNKNOWN";
}

/* ******************************************* */

eBPFEventType Utils::eBPFEventStr2Event(const char * const event_str) {
  map<string, eBPFEventType>::const_iterator it;

  if((it = ebpf_event_str_2_event.find(event_str)) != ebpf_event_str_2_event.end())
    return it->second;

  return ebpf_event_type_unknown;
}

/* ******************************************* */

const char * Utils::eBPFEvent2EventStr(eBPFEventType event) {
  map<eBPFEventType, string>::const_iterator it;

  if((it = ebpf_event_2_event_str.find(event)) != ebpf_event_2_event_str.end())
    return it->second.c_str();


  return "UNKNOWN";
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

bool Utils::isInterfaceUp(char *_ifname) {
#ifdef WIN32
  return(true);
#else
  char ifname[32];
  struct ifreq ifr;
  int sock;

  sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);

  if(sock == -1)
    return(false);

  ifname2devname(_ifname, ifname, sizeof(ifname));

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, IFNAMSIZ-1);

  if(ioctl(sock, SIOCGIFFLAGS, &ifr) < 0) {
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

bool Utils::getCPULoad(cpu_load_stats *out) {
#if !defined(__FreeBSD__) && !defined(__NetBSD__) & !defined(__OpenBSD__) && !defined(__APPLE__) && !defined(WIN32)
  float load;
  FILE *fp;

  if((fp = fopen("/proc/loadavg", "r"))) {
    if(fscanf(fp, "%f", &load) != 1)
      load = 0;
    fclose(fp);

    out->load = load;

    return(true);
  }
#endif

  return(false);
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
  ntop_if_t *devpointer, *cur;

  snprintf(buf, buf_len, "%s", ifname);

  if(!Utils::ntop_findalldevs(&devpointer)) {
    for(cur = devpointer; cur; cur = cur->next) {
      if(strcmp(cur->name, ifname) == 0) {
	if(cur->description && cur->description[0])
	  snprintf(buf, buf_len, "%s", cur->description);
	break;
      }
    }

    Utils::ntop_freealldevs(devpointer);
  }

  return(buf);
}

/* ****************************************************** */

int Utils::bindSockToDevice(int sock, int family, const char* devicename) {
#ifdef WIN32
  return(0);
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
#if !defined(__APPLE__) && !defined(__FreeBSD__)
  rc = -1;
  ntop->getTrace()->traceEvent(TRACE_WARNING, "ntopng has not been compiled with libcap-dev");
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Network discovery and other privileged activities will fail");
#endif
#endif

  return(rc);
}

/* ****************************************************** */

#if !defined(__APPLE__) || !defined(__FreeBSD__)
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
#if !defined(__APPLE__) && !defined(__FreeBSD__)
  if(ntop && !ntop->hasDroppedPrivileges())
    return(0);

  return(_setWriteCapabilities(true));
#else
  return(0);
#endif
}

/* ****************************************************** */

int Utils::dropWriteCapabilities() {
#if !defined(__APPLE__) && !defined(__FreeBSD__)
  if(ntop && !ntop->hasDroppedPrivileges())
    return(0);

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
  /* Align result to rounder. Operations intrinsically work in UTC. */
  u_int32_t result = now - (now % rounder);
  result += rounder;

  /* Aling now to localtime using the local offset from UTC.
     So for example UTC+1, which has a +3600 offset from UTC, will have the local time
     one hour behind, that is, 10PM UTC are 9PM UTC+1.
     For an UTC-1, which has a -3600 offset from UTC, the local time is one hour ahead, that is,
     10PM UTC are 11PM UTC-1.
     Hence, in practice, a negative offset needs to be added whereas a positive offset needs to be
     substracted. */
  result += -offset_from_utc;

  /* Don't allow results which are earlier than now. Adjust using rounder until now is reached.
     This can happen when result has been adjusted with a positive offset from UTC. */
  while(result <= now)
    result += rounder;

  return result;
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
  h->snaplen  = ntop->getGlobals()->getSnaplen(iface->get_name());
  h->linktype = iface->isPacketInterface() ? iface->get_datalink() : DLT_EN10MB;
}

/* ****************************************************** */

void Utils::listInterfaces(lua_State* vm) {
  ntop_if_t *devpointer, *cur;

  if(Utils::ntop_findalldevs(&devpointer)) {
    ;
  } else {
    for(cur = devpointer; cur; cur = cur->next) {
      lua_newtable(vm);

      if(cur->name) {
        struct sockaddr_in sin;
        struct sockaddr_in6 sin6;
	char buf[64];

        sin.sin_family = AF_INET;
	sin.sin_addr.s_addr = Utils::readIPv4(cur->name);

        if(sin.sin_addr.s_addr != 0)
          lua_push_str_table_entry(vm, "ipv4", Utils::intoaV4(ntohl(sin.sin_addr.s_addr), buf, sizeof(buf)));

        sin6.sin6_family = AF_INET6;
        if(Utils::readIPv6(cur->name, &sin6.sin6_addr)) {
	  struct ndpi_in6_addr* ip6 = (struct ndpi_in6_addr*)&sin6.sin6_addr;
	  char* ip = Utils::intoaV6(*ip6, 128, buf, sizeof(buf));

	  lua_push_str_table_entry(vm, "ipv6", ip);
        }
      }

      lua_pushstring(vm, cur->name);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }

    Utils::ntop_freealldevs(devpointer);
  }
}

/* ****************************************************** */

char *Utils::ntop_lookupdev(char *ifname_out, int ifname_size) {
  char ebuf[PCAP_ERRBUF_SIZE];
  pcap_if_t *pdevs, *pdev;
  bool found = false;

  ifname_out[0] = '\0';

  if(pcap_findalldevs(&pdevs, ebuf) != 0)
    goto err;

  pdev = pdevs;
  while (pdev != NULL) {
    if(Utils::validInterface(pdev) &&
       Utils::isInterfaceUp(pdev->name)) {
      snprintf(ifname_out, ifname_size, "%s", pdev->name);
      found = true;
      break;
    }
    pdev = pdev->next;
  }

  pcap_freealldevs(pdevs);

 err:
  return found ? ifname_out : NULL;
}


/* ****************************************************** */

int Utils::ntop_findalldevs(ntop_if_t **alldevsp) {
  char ebuf[PCAP_ERRBUF_SIZE];
  pcap_if_t *pdevs, *pdev;
#ifdef HAVE_PF_RING
  pfring_if_t *pfdevs, *pfdev;
#endif
  ntop_if_t *tail = NULL;
  ntop_if_t *cur;

  if(!alldevsp)
    return -1;

  *alldevsp = NULL;

  if(pcap_findalldevs(&pdevs, ebuf) != 0)
    return -1;

#ifdef HAVE_PF_RING
  pfdevs = pfring_findalldevs();

  pfdev = pfdevs;
  while (pfdev != NULL) {

    /* merge with info from pcap */
    pdev = pdevs;
    while (pdev != NULL) {
      if(pfdev->system_name && strcmp(pfdev->system_name, pdev->name) == 0)
        break;
      pdev = pdev->next;
    }

    if(pdev == NULL /* not a standard interface (e.g. fpga) */
        || (Utils::isInterfaceUp(pfdev->system_name) && Utils::validInterface(pdev))) {
      cur = (ntop_if_t*)calloc(1, sizeof(ntop_if_t));

      if(cur) {
	cur->name = strdup(pfdev->system_name ? pfdev->system_name : pfdev->name);
	cur->description = strdup((pdev && pdev->description) ? pdev->description : "");
	cur->module = strdup(pfdev->module);
	cur->license = pfdev->license;

	if(!*alldevsp) *alldevsp = cur;
	if(tail) tail->next = cur;
	tail = cur;
      }
    }

    pfdev = pfdev->next;
  }
#endif

  pdev = pdevs;
  while (pdev != NULL) {
    if(Utils::validInterface(pdev) &&
        Utils::isInterfaceUp(pdev->name)) {

#ifdef HAVE_PF_RING
      /* check if already listed */
      pfdev = pfdevs;
      while (pfdev != NULL) {
        if(strcmp(pfdev->system_name, pdev->name) == 0)
          break;
        pfdev = pfdev->next;
      }

      if(pfdev == NULL) {
#endif
	cur = (ntop_if_t*)calloc(1, sizeof(ntop_if_t));

	if(cur) {
	  cur->name = strdup(pdev->name);
	  cur->description = strdup(pdev->description ? pdev->description : "");

	  if(!*alldevsp) *alldevsp = cur;
	  if(tail) tail->next = cur;
	  tail = cur;
	}
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

  return 0;
}

/* ****************************************************** */

void Utils::ntop_freealldevs(ntop_if_t *alldevsp) {
  ntop_if_t *cur;

  while(alldevsp) {
    cur = alldevsp;
    alldevsp = alldevsp->next;

    if(cur->name) free(cur->name);
    if(cur->description) free(cur->description);
    if(cur->module) free(cur->module);

    free(cur);
  }
}

/* ****************************************************** */

bool Utils::validInterfaceName(const char *name) {
#if not defined(WIN32)
  if(!name
     || !strncmp(name, "virbr", 5) /* Ignore virtual interfaces */
     )
    return false;

  /*
     Make strict checks when validating interface names. This is fundamental
     To prevent injections in syscalls such as system() or popen(). Indeed,
     interface names can be fancy and contain special characters, e.g,.

     $ ip link add link eno1 name "\";whoami>b;\"" type vlan id 8
     $ nmcli con add type vlan ifname ";whoami>b;" dev enp1s0 id 10

     Hence, a valid interface name must have strict requirements.
  */
  for(int i = 0; name[i] != '\0'; i++) {
    if(!isalnum(name[i])
       && name[i] != '@'
       && name[i] != '-'
       && name[i] != ':'
       && name[i] != '_')
      return false;
  }
#endif

  return true;
}

/* ****************************************************** */

bool Utils::validInterfaceDescription(const char *description) {
  if(description &&
     (strstr(description, "PPP")            /* Avoid to use the PPP interface              */
      || strstr(description, "dialup")      /* Avoid to use the dialup interface           */
      || strstr(description, "ICSHARE")     /* Avoid to use the internet sharing interface */
      || strstr(description, "NdisWan"))) { /* Avoid to use the internet sharing interface */
    return false;
  }

  return true;
}

/* ****************************************************** */

bool Utils::validInterface(const ntop_if_t *ntop_if) {
  return Utils::validInterfaceName(ntop_if->name) && Utils::validInterfaceDescription(ntop_if->description);
}

/* ****************************************************** */

bool Utils::validInterface(const pcap_if_t *pcap_if) {
  return Utils::validInterfaceName(pcap_if->name) && Utils::validInterfaceDescription(pcap_if->description);
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
    if(ret < 0)
      return false;
    sent += ret;
    if(sent == len) return true;
    _usleep(100);
  }

  return false;
}

/* ****************************************************** */

bool Utils::parseAuthenticatorJson(HTTPAuthenticator *auth, char *content) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;

  o = json_tokener_parse_verbose(content, &jerr);
  if(o) {
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

/* ****************************************************** */

void Utils::freeAuthenticator(HTTPAuthenticator *auth) {
  if(auth == NULL)
    return;
  if(auth->allowedIfname) free(auth->allowedIfname);
  if(auth->allowedNets) free(auth->allowedNets);
  if(auth->language) free(auth->language);
}

/* ****************************************************** */

DetailsLevel Utils::bool2DetailsLevel(bool max, bool higher, bool normal){
  if(max){
    return details_max;
  } else if(higher){
    return details_higher;
  } else if(normal){
    return details_normal;
  }
  else{
    return details_high;
  }
}

/* ****************************************************** */

void Utils::containerInfoLua(lua_State *vm, const ContainerInfo * const cont) {
  lua_newtable(vm);

  if(cont->id)       lua_push_str_table_entry(vm, "id", cont->id);
  if(cont->data_type == container_info_data_type_k8s) {
    if(cont->name) lua_push_str_table_entry(vm, "k8s.name", cont->name);
    if(cont->data.k8s.pod)  lua_push_str_table_entry(vm, "k8s.pod", cont->data.k8s.pod);
    if(cont->data.k8s.ns)   lua_push_str_table_entry(vm, "k8s.ns", cont->data.k8s.ns);
  } else if(cont->data_type == container_info_data_type_docker) {
    if(cont->name) lua_push_str_table_entry(vm, "docker.name", cont->name);
  }
}

/* ****************************************************** */

const char* Utils::periodicityToScriptName(ScriptPeriodicity p) {
  switch(p) {
  case aperiodic_script:    return("aperiodic");
  case minute_script:       return("min");
  case five_minute_script:  return("5mins");
  case hour_script:         return("hour");
  case day_script:          return("day");
  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown periodicity value: %d", p);
    return("");
  }
}

/* ****************************************************** */

int Utils::periodicityToSeconds(ScriptPeriodicity p) {
  switch(p) {
  case aperiodic_script:    return(0);
  case minute_script:       return(60);
  case five_minute_script:  return(300);
  case hour_script:         return(3600);
  case day_script:          return(86400);
  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown periodicity value: %d", p);
    return(0);
  }
}

/* ****************************************************** */

/* TODO move into nDPI */
OSType Utils::getOSFromFingerprint(const char *fingerprint, const char*manuf, DeviceType devtype) {
  /*
    Inefficient with many signatures but ok for the
    time being that we have little data
  */
  if(!fingerprint)
    return(os_unknown);

  if(!strcmp(fingerprint,      "017903060F77FC"))
    return(os_ios);
  else if((!strcmp(fingerprint, "017903060F77FC5F2C2E"))
	  || (!strcmp(fingerprint, "0103060F775FFC2C2E2F"))
	  || (!strcmp(fingerprint, "0103060F775FFC2C2E"))
	  )
    return(os_macos);
  else if((!strcmp(fingerprint, "0103060F1F212B2C2E2F79F9FC"))
	  || (!strcmp(fingerprint, "010F03062C2E2F1F2179F92B"))
	  )
    return(os_windows);
  else if((!strcmp(fingerprint, "0103060C0F1C2A"))
	  || (!strcmp(fingerprint, "011C02030F06770C2C2F1A792A79F921FC2A"))
	  )
    return(os_linux); /* Android is also linux */
  else if((!strcmp(fingerprint, "0603010F0C2C51452B1242439607"))
	  || (!strcmp(fingerprint, "01032C06070C0F16363A3B45122B7751999A"))
	  )
    return(os_laserjet);
  else if(!strcmp(fingerprint, "0102030F060C2C"))
    return(os_apple_airport);
  else if(!strcmp(fingerprint, "01792103060F1C333A3B77"))
    return(os_android);

  /* Below you can find ambiguous signatures */
  if(manuf) {
    if(!strcmp(fingerprint, "0103063633")) {
      if(strstr(manuf, "Apple"))
        return(os_macos);
      else if(devtype == device_unknown)
        return(os_windows);
    }
  }

  return(os_unknown);
}
/*
  Missing OS mapping

  011C02030F06770C2C2F1A792A
  010F03062C2E2F1F2179F92BFC
*/

/* ****************************************************** */

/* TODO move into nDPI? */
DeviceType Utils::getDeviceTypeFromOsDetail(const char *os) {
  if(strcasestr(os, "iPhone")
      || strcasestr(os, "Android")
      || strcasestr(os, "mobile"))
    return(device_phone);
  else if(strcasestr(os, "Mac OS")
      || strcasestr(os, "Windows")
      || strcasestr(os, "Linux"))
    return(device_workstation);
  else if(strcasestr(os, "iPad") || strcasestr(os, "tablet"))
    return(device_tablet);

  return(device_unknown);
}

/* Bitmap functions */
bool Utils::bitmapIsSet(u_int64_t bitmap, u_int8_t v) {
  if(v > 64) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "INTERNAL ERROR: bitmapIsSet out of range (%u > %u)",
				 v, sizeof(bitmap));
    return(false);
  }

  return(((bitmap >> v) & 1) ? true : false);
}

u_int64_t Utils::bitmapSet(u_int64_t bitmap, u_int8_t v) {
  if(v > 64)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "INTERNAL ERROR: bitmapSet out of range (%u > %u)",
				 v, sizeof(bitmap));
  else
    bitmap |= ((u_int64_t)1) << v;

  return(bitmap);
}

u_int64_t Utils::bitmapClear(u_int64_t bitmap, u_int8_t v) {
  if(v > 64)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "INTERNAL ERROR: bitmapClear out of range (%u > %u)",
				 v, sizeof(bitmap));
  else
    bitmap &= ~(((u_int64_t)1) << v);

  return(bitmap);
}

/* ****************************************************** */

json_object *Utils::cloneJSONSimple(json_object *src) {
  struct json_object_iterator obj_it = json_object_iter_begin(src);
  struct json_object_iterator obj_itEnd = json_object_iter_end(src);
  json_object *obj = json_object_new_object();

  if(obj == NULL)
    return NULL;

  while(!json_object_iter_equal(&obj_it, &obj_itEnd)) {
    const char *key   = json_object_iter_peek_name(&obj_it);
    json_object *v    = json_object_iter_peek_value(&obj_it);
    enum json_type type = json_object_get_type(v);

    if(key != NULL && v != NULL)
    switch(type) {
    case json_type_int:
      json_object_object_add(obj, key, json_object_new_int64(json_object_get_int64(v)));
      break;
    case json_type_double:
      json_object_object_add(obj, key, json_object_new_double(json_object_get_double(v)));
      break;
    case json_type_string:
      json_object_object_add(obj, key, json_object_new_string(json_object_get_string(v)));
      break;
    case json_type_boolean:
      json_object_object_add(obj, key, json_object_new_boolean(json_object_get_boolean(v)));
      break;
    case json_type_object: /* not supported */
    default:
      break;
    }

    json_object_iter_next(&obj_it);
  }

  return obj;
}

/* ****************************************************** */

/**
 * Computes the next power of 2.
 * @param v The number to round up.
 * @return The next power of 2.
 */
u_int32_t Utils::pow2(u_int32_t v) {
  v--;
  v |= v >> 1;
  v |= v >> 2;
  v |= v >> 4;
  v |= v >> 8;
  v |= v >> 16;
  v++;
  return v;
}

/* ****************************************************** */

int Utils::exec(const char * const command) {
  int rc = 0;

#if defined(__linux__) || defined(__FreeBSD__) || defined(__APPLE__)
  if(!command || command[0] == '\0')
    return 0;

  fflush(stdout);

  rc = system(command);

  /*
  if (rc == -1)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Failed command %s: %d/%s",
				 command_buf, errno, strerror(errno));
  */
#endif

  return rc;
}

/* ****************************************************** */

#ifdef __linux__
void Utils::deferredExec(const char * const command) {
  char command_buf[256];
  int res;

  if(!command || command[0] == '\0')
    return;

  /* Self-restarting service does not restart with systemd:
     This is a hard limitation imposed by systemd.
     The best suggestions so far are to use at, cron, or systemd timer units.

     https://unix.stackexchange.com/questions/202048/self-restarting-service-does-not-restart-with-systemd
   */
  if((res = snprintf(command_buf, sizeof(command_buf),
		     "echo \"sleep 1 && %s\" | at now",
		     command)) < 0
     || res >= (int)sizeof(command_buf))
    return;

  printf("%s\n", command_buf);
  fflush(stdout);

  if(system(command_buf) == -1)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Failed command %s: %d/%s",
				 command_buf, errno, strerror(errno));
}
#endif

/* ****************************************************** */

void Utils::tlv2lua(lua_State *vm, ndpi_serializer *serializer) {
  ndpi_deserializer deserializer;
  ndpi_serialization_type kt, et;
  int rc;

  rc = ndpi_init_deserializer(&deserializer, serializer);

  if(rc == -1)
    return;

  while((et = ndpi_deserialize_get_item_type(&deserializer, &kt)) != ndpi_serialization_unknown) {
    char key[64];
    u_int32_t k32;
    ndpi_string ks, vs;
    u_int32_t v32;
    int32_t i32;
    float f = 0;
    u_int64_t v64;
    int64_t i64;
    u_int8_t bkp;

    if(et == ndpi_serialization_end_of_record) {
      ndpi_deserialize_next(&deserializer);
      return;
    }

    switch(kt) {
      case ndpi_serialization_uint32:
        ndpi_deserialize_key_uint32(&deserializer, &k32);
        snprintf(key, sizeof(key), "%u", k32);
      break;

      case ndpi_serialization_string:
        ndpi_deserialize_key_string(&deserializer, &ks);
        bkp = ks.str[ks.str_len];
        ks.str[ks.str_len] = '\0';
        snprintf(key, sizeof(key), "%s", ks.str);
        ks.str[ks.str_len] = bkp;
      break;

      default:
        /* Unexpected type */
        return;
    }

    switch(et) {
      case ndpi_serialization_uint32:
        ndpi_deserialize_value_uint32(&deserializer, &v32);
        lua_push_int32_table_entry(vm, key, v32);
        break;

      case ndpi_serialization_uint64:
        ndpi_deserialize_value_uint64(&deserializer, &v64);
        lua_push_uint64_table_entry(vm, key, v64);
        break;

      case ndpi_serialization_int32:
        ndpi_deserialize_value_int32(&deserializer, &i32);
        lua_push_int32_table_entry(vm, key, i32);
        break;

      case ndpi_serialization_int64:
        ndpi_deserialize_value_int64(&deserializer, &i64);
        lua_push_uint64_table_entry(vm, key, i64);
        break;

      case ndpi_serialization_float:
        ndpi_deserialize_value_float(&deserializer, &f);
        lua_push_float_table_entry(vm, key, f);
        break;

      case ndpi_serialization_string:
        ndpi_deserialize_value_string(&deserializer, &vs);
        bkp = vs.str[vs.str_len];
        vs.str[vs.str_len] = '\0';
        lua_push_str_table_entry(vm, key, vs.str);
        vs.str[vs.str_len] = bkp;
        break;

      default:
        /* Unexpected type */
        return;
    }

    /* Move to the next element */
    ndpi_deserialize_next(&deserializer);
  }
}

/* ****************************************************** */

u_int16_t Utils::country2u16(const char *country_code) {
  if(country_code == NULL || strlen(country_code) < 2) return 0;
  return ((((u_int16_t) country_code[0]) << 8) | ((u_int16_t) country_code[1]));
}

/* ****************************************************** */

bool Utils::isNumber(const char *s, unsigned int s_len, bool *is_float) {
  unsigned int i;
  bool is_num = true;

  *is_float = false;

  for(i = 0; i < s_len; i++) {
    if(!isdigit(s[i]) && s[i] != '.') { is_num = false; break; }
    if(s[i] == '.') *is_float = true;
  }

  return is_num;
}

/* ****************************************************** */

bool Utils::isPingSupported() {
#ifndef WIN32
    int sd;

#if defined(__APPLE__)
    sd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
#else
    sd = socket(PF_INET, SOCK_RAW, IPPROTO_ICMP);
#endif

    if(sd != -1) {
        close(sd);

        return(true);
    }
#endif

    return(false);
}

/* ****************************************************** */

/*
 * Return the linux device name given an interface name
 * to handle PF_RING interfaces like zc:ens2f1@3
 * (it removes '<module>:' prefix or trailing '@<queue>')
 */
char *Utils::ifname2devname(const char *ifname, char *devname, int devname_size) {
  const char *colon;
  char *at;

  /* strip prefix ":" */
  colon = strchr(ifname, ':');
  strncpy(devname, colon != NULL ? colon+1 : ifname, devname_size);
  devname[devname_size-1] = '\0';

  /* strip trailing "@" */
  at = strchr(devname, '@');
  if(at != NULL)
    at[0] = '\0';

  return devname;
}

/* ****************************************************** */

ScoreCategory Utils::mapAlertToScoreCategory(AlertCategory alert_category) {
  if(alert_category == alert_category_security)
    return(score_category_security);
  else
    return(score_category_network);
}

/* ****************************************************** */

AlertLevel Utils::mapScoreToSeverity(u_int32_t score) {
  if (score < SCORE_LEVEL_NOTICE)
    return alert_level_info;
  else if (score < SCORE_LEVEL_WARNING)
    return alert_level_notice;
  else if (score < SCORE_LEVEL_ERROR)
    return alert_level_warning;
  else
    return alert_level_error;
}

/* ****************************************************** */

u_int8_t Utils::mapSeverityToScore(AlertLevel alert_level) {
  if(alert_level <= alert_level_info)
    return SCORE_LEVEL_INFO;
  else if(alert_level <= alert_level_notice)
    return SCORE_LEVEL_NOTICE;
  else if(alert_level <= alert_level_warning)
    return SCORE_LEVEL_WARNING;
  else if(alert_level <= alert_level_error)
    return SCORE_LEVEL_ERROR;
  else
    return SCORE_LEVEL_SEVERE;
}

/* ****************************************************** */

AlertLevelGroup Utils::mapAlertLevelToGroup(AlertLevel alert_level) {
  switch(alert_level) {
  case alert_level_debug:
  case alert_level_info:
  case alert_level_notice:
    return alert_level_group_notice_or_lower;
  case alert_level_warning:
    return alert_level_group_warning;
  case alert_level_error:
  case alert_level_critical:
  case alert_level_alert:
  case alert_level_emergency:
    return alert_level_group_error_or_higher;
  default:
    return alert_level_group_none;
  }
}

/* ****************************************************** */
  
bool Utils::hasExtension(const char *path, const char *ext) {
  int str_len = strlen(path);
  int ext_len = strlen(ext);
  return (str_len >= ext_len) && (strcmp(&path[str_len - ext_len], ext) == 0);
}

/* ****************************************************** */

#ifndef WIN32
int Utils::mapSyslogFacilityTextToValue(const char *facility_text) {
       if (strcasecmp(facility_text, "auth") == 0) return LOG_AUTH;
  else if (strcasecmp(facility_text, "authpriv") == 0) return LOG_AUTHPRIV;
  else if (strcasecmp(facility_text, "cron") == 0) return LOG_CRON;
  else if (strcasecmp(facility_text, "daemon") == 0) return LOG_DAEMON;
  else if (strcasecmp(facility_text, "ftp") == 0) return LOG_FTP;
  else if (strcasecmp(facility_text, "kern") == 0) return LOG_KERN;
  else if (strcasecmp(facility_text, "lpr") == 0) return LOG_LPR;
  else if (strcasecmp(facility_text, "mail") == 0) return LOG_MAIL;
  else if (strcasecmp(facility_text, "news") == 0) return LOG_NEWS;
  else if (strcasecmp(facility_text, "security") == 0) return LOG_AUTH;
  else if (strcasecmp(facility_text, "syslog") == 0) return LOG_SYSLOG;
  else if (strcasecmp(facility_text, "user") == 0) return LOG_USER;
  else if (strcasecmp(facility_text, "uucp") == 0) return LOG_UUCP;
  else if (strcasecmp(facility_text, "local0") == 0) return LOG_LOCAL0;
  else if (strcasecmp(facility_text, "local1") == 0) return LOG_LOCAL1;
  else if (strcasecmp(facility_text, "local2") == 0) return LOG_LOCAL2;
  else if (strcasecmp(facility_text, "local3") == 0) return LOG_LOCAL3;
  else if (strcasecmp(facility_text, "local4") == 0) return LOG_LOCAL4;
  else if (strcasecmp(facility_text, "local5") == 0) return LOG_LOCAL5;
  else if (strcasecmp(facility_text, "local6") == 0) return LOG_LOCAL6;
  else if (strcasecmp(facility_text, "local7") == 0) return LOG_LOCAL7;
  else return -1;
}
#endif

/* ****************************************************** */

static char* appendFilterString(char *filters, char *new_filter) {
  if(!filters)
    filters = strdup(new_filter);
  else {
    filters = (char*) realloc(filters, strlen(filters) + strlen(new_filter)
      + sizeof(" OR "));

    if(filters) {
      strcat(filters, " OR ");
      strcat(filters, new_filter);
    }
  }

  return(filters);
}

struct sqlite_filter_data {
  bool match_all;
  char *hosts_filter;
  char *flows_filter;
};

static void allowed_nets_walker(ndpi_patricia_node_t *node, void *data, void *user_data) {
  struct sqlite_filter_data *filterdata = (sqlite_filter_data*)user_data;
  struct in6_addr lower_addr;
  struct in6_addr upper_addr;
  ndpi_prefix_t *prefix = ndpi_patricia_get_node_prefix(node);
  int bitlen = prefix->bitlen;
  char lower_hex[33], upper_hex[33];
  char hosts_buf[512], flows_buf[512];

  if(filterdata->match_all)
    return;

  if(bitlen == 0) {
    /* Match all, no filter necessary */
    filterdata->match_all = true;

    if(filterdata->hosts_filter) {
      free(filterdata->hosts_filter);
      filterdata->flows_filter = NULL;
    }

    if(filterdata->flows_filter) {
      free(filterdata->flows_filter);
      filterdata->flows_filter = NULL;
    }

    return;
  }

  if(prefix->family == AF_INET) {
    memset(&lower_addr, 0, sizeof(lower_addr)-4);
    memcpy(((char*)&lower_addr) + 12, &prefix->add.sin.s_addr, 4);

    bitlen += 96;
  } else
    memcpy(&lower_addr, &prefix->add.sin6, sizeof(lower_addr));

  /* Calculate upper address */
  memcpy(&upper_addr, &lower_addr, sizeof(upper_addr));

  for(int i=0; i<(128 - bitlen); i++) {
    u_char bit = 127-i;

    upper_addr.s6_addr[bit / 8] |= (1 << (bit % 8));

    /* Also normalize the lower address */
    lower_addr.s6_addr[bit / 8] &= ~(1 << (bit % 8));
  }

  /* Convert to hex */
  for(int i=0; i<16; i++) {
    u_char lval = lower_addr.s6_addr[i];
    u_char uval = upper_addr.s6_addr[i];

    lower_hex[i*2]   = hex_chars[(lval >> 4) & 0xF];
    lower_hex[i*2+1] = hex_chars[lval & 0xF];

    upper_hex[i*2]   = hex_chars[(uval >> 4) & 0xF];
    upper_hex[i*2+1] = hex_chars[uval & 0xF];
  }

  lower_hex[32] = '\0';
  upper_hex[32] = '\0';

  /* Build filter strings */
  snprintf(hosts_buf, sizeof(hosts_buf),
	    "((ip >= x'%s') AND (ip <= x'%s'))",
	    lower_hex, upper_hex);

  snprintf(flows_buf, sizeof(flows_buf),
	    "(((cli_ip >= x'%s') AND (cli_ip <= x'%s')) OR ((srv_ip >= x'%s') AND (srv_ip <= x'%s')))",
	    lower_hex, upper_hex, lower_hex, upper_hex);

  filterdata->hosts_filter = appendFilterString(filterdata->hosts_filter, hosts_buf);

  filterdata->flows_filter = appendFilterString(filterdata->flows_filter, flows_buf);
}

/* ******************************************* */

void Utils::buildSqliteAllowedNetworksFilters(lua_State *vm) {
  AddressTree *allowed_nets = getLuaVMUserdata(vm, allowedNets);

  if(allowed_nets) {
    struct sqlite_filter_data data;
    memset(&data, 0, sizeof(data));

    allowed_nets->walk(allowed_nets_walker, &data);

    getLuaVMUservalue(vm, sqlite_hosts_filter) = data.hosts_filter;
    getLuaVMUservalue(vm, sqlite_flows_filter) = data.flows_filter;
  }

  getLuaVMUservalue(vm, sqlite_filters_loaded) = true;
}

/* ****************************************************** */

void Utils::make_session_key(char *buf, u_int buf_len) {
  snprintf(buf, buf_len, "session_%u_%u", ntop->getPrefs()->get_http_port(), ntop->getPrefs()->get_https_port());
}

/* ****************************************************** */
