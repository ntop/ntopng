/*
 *
 * (C) 2013-24 - ntop.org
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

#if defined(__OpenBSD__) || defined(__APPLE__) || defined(__FreeBSD__)
#include <net/if_dl.h>
#endif

#ifndef WIN32
#include <ifaddrs.h>
#endif

// #define TRACE_CAPABILITIES

static const char *hex_chars = "0123456789ABCDEF";

static map<string, int> initTcpStatesStr2State() {
  map<string, int> states_map;

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
  map<string, eBPFEventType> events_map;

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

static map<int, string> initTcpStates2StatesStr(
    const map<string, int> &tcp_states_str_to_state) {
  map<int, string> states_map;
  map<string, int>::const_iterator it;

  for (it = tcp_states_str_to_state.begin();
       it != tcp_states_str_to_state.end(); it++) {
    states_map[it->second] = it->first;
  }

  return states_map;
}

static map<eBPFEventType, string> initeBPFEventType2TypeStr(
    const map<string, eBPFEventType> &tcp_states_str_to_state) {
  map<eBPFEventType, string> events_map;
  map<string, eBPFEventType>::const_iterator it;

  for (it = tcp_states_str_to_state.begin();
       it != tcp_states_str_to_state.end(); it++) {
    events_map[it->second] = it->first;
  }

  return events_map;
};

static const map<string, int> tcp_state_str_2_state = initTcpStatesStr2State();
static const map<int, string> tcp_state_2_state_str =
    initTcpStates2StatesStr(tcp_state_str_2_state);
static const map<string, eBPFEventType> ebpf_event_str_2_event =
    initeBPFEventTypeStr2Type();
static const map<eBPFEventType, string> ebpf_event_2_event_str =
    initeBPFEventType2TypeStr(ebpf_event_str_2_event);

// A simple struct for strings.
typedef struct {
  char *s;
  size_t l;
} String;

typedef struct {
  u_int8_t header_over;
  char outbuf[3 * 65536];
  u_int num_bytes;
  lua_State *vm;
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
  CAP_DAC_OVERRIDE,    /* Bypass file read, write, and execute permission checks */
  CAP_NET_ADMIN,       /* Perform various network-related operations */
  CAP_NET_RAW,         /* Use RAW and PACKET sockets */
  CAP_NET_BIND_SERVICE /* Listen on non-privileges ports (e.g. UDP 162 for traps) */
};

int num_cap = sizeof(cap_values) / sizeof(cap_value_t);
#endif

static size_t curl_writefunc_to_lua(char *buffer, size_t size, size_t nitems,
                                    void *userp);
static size_t curl_hdf(char *buffer, size_t size, size_t nitems, void *userp);

/* ****************************************************** */

char *Utils::jsonLabel(int label, const char *label_str, char *buf,
                       u_int buf_len) {
  if (ntop->getPrefs()->json_labels_as_strings()) {
    snprintf(buf, buf_len, "%s", label_str);
  } else
    snprintf(buf, buf_len, "%d", label);

  return (buf);
}

/* ****************************************************** */

char *Utils::formatTraffic(float numBits, bool bits, char *buf, u_int buf_len) {
  char unit;

  if (bits)
    unit = 'b';
  else
    unit = 'B';

  if (numBits < 1024) {
    snprintf(buf, buf_len, "%lu %c", (unsigned long)numBits, unit);
  } else if (numBits < 1048576) {
    snprintf(buf, buf_len, "%.2f K%c", (float)(numBits) / 1024, unit);
  } else {
    float tmpMBits = ((float)numBits) / 1048576;

    if (tmpMBits < 1024) {
      snprintf(buf, buf_len, "%.2f M%c", tmpMBits, unit);
    } else {
      tmpMBits /= 1024;

      if (tmpMBits < 1024) {
        snprintf(buf, buf_len, "%.2f G%c", tmpMBits, unit);
      } else {
        snprintf(buf, buf_len, "%.2f T%c", (float)(tmpMBits) / 1024, unit);
      }
    }
  }

  return (buf);
}

/* ****************************************************** */

char *Utils::formatPackets(float numPkts, char *buf, u_int buf_len) {
  if (numPkts < 1000) {
    snprintf(buf, buf_len, "%.2f", numPkts);
  } else if (numPkts < 1000000) {
    snprintf(buf, buf_len, "%.2f K", numPkts / (float)1000);
  } else {
    numPkts /= 1000000;
    snprintf(buf, buf_len, "%.2f M", numPkts);
  }

  return (buf);
}

/* ****************************************************** */

char *Utils::l4proto2name(u_int8_t proto) {
  static char proto_string[8];

  /* NOTE: keep in sync with /lua/pro/db_explorer_data.lua */

  switch (proto) {
    case 0:
      return ((char *)"IP");
    case 1:
      return ((char *)"ICMP");
    case 2:
      return ((char *)"IGMP");
    case 6:
      return ((char *)"TCP");
    case 17:
      return ((char *)"UDP");
    case 41:
      return ((char *)"IPv6");
    case 46:
      return ((char *)"RSVP");
    case 47:
      return ((char *)"GRE");
    case 50:
      return ((char *)"ESP");
    case 51:
      return ((char *)"AH");
    case 58:
      return ((char *)"IPv6-ICMP");
    case 88:
      return ((char *)"EIGRP");
    case 89:
      return ((char *)"OSPF");
    case 103:
      return ((char *)"PIM");
    case 112:
      return ((char *)"VRRP");
    case 139:
      return ((char *)"HIP");

    default:
      snprintf(proto_string, sizeof(proto_string), "%u", proto);
      return (proto_string);
  }
}

/* ****************************************************** */

const char *Utils::edition2name(NtopngEdition ntopng_edition) {
  switch (ntopng_edition) {
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
  if (strcmp(name, "IP") == 0)
    return 0;
  else if (strcmp(name, "ICMP") == 0)
    return 1;
  else if (strcmp(name, "IGMP") == 0)
    return 2;
  else if (strcmp(name, "TCP") == 0)
    return 6;
  else if (strcmp(name, "UDP") == 0)
    return 17;
  else if (strcmp(name, "IPv6") == 0)
    return 41;
  else if (strcmp(name, "RSVP") == 0)
    return 46;
  else if (strcmp(name, "GRE") == 0)
    return 47;
  else if (strcmp(name, "ESP") == 0)
    return 50;
  else if (strcmp(name, "AH") == 0)
    return 51;
  else if (strcmp(name, "IPv6-ICMP") == 0)
    return 58;
  else if (strcmp(name, "OSPF") == 0)
    return 89;
  else if (strcmp(name, "PIM") == 0)
    return 103;
  else if (strcmp(name, "VRRP") == 0)
    return 112;
  else if (strcmp(name, "HIP") == 0)
    return 139;
  else
    return 0;
}

/* ****************************************************** */

u_int8_t Utils::queryname2type(const char *name) {
  if (strcmp(name, "A") == 0)
    return 1;
  else if (strcmp(name, "NS") == 0)
    return 2;
  else if (strcmp(name, "MD") == 0)
    return 3;
  else if (strcmp(name, "MF") == 0)
    return 4;
  else if (strcmp(name, "CNAME") == 0)
    return 5;
  else if (strcmp(name, "SOA") == 0)
    return 6;
  else if (strcmp(name, "MB") == 0)
    return 7;
  else if (strcmp(name, "MG") == 0)
    return 8;
  else if (strcmp(name, "MR") == 0)
    return 9;
  else if (strcmp(name, "NULL") == 0)
    return 10;
  else if (strcmp(name, "WKS") == 0)
    return 11;
  else if (strcmp(name, "PTR") == 0)
    return 12;
  else if (strcmp(name, "HINFO") == 0)
    return 13;
  else if (strcmp(name, "MINFO") == 0)
    return 14;
  else if (strcmp(name, "MX") == 0)
    return 15;
  else if (strcmp(name, "TXT") == 0)
    return 16;
  else if (strcmp(name, "AAAA") == 0)
    return 28;
  else if (strcmp(name, "A6") == 0)
    return 38;
  else if (strcmp(name, "SPF") == 0)
    return 99;
  else if (strcmp(name, "AXFR") == 0)
    return 252;
  else if (strcmp(name, "MAILB") == 0)
    return 253;
  else if (strcmp(name, "MAILA") == 0)
    return 254;
  else if (strcmp(name, "ANY") == 0)
    return 255;
  else
    return 0;
}

/* ****************************************************** */

bool Utils::isIPAddress(const char *ip) {
  struct in_addr addr4;
  struct in6_addr addr6;

  if ((ip == NULL) || (ip[0] == '\0')) return (false);

  if (strchr(ip, ':') != NULL) { /* IPv6 */
    if (inet_pton(AF_INET6, ip, &addr6) == 1) return (true);
  } else {
    if (inet_pton(AF_INET, ip, &addr4) == 1) return (true);
  }

  return (false);
}

/* ****************************************************** */

#ifdef PROFILING
u_int64_t Utils::getTimeNsec() {
  u_int64_t nsec = 0;
#ifdef __linux__
  struct timespec t;

  if (clock_gettime(CLOCK_REALTIME, &t) == 0)
    nsec = (u_int64_t)((u_int64_t)t.tv_sec * 1000000000) + t.tv_nsec;
#endif

  return nsec;
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

  if (cores_list == NULL) return 0;

  if (num_cores <= 1) return 0;

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

  if (mask == NULL || CPU_COUNT(mask) == 0) return (0);

#ifdef HAVE_LIBCAP
  ret = pthread_setaffinity_np(thread, sizeof(cpu_set_t), mask);
#endif

  return (ret);
}
#endif

/* ****************************************************** */

int Utils::setThreadAffinity(pthread_t thread, int core_id) {
#ifdef __linux__
  if (core_id < 0)
    return (0);
  else {
    int ret = -1;
#ifdef HAVE_LIBCAP
    u_int num_cores = ntop->getNumCPUs();
    u_long core = core_id % num_cores;
    cpu_set_t cpu_set;

    if (num_cores > 1) {
      CPU_ZERO(&cpu_set);
      CPU_SET(core, &cpu_set);
      ret = setThreadAffinityWithMask(thread, &cpu_set);
    }
#endif

    return (ret);
  }
#else
  return (0);
#endif
}

/* ****************************************************** */

void Utils::setThreadName(const char *name) {
#if defined(__APPLE__) || defined(__linux__)
  // Mac OS X: must be set from within the thread (can't specify thread ID)
  char buf[16];  // NOTE: on linux there is a 16 char limit
  int rc;
  char *bname = NULL;

  if (Utils::file_exists(name)) {
    bname = strrchr((char *)name, '/');
    if (bname) bname++;
  }

  snprintf(buf, sizeof(buf), "%s", bname ? bname : name);

#if defined(__APPLE__)
  if ((rc = pthread_setname_np(buf)))
#else
  if ((rc = pthread_setname_np(pthread_self(), buf)))
#endif
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to set pthread name %s: %d", buf, rc);
#endif
}

/* ****************************************************** */

char *Utils::trim(char *s) {
  char *end;

  while (isspace(s[0]) || (s[0] == '"') || (s[0] == '\'')) s++;
  if (s[0] == 0) return s;

  end = &s[strlen(s) - 1];
  while (end > s && (isspace(end[0]) || (end[0] == '"') || (end[0] == '\'')))
    end--;
  end[1] = 0;

  return s;
}

/* ****************************************************** */

u_int32_t Utils::hashString(const char *key, u_int32_t len) {
  if (!key) return 0;

  u_int32_t hash = 0;

  if (len == 0) len = (u_int32_t)strlen(key);

  for (u_int32_t i = 0; i < len; i++) hash += ((u_int32_t)key[i]) * i;

  return hash;
}

/* ****************************************************** */

float Utils::timeval2ms(const struct timeval *tv) {
  return ((float)tv->tv_sec * 1000 + (float)tv->tv_usec / 1000);
}

/* ****************************************************** */

u_int32_t Utils::timeval2usec(const struct timeval *tv) {
  return (tv->tv_sec * 1000000 + tv->tv_usec);
}

/* ****************************************************** */

u_int32_t Utils::usecTimevalDiff(const struct timeval *end,
                                 const struct timeval *begin) {
  if ((end->tv_sec == 0) && (end->tv_usec == 0))
    return (0);
  else {
    struct timeval res;

    res.tv_sec = end->tv_sec - begin->tv_sec;
    if (begin->tv_usec > end->tv_usec) {
      res.tv_usec = end->tv_usec + 1000000 - begin->tv_usec;
      res.tv_sec--;
    } else
      res.tv_usec = end->tv_usec - begin->tv_usec;

    return ((res.tv_sec * 1000000) + (res.tv_usec));
  }
}

/* ****************************************************** */

float Utils::msTimevalDiff(const struct timeval *end,
                           const struct timeval *begin) {
  if ((end->tv_sec == 0) && (end->tv_usec == 0))
    return (0);
  else {
    struct timeval res;

    res.tv_sec = end->tv_sec - begin->tv_sec;
    if (begin->tv_usec > end->tv_usec) {
      res.tv_usec = end->tv_usec + 1000000 - begin->tv_usec;
      res.tv_sec--;
    } else
      res.tv_usec = end->tv_usec - begin->tv_usec;

    return (((float)res.tv_sec * 1000) + ((float)res.tv_usec / (float)1000));
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

  if (strptime(str, format, &tm) == NULL) return 0;

  t = mktime(&tm) + (3600 * tm.tm_isdst);

#ifndef WIN32
  t -= tm.tm_gmtoff;
#endif

  if (t == -1) return 0;

  return t;
}

/* ****************************************************** */

bool Utils::file_exists(const char *path) {
  std::ifstream infile(path);

  /*  ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(): %s", __FUNCTION__,
   * path); */
  bool ret = infile.good();
  infile.close();
  return ret;
}

/* ****************************************************** */

bool Utils::dir_exists(const char *path) {
  struct stat buf;

  return !((stat(path, &buf) != 0) || (!S_ISDIR(buf.st_mode)));
}

/* ****************************************************** */

size_t Utils::file_write(const char *path, const char *content,
                         size_t content_len) {
  size_t ret = 0;
  FILE *fd = fopen(path, "wb");

  if (fd == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to write file %s",
                                 path);
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

  if (f) {
    fseek(f, 0, SEEK_END);
    length = ftell(f);
    fseek(f, 0, SEEK_SET);

    buffer = (char *)malloc(length);
    if (buffer) ret = fread(buffer, 1, length, f);

    fclose(f);

    if (buffer) {
      if (content && ret)
        *content = buffer;
      else
        free(buffer);
    }
  }

  return ret;
}

/* ****************************************************** */

int Utils::remove_recursively(const char *path) {
  DIR *d = opendir(path);
  size_t path_len = strlen(path);
  int r = -1;
  size_t len;
  char *buf;

  if (d) {
    struct dirent *p;

    r = 0;

    while ((r == 0) && (p = readdir(d))) {
      /* Skip the names "." and ".." as we don't want to recurse on them. */
      if (!strcmp(p->d_name, ".") || !strcmp(p->d_name, "..")) continue;

      len = path_len + strlen(p->d_name) + 2;
      buf = (char *)malloc(len);

      if (buf) {
        struct stat statbuf;

        snprintf(buf, len, "%s/%s", path, p->d_name);

        if (stat(buf, &statbuf) == 0) {
          if (S_ISDIR(statbuf.st_mode))
            r = remove_recursively(buf);
          else
            r = unlink(buf);
        }

        free(buf);
      }
    }

    closedir(d);
  }

  if (r == 0) r = rmdir(path);

  return r;
}

/* ****************************************************** */

bool Utils::mkdir_tree(char *const path) {
  int rc;
  struct stat s;

  ntop->fixPath(path);

  if (stat(path, &s) != 0) {
    /* Start at 1 to skip the root */
    for (int i = 1; path[i] != '\0'; i++)
      if (path[i] == CONST_PATH_SEP) {
#ifdef WIN32
        /* Do not create devices directory */
        if ((i > 1) && (path[i - 1] == ':')) continue;
#endif

        /*
         * If we are already handling the final portion
         * of a path, e.g. because the path has a trailing
         * CONST_PATH_SEP, do not create the final
         * directory: it will be created later.
         */
        if (path[i + 1] == '\0') break;

        path[i] = '\0';
        rc = Utils::mkdir(path, CONST_DEFAULT_DIR_MODE);

        path[i] = CONST_PATH_SEP;
      }

    rc = Utils::mkdir(path, CONST_DEFAULT_DIR_MODE);

    return (((rc == 0) || (errno == EEXIST /* Already existing */)) ? true
                                                                    : false);
  } else
    return (true); /* Already existing */
}

/* **************************************************** */

int Utils::mkdir(const char *path, mode_t mode) {
#ifdef WIN32
  return (_mkdir(path));
#else
  int rc = ::mkdir(path, mode);

  if (rc == -1) {
    if (errno != EEXIST)
      ntop->getTrace()->traceEvent(TRACE_WARNING, "mkdir(%s) failed [%d/%s]",
                                   path, errno, strerror(errno));
  } else {
    if (chmod(path, mode) == -1) /* Ubuntu 18 */
      ntop->getTrace()->traceEvent(TRACE_WARNING, "chmod(%s) failed [%d/%s]",
                                   path, errno, strerror(errno));
  }

  return (rc);
#endif
}

/* **************************************************** */

const char *Utils::trend2str(ValueTrend t) {
  switch (t) {
    case trend_up:
      return ("Up");
      break;

    case trend_down:
      return ("Down");
      break;

    case trend_stable:
      return ("Stable");
      break;

    default:
    case trend_unknown:
      return ("Unknown");
      break;
  }
}

/* **************************************************** */

int Utils::dropPrivileges() {
#ifndef WIN32
  struct passwd *pw = NULL;
  const char *username;
  int rv;

  if (getgid() && getuid()) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Privileges are not dropped as we're not superuser");
    return -1;
  }

  if (Utils::retainWriteCapabilities() != 0) {
#ifdef HAVE_LIBCAP
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to retain privileges for privileged file writing");
#endif
  }

  username = ntop->getPrefs()->get_user();
  pw = getpwnam(username);

  if (pw == NULL) {
    /* if the user (e.g. 'ntopng') does not exists, falls back to 'nobody' */
    username = CONST_OLD_DEFAULT_NTOP_USER;
    pw = getpwnam(username);
  }

  if (pw != NULL) {
    /* Change the working dir own2ership */
    rv = chown(ntop->get_working_dir(), pw->pw_uid, pw->pw_gid);
    if (rv != 0)
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Unable to change working dir '%s' owner",
                                   ntop->get_working_dir());

    if (ntop->getPrefs()->get_pid_path() != NULL) {
      /* Change PID file ownership to be able to delete it on shutdown */
      rv = chown(ntop->getPrefs()->get_pid_path(), pw->pw_uid, pw->pw_gid);
      if (rv != 0)
        ntop->getTrace()->traceEvent(TRACE_ERROR,
                                     "Unable to change owner to PID in file %s",
                                     ntop->getPrefs()->get_pid_path());
    }

    /* Drop privileges */
    /* Dear programmer, initgroups() is necessary as there may be extra groups
       for the user that we are going to drop privileges to that are not yet
       visible. This can happen for newely created groups, or when a user has
       been added to a new group.
       Don't remove it or you will waste hours of life.
     */
    if ((initgroups(pw->pw_name, pw->pw_gid) != 0) ||
        (setgid(pw->pw_gid) != 0) || (setuid(pw->pw_uid) != 0)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to drop privileges [%s]", strerror(errno));
      return -1;
    }

    if (ntop) ntop->setDroppedPrivileges();

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "User changed to %s", username);
#ifndef WIN32
    ntop->getTrace()->traceEvent(TRACE_INFO, "Umask: %#o", umask(0077));
#endif
  } else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate user %s",
                                 username);
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

char *Utils::base64_encode(unsigned char const *bytes_to_encode,
                           ssize_t in_len) {
  char *res = NULL;
  ssize_t res_len = 0;
  std::string ret;
  int i = 0;
  unsigned char char_array_3[3];
  unsigned char char_array_4[4];

  while (in_len--) {
    char_array_3[i++] = *(bytes_to_encode++);
    if (i == 3) {
      char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
      char_array_4[1] =
          ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
      char_array_4[2] =
          ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
      char_array_4[3] = char_array_3[2] & 0x3f;

      for (i = 0; (i < 4); i++) ret += base64_chars[char_array_4[i]];
      i = 0;
    }
  }

  if (i) {
    for (int j = i; j < 3; j++) char_array_3[j] = '\0';

    char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
    char_array_4[1] =
        ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
    char_array_4[2] =
        ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
    char_array_4[3] = char_array_3[2] & 0x3f;

    for (int j = 0; (j < i + 1); j++) ret += base64_chars[char_array_4[j]];

    while ((i++ < 3)) ret += '=';
  }

  if ((res = (char *)calloc(sizeof(char), ret.size() + 1))) {
    res_len = ret.copy(res, ret.size());
    res[res_len] = '\0';
  }

  return res;
}

/* **************************************************** */

std::string Utils::base64_decode(std::string const &encoded_string) {
  int in_len = encoded_string.size();
  int i = 0, in_ = 0;
  unsigned char char_array_4[4], char_array_3[3];
  std::string ret;

  while (in_len-- && (encoded_string[in_] != '=') &&
         is_base64(encoded_string[in_])) {
    char_array_4[i++] = encoded_string[in_];
    in_++;

    if (i == 4) {
      for (i = 0; i < 4; i++)
        char_array_4[i] = base64_chars.find(char_array_4[i]);

      char_array_3[0] =
          (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
      char_array_3[1] =
          ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
      char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

      for (i = 0; (i < 3); i++) ret += char_array_3[i];
      i = 0;
    }
  }

  if (i) {
    int j;

    for (j = i; j < 4; j++) char_array_4[j] = 0;

    for (j = 0; j < 4; j++)
      char_array_4[j] = base64_chars.find(char_array_4[j]);

    char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
    char_array_3[1] =
        ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
    char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

    for (j = 0; (j < i - 1); j++) ret += char_array_3[j];
  }

  return ret;
}

/* *************************************** */

double Utils::pearsonValueCorrelation(activity_bitmap *x, activity_bitmap *y) {
  double ex = 0, ey = 0, sxx = 0, syy = 0, sxy = 0, tiny_value = 1e-2;

  for (size_t i = 0; i < NUM_MINUTES_PER_DAY; i++) {
    /* Find the means */
    ex += x->counter[i], ey += y->counter[i];
  }

  ex /= NUM_MINUTES_PER_DAY, ey /= NUM_MINUTES_PER_DAY;

  for (size_t i = 0; i < NUM_MINUTES_PER_DAY; i++) {
    /* Compute the correlation coefficient */
    double xt = x->counter[i] - ex, yt = y->counter[i] - ey;

    sxx += xt * xt, syy += yt * yt, sxy += xt * yt;
  }

  return (sxy / (sqrt(sxx * syy) + tiny_value));
}

/* *************************************** */
/* XXX: it assumes that the vectors are bitmaps */
double Utils::JaccardSimilarity(activity_bitmap *x, activity_bitmap *y) {
  size_t inter_card = 0, union_card = 0;

  for (size_t i = 0; i < NUM_MINUTES_PER_DAY; i++) {
    union_card += x->counter[i] | y->counter[i];
    inter_card += x->counter[i] & y->counter[i];
  }

  if (union_card == 0) return (1e-2);

  return ((double)inter_card / union_card);
}

/* *************************************** */

#ifdef WIN32
extern "C" {
const char *strcasestr(const char *haystack, const char *needle) {
  int i = -1;

  while (haystack[++i] != '\0') {
    if (tolower(haystack[i]) == tolower(needle[0])) {
      int j = i, k = 0, match = 0;
      while (tolower(haystack[++j]) == tolower(needle[++k])) {
        match = 1;
        // Catch case when they match at the end
        // printf("j:%d, k:%d\n",j,k);
        if (haystack[j] == '\0' && needle[k] == '\0') {
          // printf("Mj:%d, k:%d\n",j,k);
          return &haystack[i];
        }
      }
      // Catch normal case
      if (match && needle[k] == '\0') {
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

  if (name && !strcmp(name, SYSTEM_INTERFACE_NAME)) return SYSTEM_INTERFACE_ID;

  if (name == NULL) return INVALID_INTERFACE_ID;

#ifdef WIN32
  else if (isdigit(name[0]))
    return (atoi(name));
#endif
  else if (!strncmp(name, "-", 1))
    name = (char *)"stdin";

  if (ntop->getRedis()) {
    if (ntop->getRedis()->hashGet((char *)CONST_IFACE_ID_PREFS, (char *)name,
                                  rsp, sizeof(rsp)) == 0) {
      /* Found */
      return (atoi(rsp));
    } else {
      for (int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
        snprintf(ifidx, sizeof(ifidx), "%d", i);
        if (ntop->getRedis()->hashGet((char *)CONST_IFACE_ID_PREFS, ifidx, rsp,
                                      sizeof(rsp)) < 0) {
          snprintf(rsp, sizeof(rsp), "%s", name);
          ntop->getRedis()->hashSet((char *)CONST_IFACE_ID_PREFS, rsp, ifidx);
          ntop->getRedis()->hashSet((char *)CONST_IFACE_ID_PREFS, ifidx, rsp);
          return (i);
        }
      }

      ntop->getTrace()->traceEvent(
          TRACE_ERROR,
          "Interface ids exhausted. Flush redis to create new interfaces.");
    }
  }

  return INVALID_INTERFACE_ID; /* This can't happen, hopefully */
}

/* **************************************************** */

char *Utils::stringtolower(char *str) {
  int i = 0;

  while (str[i] != '\0') {
    str[i] = tolower(str[i]);
    i++;
  }

  return str;
}

/* **************************************************** */

/* http://en.wikipedia.org/wiki/Hostname */

char *Utils::sanitizeHostName(char *str) {
  int i;

  for (i = 0; str[i] != '\0'; i++) {
    if (((str[i] >= 'a') && (str[i] <= 'z')) ||
        ((str[i] >= 'A') && (str[i] <= 'Z')) ||
        ((str[i] >= '0') && (str[i] <= '9')) || (str[i] == '-') ||
        (str[i] == '_') || (str[i] == '.') ||
        (str[i] == ':') /* Used in HTTP host:port */
        || (str[i] == '@') /* Used by DNS but not a valid char */)
      ;
    else if (str[i] == '_') {
      str[i] = '\0';
      break;
    } else
      str[i] = '_';
  }

  return (str);
}

/* **************************************************** */

char *Utils::stripHTML(const char *str) {
  if (!str) return NULL;
  int len = strlen(str), j = 0;
  char *stripped_str = NULL;

  stripped_str = (char *)malloc(len + 1);

  if (!stripped_str) return (NULL);

  // scan string
  for (int i = 0; i < len; i++) {
    // found an open '<', scan for its close
    if (str[i] == '<') {
      // charge ahead in the string until it runs out or we find what we're
      // looking for
      for (; i < len && str[i] != '>'; i++)
        ;
    } else {
      stripped_str[j] = str[i];
      j++;
    }
  }
  stripped_str[j] = 0;
  return stripped_str;
}

/* **************************************************** */

char *Utils::urlDecode(const char *src, char *dst, u_int dst_len) {
  char *ret = dst;
  u_int i = 0;

  dst_len--; /* Leave room for \0 */
  dst[dst_len] = 0;

  while ((*src) && (i < dst_len)) {
    char a, b;

    if ((*src == '%') && ((a = src[1]) && (b = src[2])) &&
        (isxdigit(a) && isxdigit(b))) {
      char h[3] = {a, b, 0};
      char hexval = (char)strtol(h, (char **)NULL, 16);

      //      if(iswprint(hexval))
      *dst++ = hexval;

      src += 3;
    } else if (*src == '+') {
      *dst++ = ' ';
      src++;
    } else
      *dst++ = *src++;

    i++;
  }

  *dst++ = '\0';
  return (ret);
}

/* **************************************************** */

/**
 * @brief Purify the HTTP parameter
 *
 * @param param   The parameter to purify (remove unliked chars with _)
 */

static const char *xssAttempts[] = {
    "<?import", "<applet", "<base", "<embed", "<frame", "<iframe",
    "<implementation", "<import", "<link", "<meta", "<object", "<script",
    "<style", "charset", "classid", "code", "codetype",
    /* "data", */
    "href", "http-equiv", "javascript:", "vbscript:", "vmlframe", "xlink:href",
    "=", NULL};

/* ************************************************************ */

/* http://www.ascii-code.com */

bool Utils::isPrintableChar(u_char c) {
  if (isprint(c)) return (true);

  if ((c >= 192) && (c <= 255)) return (true);

  return (false);
}

/* ************************************************************ */

/*
  The method below does basic UTF-8 validation without chacing
  for UTF-8 sequences validation
 */
bool Utils:: isValidUTF8(const u_char *param, size_t length) {
  size_t i = 0;

  while(i < length) {
    uint8_t byte = param[i];

    if(byte < 0x80) {
      // 1-byte character (ASCII)
      i++;
    } else if((byte >> 5) == 0b110) {
      // 2-byte character
      if(((i + 1) >= length) || ((param[i + 1] >> 6) != 0b10)) {
	return(false);  // Invalid continuation byte
      }
      i += 2;
    } else if((byte >> 4) == 0b1110) {
      // 3-byte character
      if(i + 2 >= length || (param[i + 1] >> 6) != 0b10 || (param[i + 2] >> 6) != 0b10) {
	return(false);  // Invalid continuation byte
      }
      i += 3;
    } else if((byte >> 3) == 0b11110) {
      // 4-byte character
      if(((i + 3) >= length)
	 || ((param[i + 1] >> 6) != 0b10)
	 || ((param[i + 2] >> 6) != 0b10)
	 || ((param[i + 3] >> 6) != 0b10)) {
	return(false);  // Invalid continuation byte
      }
      i += 4;
    } else {
      return(false);  // Invalid UTF-8 sequence start byte
    }
  }

  return(true);
}

/* ************************************************************ */

bool Utils::purifyHTTPparam(char *const param, bool strict, bool allowURL,
                            bool allowDots) {
  if(((u_char)param[0]) >= 0x80) {
    /* UTF8 string */
    bool ret = Utils::isValidUTF8((const u_char*)param, strlen(param));

    if(ret)
      return(true);
  }

  if(strict) {
    for(int i = 0; xssAttempts[i] != NULL; i++) {
      if(strstr(param, xssAttempts[i])) {
        ntop->getTrace()->traceEvent(TRACE_WARNING,
                                     "Found possible XSS attempt: %s [%s]",
                                     param, xssAttempts[i]);
        param[0] = '\0';
        return (true);
      }
    }
  }

  for(int i = 0; param[i] != '\0'; i++) {
    bool is_good;

    if(strict) {
      is_good = ((param[i] >= 'a') && (param[i] <= 'z')) ||
                ((param[i] >= 'A') && (param[i] <= 'Z')) ||
                ((param[i] >= '0') && (param[i] <= '9'))
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
        c = param[i + 1] | 0x40;
        new_i = i + 1; /* We are actually validating two bytes */
      } else {
        c = param[i];
        new_i = i;
      }

      is_good = Utils::isPrintableChar(c) && (c != '<') && (c != '>') &&
                (c != '"'); /* Prevents injections - single quotes are allowed
                               and will be validated in http_lint.lua */

      if(is_good) i = new_i;
    }

    if(is_good)
      ; /* Good: we're on the whitelist */
    else
      param[i] = '_'; /* Invalid char: we discard it */

    if((i > 0) &&
        (((!allowDots) && (param[i] == '.') && (param[i - 1] == '.')) ||
         ((!allowURL) && ((param[i] == '/') && (param[i - 1] == '/'))) ||
         ((param[i] == '\\') && (param[i - 1] == '\\')))) {
      /* Make sure we do not have .. in the variable that can be used for future
       * hacking */
      param[i - 1] = '_', param[i] = '_'; /* Invalidate the path */
    }
  }

  return(false);
}

/* ************************************************************ */

bool Utils::sendTCPData(char *host, int port, char *data,
                        int timeout /* msec */) {
  struct hostent *server = NULL;
  struct sockaddr_in serv_addr;
  int sockfd = -1;
  int retval;
  bool rc = false;
  static time_t last_warn = 0;

  server = gethostbyname(host);
  if (server == NULL) return false;

  memset((char *)&serv_addr, 0, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  memcpy((char *)&serv_addr.sin_addr.s_addr, (char *)server->h_addr,
         server->h_length);
  serv_addr.sin_port = htons(port);

  sockfd = Utils::openSocket(AF_INET, SOCK_STREAM, 0, "sendTCPData");

  if (sockfd < 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
    return false;
  }

#ifndef WIN32
  if (timeout == 0) {
    retval = fcntl(sockfd, F_SETFL, fcntl(sockfd, F_GETFL, 0) | O_NONBLOCK);
    if (retval == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Error setting NONBLOCK flag");
      Utils::closeSocket(sockfd);
      return false;
    }
  } else {
    struct timeval tv_timeout;
    tv_timeout.tv_sec = timeout / 1000;
    tv_timeout.tv_usec = (timeout % 1000) * 1000;
    retval = setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &tv_timeout,
                        sizeof(tv_timeout));
    if (retval == -1) {
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Error setting send timeout: %s", strerror(errno));
      Utils::closeSocket(sockfd);
      return false;
    }
  }
#endif

  if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0 &&
      (errno == ECONNREFUSED || errno == EALREADY || errno == EAGAIN ||
       errno == ENETUNREACH || errno == ETIMEDOUT)) {
    time_t now = time(NULL);
    if (now > last_warn) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Could not connect to remote party");
      last_warn = now;
    }
    Utils::closeSocket(sockfd);
    return false;
  }

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Sending '%s' to %s:%d",
  //   data, host, port);

  rc = true;
  retval = send(sockfd, data, strlen(data), 0);
  if (retval <= 0) {
    time_t now = time(NULL);
    if (now > last_warn) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Send failed: %s (%d)",
                                   strerror(errno), errno);
      last_warn = now;
    }
    rc = false;
  }

  Utils::closeSocket(sockfd);

  return rc;
}

/* ************************************************************ */

bool Utils::sendUDPData(char *host, int port, char *data) {
  int sockfd = ntop->getUdpSock();
  int rc = -1;

  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s: %s:%d %s", __FUNCTION__,
  //  host, port, data);

  if (sockfd == -1)
    return false;

  if (strchr(host, ':') != NULL) {
    struct sockaddr_in6 serv_addr;

    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin6_family = AF_INET6;
    inet_pton(AF_INET6, host, &serv_addr.sin6_addr);
    serv_addr.sin6_port = htons(port);

    rc = sendto(sockfd, data, strlen(data), 0, (struct sockaddr *)&serv_addr,
                sizeof(serv_addr));
  } else {
    struct sockaddr_in serv_addr;
    struct hostent *server = NULL;

    server = gethostbyname(host);
    if (server == NULL) return false;

    memset((char *)&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    //serv_addr.sin_addr.s_addr = inet_addr(host);
    memcpy((char *)&serv_addr.sin_addr.s_addr, (char *)server->h_addr,
           server->h_length);
    serv_addr.sin_port = htons(port);

    rc = sendto(sockfd, data, strlen(data), 0, (struct sockaddr *)&serv_addr,
                sizeof(serv_addr));
  }

  return rc != -1;
}

/* **************************************************** */

/* holder for curl fetch */
struct curl_fetcher_t {
  char *const payload;
  size_t cur_size;
  const size_t max_size;
};

static size_t curl_get_writefunc(void *contents, size_t size, size_t nmemb,
                                 void *userp) {
  size_t realsize = size * nmemb;
  struct curl_fetcher_t *p = (struct curl_fetcher_t *)userp;

  if (!p->max_size) return realsize;

  /* Leave the last position for a '\0' */
  if (p->cur_size + realsize > p->max_size - 1)
    realsize = p->max_size - p->cur_size - 1;

  if (realsize) {
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

static int curl_post_writefunc(void *ptr, size_t size, size_t nmemb,
                               void *stream) {
  char *str = (char *)ptr;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "[JSON] %s", str);
  return (size * nmemb);
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

  switch (type) {
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

  if (dir) {
    char *msg = data;

    while (*msg) {
      char *end = strchr(msg, '\n');
      if (!end) break;

      *end = '\0';
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[CURL] %c %s", dir, msg);
      *end = '\n';
      msg = end + 1;
    }
  }

  return (size);
}

/* **************************************** */

static size_t curl_smtp_payload_source(void *ptr, size_t size, size_t nmemb,
                                       void *userp) {
  struct snmp_upload_status *upload_ctx = (struct snmp_upload_status *)userp;

  if ((size == 0) || (nmemb == 0) || ((size * nmemb) < 1)) {
    return 0;
  }

  char *eol = strstr(upload_ctx->lines, "\r\n");

  if (eol) {
    size_t len = min(size, (size_t)(eol - upload_ctx->lines + 2));
    memcpy(ptr, upload_ctx->lines, len);
    upload_ctx->lines += len;

    return len;
  }

  return 0;
}

#endif

/* **************************************** */

static void readCurlStats(CURL *curl, HTTPTranferStats *stats, lua_State *vm) {
  curl_easy_getinfo(curl, CURLINFO_NAMELOOKUP_TIME, &stats->namelookup);
  curl_easy_getinfo(curl, CURLINFO_CONNECT_TIME, &stats->connect);
  curl_easy_getinfo(curl, CURLINFO_APPCONNECT_TIME, &stats->appconnect);
  curl_easy_getinfo(curl, CURLINFO_PRETRANSFER_TIME, &stats->pretransfer);
  curl_easy_getinfo(curl, CURLINFO_REDIRECT_TIME, &stats->redirect);
  curl_easy_getinfo(curl, CURLINFO_STARTTRANSFER_TIME, &stats->start);
  curl_easy_getinfo(curl, CURLINFO_TOTAL_TIME, &stats->total);

  if (vm) {
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

  ntop->getTrace()->traceEvent(
      TRACE_INFO,
      "[NAMELOOKUP_TIME %.02f][CONNECT_TIME %.02f][APPCONNECT_TIME "
      "%.02f][PRETRANSFER_TIME %.02f]"
      "[REDIRECT_TIME %.02f][STARTTRANSFER_TIME %.02f][TOTAL_TIME %.02f]",
      stats->namelookup, stats->connect, stats->appconnect, stats->pretransfer,
      stats->redirect, stats->start, stats->total);
}

/* **************************************** */

static void fillcURLProxy(CURL *curl) {
  char *http_proxy = NULL;
  char *http_proxy_port = NULL;
  char *no_proxy = NULL;

  http_proxy = getenv("HTTP_PROXY");
  if (!http_proxy) http_proxy = getenv("http_proxy");

  if (http_proxy) {
    char proxy[1024];

    http_proxy_port = getenv("HTTP_PROXY_PORT");
    if (!http_proxy_port) http_proxy_port = getenv("http_proxy_port");

    if (http_proxy_port)
      snprintf(proxy, sizeof(proxy), "%s:%s", http_proxy, http_proxy_port);
    else
      snprintf(proxy, sizeof(proxy), "%s", http_proxy);

    curl_easy_setopt(curl, CURLOPT_PROXY, proxy);
    curl_easy_setopt(curl, CURLOPT_PROXYTYPE, CURLPROXY_HTTP);

    no_proxy = getenv("NO_PROXY");
    if (!no_proxy) no_proxy = getenv("no_proxy");

    if (no_proxy) {
      char no_proxy_buf[1024];

      snprintf(no_proxy_buf, sizeof(no_proxy_buf), "%s", no_proxy);
      curl_easy_setopt(curl, CURLOPT_NOPROXY, no_proxy_buf);
    }
  }
}

/* **************************************** */

bool Utils::postHTTPJsonData(char *bearer_token, char *username, char *password,
                             char *url, char *json, int timeout,
                             HTTPTranferStats *stats) {
  CURL *curl;
  bool ret = false;

  curl = curl_easy_init();
  if (curl) {
    CURLcode res;
    struct curl_slist *headers = NULL;

    fillcURLProxy(curl);

    memset(stats, 0, sizeof(HTTPTranferStats));
    curl_easy_setopt(curl, CURLOPT_URL, url);

    if (bearer_token && bearer_token[0] != '\0') {
#ifdef CURLAUTH_BEARER
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_BEARER);
      curl_easy_setopt(curl, CURLOPT_XOAUTH2_BEARER, bearer_token);
#else
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Bearer auth is not supported by curl (%s)", url);
      return (false);
#endif
    } else if ((username && (username[0] != '\0')) ||
               (password && (password[0] != '\0'))) {
      char auth[64];

      snprintf(auth, sizeof(auth), "%s:%s", username ? username : "",
               password ? password : "");
      curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
    }

    if (!strncmp(url, "https", 5) && ntop->getPrefs()->do_insecure_tls()) {
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
      curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout * 1000);
#endif
    }

    res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to post data to (%s): %s", url,
                                   curl_easy_strerror(res));
    } else {
      long http_code = 0;

      ntop->getTrace()->traceEvent(TRACE_INFO, "Posted JSON to %s", url);
      readCurlStats(curl, stats, NULL);

      curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
      // Success if http_code is 2xx, failure otherwise
      if (http_code >= 200 && http_code <= 299)
        ret = true;
      else
        ntop->getTrace()->traceEvent(
            TRACE_WARNING, "Unexpected HTTP response code received %u",
            http_code);
    }

    /* always cleanup */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to initialize curl");

  return (ret);
}

/* **************************************** */

bool Utils::postHTTPJsonData(char *bearer_token, char *username, char *password,
                             char *url, char *json, int timeout,
                             HTTPTranferStats *stats, char *return_data,
                             int return_data_size, int *response_code) {
  CURL *curl;
  bool ret = false;

  curl = curl_easy_init();

  if (curl) {
    CURLcode res;
    struct curl_slist *headers = NULL;
    curl_fetcher_t fetcher = {/* .payload =  */ return_data,
                              /* .cur_size = */ 0,
                              /* .max_size = */ (size_t)return_data_size};

    fillcURLProxy(curl);

    memset(stats, 0, sizeof(HTTPTranferStats));
    curl_easy_setopt(curl, CURLOPT_URL, url);

    if (bearer_token && bearer_token[0] != '\0') {
#ifdef CURLAUTH_BEARER
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_BEARER);
      curl_easy_setopt(curl, CURLOPT_XOAUTH2_BEARER, bearer_token);
#else
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Bearer auth is not supported by curl (%s)", url);
      return (false);
#endif
    } else if ((username && (username[0] != '\0')) ||
               (password && (password[0] != '\0'))) {
      char auth[64];

      snprintf(auth, sizeof(auth), "%s:%s", username ? username : "",
               password ? password : "");
      curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
    }

    if (!strncmp(url, "https", 5) && ntop->getPrefs()->do_insecure_tls()) {
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
      curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout * 1000);
#endif
    }

    res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to post data to (%s): %s", url,
                                   curl_easy_strerror(res));
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

  return (ret);
}

/* **************************************** */

static size_t read_callback(void *ptr, size_t size, size_t nmemb,
                            void *stream) {
  return (fread(ptr, size, nmemb, (FILE *)stream));
}

bool Utils::postHTTPTextFile(lua_State *vm, char *username, char *password,
                             char *url, char *path, int timeout,
                             HTTPTranferStats *stats) {
  CURL *curl;
  bool ret = true;
  struct stat buf;
  size_t file_len;
  FILE *fd;

  if (stat(path, &buf) != 0) return (false);

  if ((fd = fopen(path, "rb")) == NULL)
    return (false);
  else
    file_len = (size_t)buf.st_size;

  curl = curl_easy_init();

  if (curl) {
    CURLcode res;
    DownloadState *state = NULL;
    struct curl_slist *headers = NULL;

    fillcURLProxy(curl);

    memset(stats, 0, sizeof(HTTPTranferStats));
    curl_easy_setopt(curl, CURLOPT_URL, url);

    if ((username && (username[0] != '\0')) ||
        (password && (password[0] != '\0'))) {
      char auth[64];

      snprintf(auth, sizeof(auth), "%s:%s", username ? username : "",
               password ? password : "");
      curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
    }

    if (!strncmp(url, "https", 5) && ntop->getPrefs()->do_insecure_tls()) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    headers =
        curl_slist_append(headers, "Content-Type: text/plain; charset=utf-8");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    curl_easy_setopt(curl, CURLOPT_READDATA, fd);
    curl_easy_setopt(curl, CURLOPT_READFUNCTION, read_callback);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (curl_off_t)file_len);

    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);

#ifdef CURLOPT_CONNECTTIMEOUT_MS
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout * 1000);
#endif

    state = (DownloadState *)malloc(sizeof(DownloadState));
    if (state != NULL) {
      memset(state, 0, sizeof(DownloadState));

      curl_easy_setopt(curl, CURLOPT_WRITEDATA, state);
      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_lua);
      curl_easy_setopt(curl, CURLOPT_HEADERDATA, state);
      curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curl_hdf);

      state->vm = vm, state->header_over = 0, state->return_content = true;
    } else {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
      curl_easy_cleanup(curl);
      if (vm) lua_pushnil(vm);
      return (false);
    }

    if (vm) lua_newtable(vm);

    res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_INFO,
                                   "Unable to post data to (%s): %s", url,
                                   curl_easy_strerror(res));
      lua_push_str_table_entry(vm, "error_msg", curl_easy_strerror(res));
      ret = false;
    } else {
      ntop->getTrace()->traceEvent(TRACE_INFO, "Posted JSON to %s", url);
      readCurlStats(curl, stats, NULL);

      if (vm) {
        long response_code;

	lua_push_str_table_entry(vm, "CONTENT", state->outbuf);
        lua_push_uint64_table_entry(vm, "CONTENT_LEN", state->num_bytes);

        if (curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) ==
            CURLE_OK)
          lua_push_uint64_table_entry(vm, "RESPONSE_CODE", response_code);
      }
    }

    if (state) free(state);

    fclose(fd);

    /* always cleanup */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  return (ret);
}

/* **************************************** */

bool Utils::sendMail(lua_State *vm, char *from, char *to, char *cc,
                     char *message, char *smtp_server, char *username,
                     char *password, bool use_proxy, bool verbose) {
  bool ret = true;
  const char *ret_str = "";

#ifdef HAVE_CURL_SMTP
  CURL *curl;
  CURLcode res;
  struct curl_slist *recipients = NULL;
  struct snmp_upload_status *upload_ctx =
      (struct snmp_upload_status *)calloc(1, sizeof(struct snmp_upload_status));

  if (!upload_ctx) {
    ret = false;
    goto out;
  }

  upload_ctx->lines = message;
  curl = curl_easy_init();

  if (curl) {

    if (use_proxy) {
      fillcURLProxy(curl);
    }

    if (username != NULL && password != NULL) {
      curl_easy_setopt(curl, CURLOPT_USERNAME, username);
      curl_easy_setopt(curl, CURLOPT_PASSWORD, password);
    }

    curl_easy_setopt(curl, CURLOPT_URL, smtp_server);

    if (strncmp(smtp_server, "smtps://", 8) == 0)
      curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_ALL);
    else if (strncmp(smtp_server, "smtp://", 7) == 0)
      curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_NONE);
    else /* Try using SSL */
      curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_TRY);

    if (ntop->getPrefs()->do_insecure_tls()) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    curl_easy_setopt(curl, CURLOPT_MAIL_FROM, from);
    if(verbose) ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding from: %s", from);

    recipients = curl_slist_append(recipients, to);
    if(verbose) ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding to: %s", to);

    if (cc && cc[0]) {
      char *ccs = strdup(cc);

      if(ccs) {
	char *tmp, *rec;

	rec = strtok_r(ccs, ",", &tmp);

	while(rec != NULL) {
	  if(verbose) ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding cc: %s", rec);
	  recipients = curl_slist_append(recipients, rec);
	  rec = strtok_r(NULL, ",", &tmp);
	}

	free(ccs);
      }
    }
    curl_easy_setopt(curl, CURLOPT_MAIL_RCPT, recipients);

    curl_easy_setopt(curl, CURLOPT_READFUNCTION, curl_smtp_payload_source);
    curl_easy_setopt(curl, CURLOPT_READDATA, upload_ctx);
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1L);

    if (ntop->getTrace()->get_trace_level() >= TRACE_LEVEL_DEBUG
        || verbose) {
      /* Show verbose message trace */
      curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
      curl_easy_setopt(curl, CURLOPT_DEBUGFUNCTION, curl_debugfunc);
      curl_easy_setopt(curl, CURLOPT_DEBUGDATA, upload_ctx);
    }

    res = curl_easy_perform(curl);
    ret_str = curl_easy_strerror(res);

    if (res != CURLE_OK) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to send email to (%s): %s. Run "
                                   "ntopng with -v6 for more details.",
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

  if (vm) {
    /*
    If a lua VM has been passed as parameter, return code and return message are
    pushed into the lua stack.
    */
    lua_newtable(vm);
    lua_push_bool_table_entry(vm, "success", ret);
    lua_push_str_table_entry(vm, "msg", ret_str);
  } else if (!ret)
    /*
      If not lua VM has been passed, in case of error, a message is logged to
      stdout
     */
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to send email to (%s): %s. Run ntopng "
                                 "with -v6 for more details.",
                                 smtp_server, ret_str);
  return ret;
}

/* **************************************** */

/* curl calls this routine to get more data */
static size_t curl_writefunc_to_lua(char *buffer, size_t size, size_t nitems,
                                    void *userp) {
  DownloadState *state = (DownloadState *)userp;
  int len = size * nitems, diff;

  if (state->header_over == 0) {
    /* We need to parse the header as this is the first call for the body */
    char *tmp, *element;

    state->outbuf[state->num_bytes] = 0;
    element = strtok_r(state->outbuf, "\r\n", &tmp);
    if (element) element = strtok_r(NULL, "\r\n", &tmp);

    lua_newtable(state->vm);

    while (element) {
      char *column = strchr(element, ':');

      if (!column) break;

      column[0] = '\0';

      /* Put everything in lowercase */
      for (int i = 0; element[i] != '\0'; i++) element[i] = tolower(element[i]);
      lua_push_str_table_entry(state->vm, element, &column[1]);

      element = strtok_r(NULL, "\r\n", &tmp);
    }

    lua_pushstring(state->vm, "HTTP_HEADER");
    lua_insert(state->vm, -2);
    lua_settable(state->vm, -3);

    state->num_bytes = 0, state->header_over = 1;
  }

  if (state->return_content) {
    diff = sizeof(state->outbuf) - state->num_bytes - 1;

    if (diff > 0) {
      int buff_diff = min(diff, len);

      if (buff_diff > 0) {
        strncpy(&state->outbuf[state->num_bytes], buffer, buff_diff);
        state->num_bytes += buff_diff;
        state->outbuf[state->num_bytes] = '\0';
      }
    }
  }

  return (len);
}

/* **************************************** */

static size_t curl_writefunc_to_file(void *ptr, size_t size, size_t nmemb,
                                     void *stream) {
  size_t written = fwrite(ptr, size, nmemb, (FILE *)stream);
  return written;
}

/* **************************************** */

/* Same as the above function but only for header */
static size_t curl_hdf(char *buffer, size_t size, size_t nitems, void *userp) {
  DownloadState *state = (DownloadState *)userp;
  int len = size * nitems;
  int diff = sizeof(state->outbuf) - state->num_bytes - 1;

  if (diff > 0) {
    int buff_diff = min(diff, len);

    if (buff_diff > 0) {
      strncpy(&state->outbuf[state->num_bytes], buffer, buff_diff);
      state->num_bytes += buff_diff;
      state->outbuf[state->num_bytes] = '\0';
    }
  }

  return (len);
}

/* **************************************** */

bool Utils::progressCanContinue(ProgressState *progressState) {
  struct mg_connection *conn;
  time_t now = time(0);

  if (progressState->vm && ((now - progressState->last_conn_check) >= 1) &&
      (conn = getLuaVMUserdata(progressState->vm, conn))) {
    progressState->last_conn_check = now;

    if (!mg_is_client_connected(conn))
      /* connection to the client was closed, should not continue */
      return (false);
  }

  return (true);
}

/* **************************************** */

static int progress_callback(void *clientp, double dltotal, double dlnow,
                             double ultotal, double ulnow) {
  ProgressState *progressState = (ProgressState *)clientp;

  progressState->bytes.download = (u_int32_t)dlnow,
  progressState->bytes.upload = (u_int32_t)ulnow;

  return Utils::progressCanContinue(progressState) ? 0 /* continue */
                                                   : 1 /* stop transfer */;
}

/* **************************************** */

/* form_data is in format param=value&param1=&value1... */
bool Utils::httpGetPost(lua_State *vm, char *url,
                        /* NOTE if user_header_token != NULL, username AND
                           password are ignored, and vice-versa */
                        char *username, char *password, char *user_header_token,
                        int timeout, bool return_content,
                        bool use_cookie_authentication, HTTPTranferStats *stats,
                        const char *form_data, char *write_fname,
                        bool follow_redirects, int ip_version,
			bool use_put_method) {
  CURL *curl = curl_easy_init();
  FILE *out_f = NULL;
  bool ret = true;
  char tokenBuffer[64];
  bool used_tokenBuffer = false;

  tokenBuffer[0] = '\0';

  if (curl) {
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

    if (user_header_token != NULL) {
      snprintf(tokenBuffer, sizeof(tokenBuffer), "Authorization: Token %s",
               user_header_token);
    } else {
      if (username || password) {
        char auth[64];

        if (use_cookie_authentication) {
          snprintf(auth, sizeof(auth), "user=%s; password=%s",
                   username ? username : "", password ? password : "");
          curl_easy_setopt(curl, CURLOPT_COOKIE, auth);
        } else {
          if (username && (username[0] != '\0')) {
            snprintf(auth, sizeof(auth), "%s:%s", username ? username : "",
                     password ? password : "");
            curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
            curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
          }
        }
      }
    }

    if (!strncmp(url, "https", 5) && ntop->getPrefs()->do_insecure_tls()) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);

#ifdef CURLOPT_SSL_ENABLE_ALPN
      /* Note: this option is enabled by default */
      curl_easy_setopt(curl, CURLOPT_SSL_ENABLE_ALPN, 1L); /* Enable ALPN */
#endif

#ifdef CURLOPT_SSL_ENABLE_NPN
      /* Note: this options is deprecated since 7.86.0 */
      curl_easy_setopt(curl, CURLOPT_SSL_ENABLE_NPN,
                       1L); /* Negotiate HTTP/2 if available */
#endif
    }

    if (form_data) {
      /* This is a POST request */
      curl_easy_setopt(curl, CURLOPT_POST, 1L);
      curl_easy_setopt(curl, CURLOPT_POSTFIELDS, form_data);
      curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(form_data));

      if (form_data[0] == '{' /* JSON */) {
        headers = curl_slist_append(headers, "Content-Type: application/json");

        if (tokenBuffer[0] != '\0') {
          headers = curl_slist_append(headers, tokenBuffer);
          used_tokenBuffer = true;
        }
      }
    }

    if ((tokenBuffer[0] != '\0') && (!used_tokenBuffer)) {
      headers = curl_slist_append(headers, tokenBuffer);
      used_tokenBuffer = true;
    }

    if (headers != NULL) curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    if(use_put_method) {
      /* enable uploading (implies PUT over HTTP) */
      curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PUT");
    }

    if (write_fname) {
      ntop->fixPath(write_fname);
      out_f = fopen(write_fname, "wb");

      if (out_f == NULL) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Could not open %s for write",
                                     write_fname, strerror(errno));
        curl_easy_cleanup(curl);
        if (vm) lua_pushnil(vm);
        return (false);
      }

      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_file);
      curl_easy_setopt(curl, CURLOPT_WRITEDATA, out_f);
    } else {
      state = (DownloadState *)malloc(sizeof(DownloadState));
      if (state != NULL) {
        memset(state, 0, sizeof(DownloadState));

        curl_easy_setopt(curl, CURLOPT_WRITEDATA, state);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writefunc_to_lua);
        curl_easy_setopt(curl, CURLOPT_HEADERDATA, state);
        curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curl_hdf);

        state->vm = vm, state->header_over = 0,
        state->return_content = return_content;
      } else {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory");
        curl_easy_cleanup(curl);
        if (vm) lua_pushnil(vm);
        return (false);
      }
    }

    if (follow_redirects) {
      curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
      curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5);
    }

    if (ip_version == 4)
      curl_easy_setopt(curl, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
    else if (ip_version == 6)
      curl_easy_setopt(curl, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V6);

    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);

    if (!form_data) {
      /* A GET request, track client connection status */
      memset(&progressState, 0, sizeof(progressState));
      progressState.vm = vm;
      curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);

#if LIBCURL_VERSION_NUM >= 0x072000
      curl_easy_setopt(curl, CURLOPT_XFERINFOFUNCTION, progress_callback);
#else
      curl_easy_setopt(curl, CURLOPT_PROGRESSFUNCTION, progress_callback);
#endif
      curl_easy_setopt(curl, CURLOPT_PROGRESSDATA, &progressState);
    }

#ifdef CURLOPT_CONNECTTIMEOUT_MS
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout * 1000);
#endif

    if (ntop->getTrace()->get_trace_level() > TRACE_LEVEL_NORMAL)
      curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);

    snprintf(ua, sizeof(ua), "%s/%s/%s", PACKAGE_STRING, PACKAGE_MACHINE,
             PACKAGE_OS);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, ua);
    // curl_easy_setopt(curl, CURLOPT_USERAGENT, "libcurl/7.54.0");

    if (vm) lua_newtable(vm);

    curlcode = curl_easy_perform(curl);

    /* Workaround for curl 7.81.0 which fails in case of unexpected EOF
     * with OpenSSL 3.0.x (https://github.com/ntop/ntopng/issues/8434) */
    if (curlcode == CURLE_RECV_ERROR && state && state->num_bytes > 0)
      curlcode = CURLE_OK;

    if (curlcode == CURLE_OK) {
      if (vm) {
        if (return_content && state) {
          lua_push_str_table_entry(vm, "CONTENT", state->outbuf);
          lua_push_uint64_table_entry(vm, "CONTENT_LEN", state->num_bytes);
        }

        char *ip = NULL;
        if (!curl_easy_getinfo(curl, CURLINFO_PRIMARY_IP, &ip) && ip)
          lua_push_str_table_entry(vm, "RESOLVED_IP", ip);
      }

      ret = true;
    } else {
      if (vm) {
        lua_push_str_table_entry(vm, "ERROR", curl_easy_strerror(curlcode));
      }

      ret = false;
    }

    if (vm) {
      readCurlStats(curl, stats, vm);

      if (curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) == CURLE_OK)
        lua_push_uint64_table_entry(vm, "RESPONSE_CODE", response_code);

      if ((curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &content_type) == CURLE_OK) && content_type)
        lua_push_str_table_entry(vm, "CONTENT_TYPE", content_type);

      if (curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &redirection) == CURLE_OK)
        lua_push_str_table_entry(vm, "EFFECTIVE_URL", redirection);

      if (!form_data) {
        lua_push_uint64_table_entry(vm, "BYTES_DOWNLOAD",
                                    progressState.bytes.download);
        lua_push_uint64_table_entry(vm, "BYTES_UPLOAD",
                                    progressState.bytes.upload);
      }

      if (!ret) lua_push_bool_table_entry(vm, "IS_PARTIAL", true);
    }

    if (state) free(state);

    /* always cleanup */
    if (headers != NULL) curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  if (out_f) fclose(out_f);

  return (ret);
}

/* **************************************** */

long Utils::httpGet(const char *url,
                    /* NOTE if user_header_token != NULL, username AND password
                       are ignored, and vice-versa */
                    const char *username, const char *password,
                    const char *user_header_token, int timeout,
                    char *const resp, const u_int resp_len) {
  CURL *curl = curl_easy_init();
  long response_code = 0;
  char tokenBuffer[64];

  if (curl) {
    struct curl_slist *headers = NULL;
    char *content_type;
    char ua[64];
    curl_fetcher_t fetcher = {/* .payload =  */ resp,
                              /* .cur_size = */ 0,
                              /* .max_size = */ resp_len};

    fillcURLProxy(curl);

    curl_easy_setopt(curl, CURLOPT_URL, url);

    if (user_header_token == NULL) {
      if (username || password) {
        char auth[64];

        snprintf(auth, sizeof(auth), "%s:%s", username ? username : "",
                 password ? password : "");
        curl_easy_setopt(curl, CURLOPT_USERPWD, auth);
        curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
      }
    } else {
      snprintf(tokenBuffer, sizeof(tokenBuffer), "Authorization: Token %s",
               user_header_token);
      headers = curl_slist_append(headers, tokenBuffer);
    }

    if (headers != NULL) curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    if (!strncmp(url, "https", 5) && ntop->getPrefs()->do_insecure_tls()) {
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    if (resp && resp_len) {
      curl_easy_setopt(curl, CURLOPT_WRITEDATA, &fetcher);
      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_get_writefunc);
    }

    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, timeout);

#ifdef CURLOPT_CONNECTTIMEOUT_MS
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout * 1000);
#endif

    snprintf(ua, sizeof(ua), "%s [%s][%s]", PACKAGE_STRING, PACKAGE_MACHINE,
             PACKAGE_OS);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, ua);

    if (curl_easy_perform(curl) == CURLE_OK) {
      if ((curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &content_type) !=
           CURLE_OK) ||
          (curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code) !=
           CURLE_OK))
        response_code = 0;
    }

    /* always cleanup */
    if (headers != NULL) curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }

  return response_code;
}

/* **************************************** */

char *Utils::getURL(char *url, char *buf, u_int buf_len) {
  struct stat s;

  if (!ntop->getPrefs()->is_pro_edition()) return (url);

  snprintf(buf, buf_len, "%s/lua/pro%s",
           ntop->get_HTTPserver()->get_scripts_dir(), &url[4]);

  ntop->fixPath(buf);
  if ((stat(buf, &s) == 0) && (S_ISREG(s.st_mode))) {
    u_int l = strlen(ntop->get_HTTPserver()->get_scripts_dir());
    char *new_url = &buf[l];

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "===>>> %s", new_url);
    return (new_url);
  } else
    return (url);
}

/* **************************************************** */

/* URL encodes the given string. The caller must free the returned string after
 * use. */
char *Utils::urlEncode(const char *url) {
  CURL *curl;

  if (url) {
    curl = curl_easy_init();

    if (curl) {
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
  str->s = (char *)malloc((str->l) + 1);
  if (str->s == NULL) {
    fprintf(stderr, "ERROR: malloc() failed!\n");
    exit(EXIT_FAILURE);
  } else {
    str->s[0] = '\0';
  }
  return;
}
#endif

/* **************************************** */

ticks Utils::getticks() {
#ifdef WIN32
  struct timeval tv;
  gettimeofday(&tv, 0);

  return (((ticks)tv.tv_usec) + (((ticks)tv.tv_sec) * 1000000LL));
#else
#if defined(__i386__)
  ticks x;

  __asm__ volatile(".byte 0x0f, 0x31" : "=A"(x));
  return x;
#elif defined(__x86_64__)
  u_int32_t a, d;

  asm volatile("rdtsc" : "=a"(a), "=d"(d));
  return (((ticks)a) | (((ticks)d) << 32));

  /*
    __asm __volatile("rdtsc" : "=A" (x));
    return (x);
  */
#else /* ARM, MIPS.... (not very fast) */
  struct timeval tv;
  gettimeofday(&tv, 0);

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
  if (ret == 0) ret = 1; /* Avoid invalid values */

  return (ret);
#else
  return CLOCKS_PER_SEC;
#endif
}

/* **************************************** */

static bool scan_dir(const char *dir_name,
                     list<pair<struct dirent *, char *> > *dirlist,
                     unsigned long *total) {
  int path_length;
  char path[MAX_PATH + 2];
  DIR *d;
  struct stat buf;

  d = opendir(dir_name);
  if (!d) return false;

  while (1) {
    struct dirent *entry;
    const char *d_name;

    entry = readdir(d);
    if (!entry) break;
    d_name = entry->d_name;

    if (entry->d_type & DT_REG) {
      snprintf(path, sizeof(path), "%s/%s", dir_name, entry->d_name);
      if (!stat(path, &buf)) {
        struct dirent *temp = (struct dirent *)malloc(sizeof(struct dirent));
        memcpy(temp, entry, sizeof(struct dirent));
        dirlist->push_back(make_pair(temp, strndup(path, MAX_PATH)));
        if (total) *total += buf.st_size;
      }

    } else if (entry->d_type & DT_DIR) {
      if (strncmp(d_name, "..", 2) != 0 && strncmp(d_name, ".", 1) != 0) {
        path_length = snprintf(path, MAX_PATH, "%s/%s", dir_name, d_name);

        if (path_length >= MAX_PATH) return false;

        scan_dir(path, dirlist, total);
      }
    }
  }

  if (closedir(d)) return false;

  return true;
}

/* **************************************** */

bool file_mtime_compare(const pair<struct dirent *, char *> &d1,
                        const pair<struct dirent *, char *> &d2) {
  struct stat sa, sb;

  if (!d1.second || !d2.second) return false;

  if (stat(d1.second, &sa) || stat(d2.second, &sb)) return false;

  return difftime(sa.st_mtime, sb.st_mtime) <= 0;
}

/* **************************************** */

bool Utils::discardOldFilesExceeding(const char *path,
                                     const unsigned long max_size) {
  unsigned long total = 0;
  list<pair<struct dirent *, char *> > fileslist;
  list<pair<struct dirent *, char *> >::iterator it;
  struct stat st;

  if (path == NULL || !strncmp(path, "", MAX_PATH)) return false;

  /* First, get a list of all non-dir dirents and compute total size */
  if (!scan_dir(path, &fileslist, &total)) return false;

  // printf("path: %s, total: %u, max_size: %u\n", path, total, max_size);

  if (total < max_size) return true;

  fileslist.sort(file_mtime_compare);

  /* Third, traverse list and delete until we go below quota */
  for (it = fileslist.begin(); it != fileslist.end(); ++it) {
    // printf("[file: %s][path: %s]\n", it->first->d_name, it->second);
    if (!it->second) continue;

    stat(it->second, &st);
    unlink(it->second);

    total -= st.st_size;
    if (total < max_size) break;
  }

  for (it = fileslist.begin(); it != fileslist.end(); ++it) {
    if (it->first) free(it->first);
    if (it->second) free(it->second);
  }

  return true;
}

/* **************************************** */

/* Format MAC address to string */
char *Utils::formatMacAddress(const u_int8_t *const mac, char *buf, u_int buf_len) {
  if (mac == NULL)
    buf[0] = '\0';
  else
    snprintf(buf, buf_len, "%02X:%02X:%02X:%02X:%02X:%02X", mac[0] & 0xFF,
             mac[1] & 0xFF, mac[2] & 0xFF, mac[3] & 0xFF, mac[4] & 0xFF,
             mac[5] & 0xFF);
  return (buf);
}

/* **************************************** */

/* Format host MAC in case of getHostMask() = no_host_mask */
char *Utils::formatMac(const u_int8_t *const mac, char *buf, u_int buf_len) {
  if (ntop->getPrefs()->getHostMask() != no_host_mask) {
    snprintf(buf, buf_len, "00:00:00:00:00:00");
    return buf;
  }
  return Utils::formatMacAddress(mac, buf, buf_len);
}

/* **************************************** */

u_int64_t Utils::encodeMacTo64(u_int8_t mac[6]) {
  u_int64_t m = 0;
  memcpy(&m, mac, 6);
  return (m);
}

/* **************************************** */

void Utils::decode64ToMac(u_int64_t mac64, u_int8_t mac[6] /* out */) {
  memcpy(mac, &mac64, 6);
}

/* **************************************** */

u_int64_t Utils::macaddr_int(const u_int8_t *mac) {
  if (mac == NULL)
    return (0);
  else {
    u_int64_t mac_int = 0;

    for (u_int8_t i = 0; i < 6; i++) {
      mac_int |= ((u_int64_t)(mac[i] & 0xFF)) << (5 - i) * 8;
    }

    return mac_int;
  }
}

/* **************************************** */

void Utils::readMac(const char *_ifname, dump_mac_t mac_addr) {
#if defined(__linux__) || defined(__FreeBSD__) || defined(__APPLE__)
  char ifname[15];
  macstr_t mac_addr_buf;
  int res;

  ifname2devname(_ifname, ifname, sizeof(ifname));

#if defined(__FreeBSD__) || defined(__APPLE__)
  struct ifaddrs *ifap, *ifaptr;
  unsigned char *ptr;

  if ((res = getifaddrs(&ifap)) == 0) {
    for (ifaptr = ifap; ifaptr != NULL; ifaptr = ifaptr->ifa_next) {
      if (!strcmp(ifaptr->ifa_name, ifname) &&
          (ifaptr->ifa_addr->sa_family == AF_LINK)) {
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

  memset(&ifr, 0, sizeof(struct ifreq));

  /* Dummy socket, just to make ioctls with */
  _sock = Utils::openSocket(PF_INET, SOCK_DGRAM, 0, "readMac");
  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);

  if ((res = ioctl(_sock, SIOCGIFHWADDR, &ifr)) >= 0)
    memcpy(mac_addr, ifr.ifr_ifru.ifru_hwaddr.sa_data, 6);

  Utils::closeSocket(_sock);
#endif

  if (res < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot get hw addr for %s",
                                 ifname);
  else
    ntop->getTrace()->traceEvent(
        TRACE_INFO, "Interface %s has MAC %s", ifname,
        formatMac((u_int8_t *)mac_addr, mac_addr_buf, sizeof(mac_addr_buf)));
#else
  char ebuf[PCAP_ERRBUF_SIZE];
  pcap_if_t *pdevs, *pdev;
  bool found = false;

  memset(mac_addr, 0, 6);

  if (pcap_findalldevs(&pdevs, ebuf) == 0) {
    pdev = pdevs;
    while (pdev != NULL) {
      if (Utils::validInterface(pdev) && Utils::isInterfaceUp(pdev->name)) {
	if (strstr(pdev->name, _ifname) != NULL) {
	  memcpy(mac_addr, pdev->addresses->addr->sa_data, 6);
	  break;
	}
      }
      pdev = pdev->next;
    }

    pcap_freealldevs(pdevs);
  }
#endif
}

/* **************************************** */

u_int32_t Utils::readIPv4(char *ifname) {
  u_int32_t ret_ip = 0;

#ifndef WIN32
  struct ifreq ifr;
  int fd;

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
  ifr.ifr_addr.sa_family = AF_INET;

  if ((fd = Utils::openSocket(AF_INET, SOCK_DGRAM, IPPROTO_IP, "readIPv4")) <
      0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
  } else {
    if (ioctl(fd, SIOCGIFADDR, &ifr) == -1)
      ntop->getTrace()->traceEvent(TRACE_INFO,
                                   "Unable to read IPv4 for device %s", ifname);
    else
      ret_ip = (((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr).s_addr;

    Utils::closeSocket(fd);
  }
#endif

  return (ret_ip);
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
  if (f == NULL) return (false);

  while (19 == fscanf(f,
                      " %2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%"
                      "2hhx%2hhx%2hhx%2hhx%2hhx%2hhx %*x %x %x %*x %s",
                      &ipv6[0], &ipv6[1], &ipv6[2], &ipv6[3], &ipv6[4],
                      &ipv6[5], &ipv6[6], &ipv6[7], &ipv6[8], &ipv6[9],
                      &ipv6[10], &ipv6[11], &ipv6[12], &ipv6[13], &ipv6[14],
                      &ipv6[15], &prefix, &scope, dname)) {
    if (strcmp(ifname, dname) != 0) continue;

    if (scope == 0x0000U /* IPV6_ADDR_GLOBAL */) {
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
  struct stat buf;

  /* Check if this is a pcap file */
  if(stat(ifname, &buf) == 0)
    return(CONST_MAX_PACKET_SIZE);

#ifdef WIN32
  return (CONST_DEFAULT_MAX_PACKET_SIZE);
#else
  struct ifreq ifr;
  u_int32_t max_packet_size = CONST_DEFAULT_MAX_PACKET_SIZE; /* default */
  int fd;

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
  ifr.ifr_addr.sa_family = AF_INET;

  if ((fd = Utils::openSocket(AF_INET, SOCK_DGRAM, 0, "getIfMTU")) < 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
  } else {
    if (ioctl(fd, SIOCGIFMTU, &ifr) == -1) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read MTU for device %s", ifname);
    } else {
      max_packet_size = ifr.ifr_mtu + sizeof(struct ndpi_ethhdr) + sizeof(Ether80211q);

      if (max_packet_size > ((u_int16_t)-1)) max_packet_size = ((u_int16_t)-1);
    }

    Utils::closeSocket(fd);
  }

  return ((u_int16_t)max_packet_size);
#endif
}

/* **************************************** */

u_int32_t Utils::getMaxIfSpeed(const char *_ifname) {
#if defined(__linux__) && \
    (!defined(__GNUC_RH_RELEASE__) || (__GNUC_RH_RELEASE__ != 44))
  int sock, rc;
  struct ifreq ifr;
  struct ethtool_cmd edata;
  u_int32_t ifSpeed = 1000;
  char ifname[15];

  if (strchr(_ifname, ',')) {
    /* These are interfaces with , (e.g. eth0,eth1) */
    char ifaces[128], *iface, *tmp;
    u_int32_t speed = 0;

    snprintf(ifaces, sizeof(ifaces), "%s", _ifname);
    iface = strtok_r(ifaces, ",", &tmp);

    while (iface) {
      u_int32_t thisSpeed;

      ifname2devname(iface, ifname, sizeof(ifname));

      thisSpeed = getMaxIfSpeed(ifname);
      if (thisSpeed > speed) speed = thisSpeed;

      iface = strtok_r(NULL, ",", &tmp);
    }

    return (speed);
  } else {
    ifname2devname(_ifname, ifname, sizeof(ifname));
  }

  memset(&ifr, 0, sizeof(struct ifreq));

  sock = Utils::openSocket(PF_INET, SOCK_DGRAM, 0, "getMaxIfSpeed");
  if (sock < 0) {
    // ntop->getTrace()->traceEvent(TRACE_ERROR, "Socket error [%s]", ifname);
    return (ifSpeed);
  }

  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
  ifr.ifr_data = (char *)&edata;

  // Do the work
  edata.cmd = ETHTOOL_GSET;

  rc = ioctl(sock, SIOCETHTOOL, &ifr);
  Utils::closeSocket(sock);

  if (rc < 0) {
    // ntop->getTrace()->traceEvent(TRACE_ERROR, "I/O Control error [%s]",
    // ifname);
    return (ifSpeed);
  }

  if ((int32_t)ethtool_cmd_speed(&edata) != SPEED_UNKNOWN)
    ifSpeed = ethtool_cmd_speed(&edata);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Interface %s has MAC Speed = %u",
                               ifname, edata.speed);

  return (ifSpeed);
#else
  return (1000);
#endif
}

/* **************************************** */

int Utils::ethtoolGet(const char *ifname, int cmd, uint32_t *v) {
#if defined(__linux__)
  struct ifreq ifr;
  struct ethtool_value ethv;
  int fd;

  memset(&ifr, 0, sizeof(ifr));

  fd = Utils::openSocket(AF_INET, SOCK_DGRAM, 0, "ethtoolGet");

  if (fd == -1) return -1;

  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);

  ethv.cmd = cmd;
  ifr.ifr_data = (char *)&ethv;

  if (ioctl(fd, SIOCETHTOOL, (char *)&ifr) < 0) {
    Utils::closeSocket(fd);
    return -1;
  }

  *v = ethv.data;
  Utils::closeSocket(fd);

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

  fd = Utils::openSocket(AF_INET, SOCK_DGRAM, 0, "ethtoolSet");

  if (fd == -1) return -1;

  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);

  ethv.cmd = cmd;
  ethv.data = v;
  ifr.ifr_data = (char *)&ethv;

  if (ioctl(fd, SIOCETHTOOL, (char *)&ifr) < 0) {
    Utils::closeSocket(fd);
    return -1;
  }

  Utils::closeSocket(fd);

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
  if (Utils::ethtoolGet(ifname, ETHTOOL_GGRO, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_SGRO, 0);
#endif

#ifdef ETHTOOL_GGSO
  if (Utils::ethtoolGet(ifname, ETHTOOL_GGSO, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_SGSO, 0);
#endif

#ifdef ETHTOOL_GTSO
  if (Utils::ethtoolGet(ifname, ETHTOOL_GTSO, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_STSO, 0);
#endif

#ifdef ETHTOOL_GSG
  if (Utils::ethtoolGet(ifname, ETHTOOL_GSG, &v) == 0 && v != 0)
    Utils::ethtoolSet(ifname, ETHTOOL_SSG, 0);
#endif

#ifdef ETHTOOL_GFLAGS
  if (Utils::ethtoolGet(ifname, ETHTOOL_GFLAGS, &v) == 0 && (v & ETH_FLAG_LRO))
    Utils::ethtoolSet(ifname, ETHTOOL_SFLAGS, v & ~ETH_FLAG_LRO);
#endif

  return 0;
#else
  return -1;
#endif
}

/* **************************************** */

bool Utils::isGoodNameToCategorize(char *name) {
  if ((name[0] == '\0') || (strchr(name, '.') == NULL) /* Missing domain */
      || (!strcmp(name, "Broadcast")) || (!strcmp(name, "localhost")) ||
      strchr((const char *)name, ':') /* IPv6 */
      || (strstr(name, "in-addr.arpa")) || (strstr(name, "ip6.arpa")) ||
      (strstr(name, "_dns-sd._udp")))
    return (false);
  else
    return (true);
}

/* **************************************** */

char *Utils::get2ndLevelDomain(char *_domainname) {
  int i, found = 0;

  for (i = (int)strlen(_domainname) - 1, found = 0; (found != 2) && (i > 0);
       i--) {
    if (_domainname[i] == '.') {
      found++;

      if (found == 2) {
        return (&_domainname[i + 1]);
      }
    }
  }

  return (_domainname);
}

/* ****************************************************** */

char *Utils::tokenizer(char *arg, int c, char **data) {
  char *p = NULL;

  if ((p = strchr(arg, c)) != NULL) {
    *p = '\0';
    if (data) {
      if (strlen(arg))
        *data = strdup(arg);
      else
        *data = strdup("");
    }

    arg = &(p[1]);
  } else if (data) {
    if (arg)
      *data = strdup(arg);
    else
      *data = NULL;
  }

  return (arg);
}

/* ****************************************************** */

in_addr_t Utils::inet_addr(const char *cp) {
  if ((cp == NULL) || (cp[0] == '\0'))
    return (0);
  else
    return (::inet_addr(cp));
}

/* ****************************************************** */

char *Utils::intoaV4(unsigned int addr, char *buf, u_short bufLen) {
  char *cp;
  int n;

  cp = &buf[bufLen];
  *--cp = '\0';

  n = 4;
  do {
    u_int byte = addr & 0xff;

    *--cp = byte % 10 + '0';
    byte /= 10;
    if (byte > 0) {
      *--cp = byte % 10 + '0';
      byte /= 10;
      if (byte > 0) *--cp = byte + '0';
    }
    if (n > 1) *--cp = '.';
    addr >>= 8;
  } while (--n > 0);

  return (cp);
}

/* ****************************************************** */

char *Utils::intoaV6(struct ndpi_in6_addr ipv6, u_int8_t bitmask, char *buf,
                     u_short bufLen) {
  char *ret;

  for (int32_t i = bitmask, j = 0; i > 0; i -= 8, ++j)
    ipv6.u6_addr.u6_addr8[j] &=
        i >= 8 ? 0xff : (u_int32_t)((0xffU << (8 - i)) & 0xffU);

  ret = (char *)inet_ntop(AF_INET6, &ipv6, buf, bufLen);

  if (ret == NULL) {
    /* Internal error (buffer too short) */
    buf[0] = '\0';
    return (buf);
  } else
    return (ret);
}

/* ****************************************************** */

void Utils::xor_encdec(u_char *data, int data_len, u_char *key) {
  int i, y;

  for (i = 0, y = 0; i < data_len; i++) {
    data[i] ^= key[y++];
    if (key[y] == 0) y = 0;
  }
}

/* ****************************************************** */

u_int32_t Utils::macHash(const u_int8_t *const mac) {
  if (mac == NULL)
    return (0);
  else {
    u_int32_t hash = 0;

    for (int i = 0; i < 6; i++) hash += mac[i] << (i + 1);

    return (hash);
  }
}

/* ****************************************************** */

bool Utils::isEmptyMac(const u_int8_t *const mac) {
  static const u_int8_t zero[6] = {0, 0, 0, 0, 0, 0};

  return (memcmp(mac, zero, 6) == 0);
}

/* ****************************************************** */

/* https://en.wikipedia.org/wiki/Multicast_address */
/* https://hwaddress.com/company/private */
bool Utils::isSpecialMac(u_int8_t *mac) {
  if (isEmptyMac(mac))
    return (true);
  else {
    u_int16_t v2 = (mac[0] << 8) + mac[1];
    u_int32_t v3 = (mac[0] << 16) + (mac[1] << 8) + mac[2];

    switch (v3) {
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
        return (true);
    }

    switch (v2) {
      case 0xFFFF:
      case 0x3333:
        return (true);
        break;
    }

    return (false);
  }
}

/* ****************************************************** */

bool Utils::isBroadcastMac(const u_int8_t *mac) {
  u_int8_t broad[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

  return (memcmp(mac, broad, 6) == 0);
}

/* ****************************************************** */

/*
  http://h22208.www2.hpe.com/eginfolib/networking/docs/switches/5130ei/5200-3944_ip-multi_cg/content/483573739.htm
  https://ipcisco.com/lesson/multicast-mac-addresses/
*/
bool Utils::isMulticastMac(const u_int8_t *mac) {
  if (isEmptyMac(mac)) return (false);

  if (((mac[0] == 0x33) && (mac[1] == 0x33)) ||
      ((mac[0] == 0x01) && (mac[1] == 0x00) && (mac[2] == 0x5E)))
    return (true);
  else
    return (false);
}

/* ****************************************************** */

void Utils::parseMac(u_int8_t *mac, const char *symMac) {
  int _mac[6] = {0};

  if (symMac)
    sscanf(symMac, "%x:%x:%x:%x:%x:%x", &_mac[0], &_mac[1], &_mac[2], &_mac[3],
           &_mac[4], &_mac[5]);

  for (int i = 0; i < 6; i++) mac[i] = (u_int8_t)_mac[i];
}

/* *********************************************** */

ndpi_patricia_node_t *Utils::add_to_ptree(ndpi_patricia_tree_t *tree,
                                          int family, void *addr, int bits) {
  ndpi_prefix_t prefix;
  ndpi_patricia_node_t *node;
  u_int16_t maxbits = ndpi_patricia_get_maxbits(tree);

  if (family == AF_INET)
    ndpi_fill_prefix_v4(&prefix, (struct in_addr *)addr, bits, maxbits);
  else if (family == AF_INET6)
    ndpi_fill_prefix_v6(&prefix, (struct in6_addr *)addr, bits, maxbits);
  else
    ndpi_fill_prefix_mac(&prefix, (u_int8_t *)addr, bits, maxbits);

  node = ndpi_patricia_lookup(tree, &prefix);

  return (node);
}

/* ******************************************* */

ndpi_patricia_node_t *Utils::ptree_match(ndpi_patricia_tree_t *tree, int family,
                                         const void *const addr, int bits) {
  ndpi_prefix_t prefix;
  u_int16_t maxbits = ndpi_patricia_get_maxbits(tree);

  if (addr == NULL) return (NULL);

  if (family == AF_INET)
    ndpi_fill_prefix_v4(&prefix, (struct in_addr *)addr, bits, maxbits);
  else if (family == AF_INET6)
    ndpi_fill_prefix_v6(&prefix, (struct in6_addr *)addr, bits, maxbits);
  else
    ndpi_fill_prefix_mac(&prefix, (u_int8_t *)addr, bits, maxbits);

  if (prefix.bitlen > maxbits) { /* safety check */
    char buf[128];
    ntop->getTrace()->traceEvent(
        TRACE_ERROR,
        "Bad radix tree lookup for %s "
        "(prefix family = %u, len = %u (%u), tree max len = %u)",
        Utils::ptree_prefix_print(&prefix, buf, sizeof(buf)) ? buf : "-",
        family, prefix.bitlen, bits, maxbits);
    return NULL;
  }

  return (ndpi_patricia_search_best(tree, &prefix));
}

/* ******************************************* */

ndpi_patricia_node_t *Utils::ptree_add_rule(ndpi_patricia_tree_t *ptree,
                                            const char *addr_line) {
  char *ip, *bits, *slash = NULL, *line = NULL;
  struct in_addr addr4;
  struct in6_addr addr6;
  u_int8_t mac[6];
  u_int32_t _mac[6];
  ndpi_patricia_node_t *node = NULL;

  line = strdup(addr_line);

  /* Remove heading/trailer  []  if present */
  if(line[0] == '[') {
    int len = strlen(line);

    if(len > 0) line[len-1] = '\0';

    ip = &line[1];
  } else
    ip = line;

  bits = strchr(line, '/');
  if (bits == NULL)
    bits = (char *)"/32";
  else {
    slash = bits;
    slash[0] = '\0';
  }

  bits++;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Rule %s/%s", ip, bits);

  if (sscanf(ip, "%02X:%02X:%02X:%02X:%02X:%02X", &_mac[0], &_mac[1], &_mac[2],
             &_mac[3], &_mac[4], &_mac[5]) == 6) {
    for (int i = 0; i < 6; i++) mac[i] = _mac[i];
    node = add_to_ptree(ptree, AF_MAC, mac, 48);
  } else if (strchr(ip, ':') != NULL) { /* IPv6 */
    if (inet_pton(AF_INET6, ip, &addr6) == 1)
      node = add_to_ptree(ptree, AF_INET6, &addr6, atoi(bits));
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv6 %s\n", ip);
  } else { /* IPv4 */
    /* inet_aton(ip, &addr4) fails parsing subnets */
    int num_octets;
    u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
    u_char *ip4 = (u_char *)&addr4;

    if ((num_octets =
             sscanf(ip, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3)) >= 1) {
      int num_bits = atoi(bits);

      ip4[0] = ip4_0, ip4[1] = ip4_1, ip4[2] = ip4_2, ip4[3] = ip4_3;

      if (num_bits > 32) num_bits = 32;

      if (num_octets * 8 < num_bits)
        ntop->getTrace()->traceEvent(
            TRACE_INFO, "Found IP smaller than netmask [%s]", line);

      // addr4.s_addr = ntohl(addr4.s_addr);
      node = add_to_ptree(ptree, AF_INET, &addr4, num_bits);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv4 %s\n", ip);
    }
  }

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Added IPv%d rule %s/%s [%p]",
  // isV4 ? 4 : 6, ip, bits, node);

  if (line) free(line);
  return (node);
}

/* ******************************************* */

bool Utils::ptree_prefix_print(ndpi_prefix_t *prefix, char *buffer,
                               size_t bufsize) {
  char *a, ipbuf[64];

  switch (prefix->family) {
    case AF_INET:
      a = Utils::intoaV4(ntohl(prefix->add.sin.s_addr), ipbuf, sizeof(ipbuf));
      snprintf(buffer, bufsize, "%s/%d", a, prefix->bitlen);
      return (true);

    case AF_INET6:
      a = Utils::intoaV6(*((struct ndpi_in6_addr *)&prefix->add.sin6),
                         prefix->bitlen, ipbuf, sizeof(ipbuf));
      snprintf(buffer, bufsize, "%s/%d", a, prefix->bitlen);
      return (true);
  }

  return (false);
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

void Utils::initRedis(Redis **r, const char *redis_host,
                      const char *redis_password, u_int16_t redis_port,
                      u_int8_t _redis_db_id, bool giveup_on_failure) {
  if (r) {
    if (*r) delete (*r);
    (*r) = new (std::nothrow) Redis(redis_host, redis_password, redis_port,
                                    _redis_db_id, giveup_on_failure);
  }
}

/* ******************************************* */

int Utils::tcpStateStr2State(const char *state_str) {
  map<string, int>::const_iterator it;

  if ((it = tcp_state_str_2_state.find(state_str)) !=
      tcp_state_str_2_state.end())
    return it->second;

  return 0;
}

/* ******************************************* */

const char *Utils::tcpState2StateStr(int state) {
  map<int, string>::const_iterator it;

  if ((it = tcp_state_2_state_str.find(state)) != tcp_state_2_state_str.end())
    return it->second.c_str();

  return "UNKNOWN";
}

/* ******************************************* */

eBPFEventType Utils::eBPFEventStr2Event(const char *event_str) {
  map<string, eBPFEventType>::const_iterator it;

  if ((it = ebpf_event_str_2_event.find(event_str)) !=
      ebpf_event_str_2_event.end())
    return it->second;

  return ebpf_event_type_unknown;
}

/* ******************************************* */

const char *Utils::eBPFEvent2EventStr(eBPFEventType event) {
  map<eBPFEventType, string>::const_iterator it;

  if ((it = ebpf_event_2_event_str.find(event)) != ebpf_event_2_event_str.end())
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

  if ((sp = strstr(line, search)) == NULL) {
    return;
  }

  search_len = strlen(search), replace_len = strlen(replace);
  tail_len = strlen(sp + search_len);

  memmove(sp + replace_len, sp + search_len, tail_len + 1);
  memcpy(sp, replace, replace_len);
}

/* ****************************************************** */

u_int32_t Utils::stringHash(const char *s) {
  u_int32_t hash = 0;
  const char *p = s;
  int pos = 0;

  while (*p) {
    hash += (*p) << pos;
    p++;
    pos += 8;
    if (pos == 32) pos = 0;
  }

  return hash;
}

/* ****************************************************** */

/* Note: the returned IP address is in network byte order */
u_int32_t Utils::getHostManagementIPv4Address() {
  int sock =
      Utils::openSocket(AF_INET, SOCK_DGRAM, 0, "getHostManagementIPv4Address");
  const char *kGoogleDnsIp = "8.8.8.8";
  u_int16_t kDnsPort = 53;
  struct sockaddr_in serv;
  struct sockaddr_in name;
  socklen_t namelen = sizeof(name);
  u_int32_t me;

  memset(&serv, 0, sizeof(serv));
  serv.sin_family = AF_INET;
  serv.sin_addr.s_addr = inet_addr(kGoogleDnsIp);
  serv.sin_port = htons(kDnsPort);

  if ((connect(sock, (const struct sockaddr *)&serv, sizeof(serv)) == 0) &&
      (getsockname(sock, (struct sockaddr *)&name, &namelen) == 0)) {
    me = name.sin_addr.s_addr;
  } else
    me = inet_addr("127.0.0.1");

  Utils::closeSocket(sock);

  return (me);
}

/* ****************************************************** */

bool Utils::isInterfaceUp(char *_ifname) {
#ifdef WIN32
  return (true);
#else
  char ifname[IFNAMSIZ];
  struct ifreq ifr;
  int sock;

  sock = Utils::openSocket(PF_INET, SOCK_DGRAM, IPPROTO_IP, "isInterfaceUp");

  if (sock == -1) return (false);

  ifname2devname(_ifname, ifname, sizeof(ifname));

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);

  if (ioctl(sock, SIOCGIFFLAGS, &ifr) < 0) {
    Utils::closeSocket(sock);
    return (false);
  }

  Utils::closeSocket(sock);

  return (!!(ifr.ifr_flags & IFF_UP) ? true : false);
#endif
}

/* ****************************************************** */

bool Utils::maskHost(bool isLocalIP) {
  bool mask_host = false;

  switch (ntop->getPrefs()->getHostMask()) {
    case mask_local_hosts:
      if (isLocalIP) mask_host = true;
      break;

    case mask_remote_hosts:
      if (!isLocalIP) mask_host = true;
      break;

    default:
      break;
  }

  return (mask_host);
}

/* ****************************************************** */

bool Utils::getCPULoad(cpu_load_stats *out) {
#if !defined(__FreeBSD__) && !defined(__NetBSD__) & !defined(__OpenBSD__) && \
    !defined(__APPLE__) && !defined(WIN32)
  float load;
  FILE *fp;

  if ((fp = fopen("/proc/loadavg", "r"))) {
    if (fscanf(fp, "%f", &load) != 1) load = 0;
    fclose(fp);

    out->load = load;

    return (true);
  }
#endif

  return (false);
};

/* ****************************************************** */

void Utils::luaMeminfo(lua_State *vm) {
#if !defined(__FreeBSD__) && !defined(__NetBSD__) & !defined(__OpenBSD__) && \
    !defined(__APPLE__) && !defined(WIN32)
  long unsigned int memtotal = 0, memfree = 0, buffers = 0, cached = 0,
                    sreclaimable = 0, shmem = 0;
  long unsigned int mem_resident = 0, mem_virtual = 0;
  char *line = NULL;
  size_t len;
  int read;
  FILE *fp;

  if (vm) {
    if ((fp = fopen("/proc/meminfo", "r"))) {
      while ((read = getline(&line, &len, fp)) != -1) {
        if (!strncmp(line, "MemTotal", strlen("MemTotal")) &&
            sscanf(line, "%*s %lu kB", &memtotal))
          lua_push_uint64_table_entry(vm, "mem_total", memtotal);
        else if (!strncmp(line, "MemFree", strlen("MemFree")) &&
                 sscanf(line, "%*s %lu kB", &memfree))
          lua_push_uint64_table_entry(vm, "mem_free", memfree);
        else if (!strncmp(line, "Buffers", strlen("Buffers")) &&
                 sscanf(line, "%*s %lu kB", &buffers))
          lua_push_uint64_table_entry(vm, "mem_buffers", buffers);
        else if (!strncmp(line, "Cached", strlen("Cached")) &&
                 sscanf(line, "%*s %lu kB", &cached))
          lua_push_uint64_table_entry(vm, "mem_cached", cached);
        else if (!strncmp(line, "SReclaimable", strlen("SReclaimable")) &&
                 sscanf(line, "%*s %lu kB", &sreclaimable))
          lua_push_uint64_table_entry(vm, "mem_sreclaimable", sreclaimable);
        else if (!strncmp(line, "Shmem", strlen("Shmem")) &&
                 sscanf(line, "%*s %lu kB", &shmem))
          lua_push_uint64_table_entry(vm, "mem_shmem", shmem);
      }

      if (line) {
        free(line);
        line = NULL;
      }

      fclose(fp);

      /* Equivalent to top utility mem used */
      lua_push_uint64_table_entry(
          vm, "mem_used",
          memtotal - memfree - (buffers + cached + sreclaimable - shmem));
    }

    if ((fp = fopen("/proc/self/status", "r"))) {
      while ((read = getline(&line, &len, fp)) != -1) {
        if (!strncmp(line, "VmRSS", strlen("VmRSS")) && sscanf(line, "%*s %lu kB", &mem_resident))
          lua_push_uint64_table_entry(vm, "mem_ntopng_resident", mem_resident);

        else if (!strncmp(line, "VmSize", strlen("VmSize")) && sscanf(line, "%*s %lu kB", &mem_virtual))
          lua_push_uint64_table_entry(vm, "mem_ntopng_virtual", mem_virtual);
      }

      if (line) {
        free(line);
        line = NULL;
      }

      fclose(fp);
    }
  }
#endif
};

/* ****************************************************** */

char *Utils::getInterfaceDescription(char *ifname, char *buf, int buf_len) {
  ntop_if_t *devpointer, *cur;

  snprintf(buf, buf_len, "%s", ifname);

  if (!Utils::ntop_findalldevs(&devpointer)) {
    for (cur = devpointer; cur; cur = cur->next) {
      if (strcmp(cur->name, ifname) == 0) {
        if (cur->description && cur->description[0])
          snprintf(buf, buf_len, "%s", cur->description);
        break;
      }
    }

    Utils::ntop_freealldevs(devpointer);
  }

  return (buf);
}

/* ****************************************************** */

int Utils::bindSockToDevice(int sock, int family, const char *devicename) {
#ifdef WIN32
  return (0);
#else
  struct ifaddrs *pList = NULL;
  struct ifaddrs *pAdapter = NULL;
  struct ifaddrs *pAdapterFound = NULL;
  int bindresult = -1;

  int result = getifaddrs(&pList);

  if (result < 0) return -1;

  pAdapter = pList;
  while (pAdapter) {
    if ((pAdapter->ifa_addr != NULL) && (pAdapter->ifa_name != NULL) &&
        (family == pAdapter->ifa_addr->sa_family)) {
      if (strcmp(pAdapter->ifa_name, devicename) == 0) {
        pAdapterFound = pAdapter;
        break;
      }
    }

    pAdapter = pAdapter->ifa_next;
  }

  if (pAdapterFound != NULL) {
    int addrsize =
        (family == AF_INET6) ? sizeof(sockaddr_in6) : sizeof(sockaddr_in);
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

  /* (1) Read the current process capabilities */
  caps = cap_get_proc();

  /* (2) Add the capability of interest to the permitted capabilities  */
  /* CAP_PERMITTED: It is a superset for the effective capabilities that the process may assume.
     If the capability is available in this set, a process transitions it to an effective set and drops it later.
     But once a process has dropped capability from the permitted set, it can not re-aquire
  */
  if (cap_set_flag(caps, CAP_PERMITTED, num_cap, cap_values, CAP_SET) == -1)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_set_flag error: %s", strerror(errno));

  /* CAP_INHERITABLE: This set is reserved for execve() syscall. If the capability is set to inheritable,
     it will be added permitted set when the program is executed with execve() syscall */
  if (cap_set_flag(caps, CAP_INHERITABLE, num_cap, cap_values, CAP_SET) == -1)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_set_flag error: %s", strerror(errno));

  /* CAP_EFFECTIVE: Capabilities used by the kernel to perform permission checks for the thread */
  if (cap_set_flag(caps, CAP_EFFECTIVE, num_cap, cap_values, CAP_SET) == -1)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_set_flag error: %s", strerror(errno));

  /* (3) Set the new process capabilities */
  rc = cap_set_proc(caps);
  if (rc == 0) {
#ifdef TRACE_CAPABILITIES
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[CAPABILITIES] INITIAL SETUP [%s][num_cap: %u]",
				 cap_to_text(caps, NULL), num_cap);
#endif

    /* Tell the kernel to retain permitted capabilities */
    if (prctl(PR_SET_KEEPCAPS, 1, 0, 0, 0) != 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to retain permitted capabilities [%s]\n",
				   strerror(errno));
      rc = -1;
    }
  } else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_set_proc error: %s", strerror(errno));
  }

  if (cap_free(caps) == -1)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_free error: %s", strerror(errno));

#else
#if !defined(__APPLE__) && !defined(__FreeBSD__)
  rc = -1;
  ntop->getTrace()->traceEvent(TRACE_WARNING,
                               "ntopng has not been compiled with libcap-dev");
  ntop->getTrace()->traceEvent(TRACE_WARNING,
			       "Network discovery and other privileged activities will fail");
#endif
#endif

  return (rc);
}

/* ****************************************************** */

#if !defined(__APPLE__) && !defined(__FreeBSD__)

static Mutex capabilitiesMutex;

static int _setWriteCapabilities(int enable) {
  int rc = 0;

#ifdef HAVE_LIBCAP
  cap_t caps;

  /*
    NOTE

    The capabilitiesMutex lock is used to avoid that two threads concurrently
    enable/disable capabilities
   */
  if (enable) capabilitiesMutex.lock(__FILE__, __LINE__);

  caps = cap_get_proc();

  if (caps) {
#ifdef TRACE_CAPABILITIES
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "[CAPABILITIES] BEFORE [enable: %u][%s][tid: %u]",
                                 enable, cap_to_text(caps, NULL), gettid());
#endif

    if (cap_set_flag(caps, CAP_EFFECTIVE, num_cap, cap_values, enable ? CAP_SET : CAP_CLEAR) == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Capabilities cap_set_flag error: %s",
                                   strerror(errno));
      rc = -1;
    }

    if (cap_set_proc(caps) == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_set_proc error: %s [enable: %u]",
				   strerror(errno), enable);
       rc = -1;
    } else {
#ifdef TRACE_CAPABILITIES
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "[CAPABILITIES] Capabilities %s [rc: %d]",
                                   enable ? "ENABLE" : "DISABLE", rc);
#endif
    }

#ifdef TRACE_CAPABILITIES
    if(rc != -1)
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "[CAPABILITIES] AFTER  [enable: %u][%s][tid: %u]",
				   enable, cap_to_text(caps, NULL), gettid());
#endif

    if (cap_free(caps) == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_free error");
      rc = -1;
    }
  } else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Capabilities cap_get_proc error");
    rc = -1;
  }

  if (!enable) capabilitiesMutex.unlock(__FILE__, __LINE__);
#else
  rc = -1;
#endif

  return (rc);
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
  if (ntop && !ntop->hasDroppedPrivileges())
    return(-99);

  return (_setWriteCapabilities(true));
#else
  return (0);
#endif
}

/* ****************************************************** */

int Utils::dropWriteCapabilities() {
#if !defined(__APPLE__) && !defined(__FreeBSD__)
  if (ntop && !ntop->hasDroppedPrivileges()) return (0);

  return (_setWriteCapabilities(false));
#else
  return (0);
#endif
}

/* ******************************* */

/* Return IP is network byte order */
u_int32_t Utils::findInterfaceGatewayIPv4(const char *ifname) {
#ifndef WIN32
  char cmd[128];
  FILE *fp;

  snprintf(cmd, sizeof(cmd),
           "netstat -rn | grep '%s' | grep 'UG' | awk '{print $2}'", ifname);

  if ((fp = popen(cmd, "r")) != NULL) {
    char line[256];
    u_int32_t rc = 0;

    if (fgets(line, sizeof(line), fp) != NULL) rc = inet_addr(line);

    pclose(fp);
    return (rc);
  } else
#endif
    return (0);
}

/* ******************************* */

/* Exec the command and returns false in case of error, or true otherwise */
bool Utils::execCmd(char *cmd, std::string *out) {
#ifndef WIN32
  FILE *fp;

  /* Do not start commands during shutdown */
  if(ntop->getGlobals()->isShutdownRequested()) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping command during shutdown (%s)", cmd);
    return(false);
  }

  ntop->getTrace()->traceEvent(TRACE_INFO, "Executing %s", cmd);

  if ((fp = popen(cmd, "r")) != NULL) {
    char line[256], *l;
    int fd = fileno(fp);

    while(!ntop->getGlobals()->isShutdownRequested()) {
      struct timeval ts;
      fd_set rset;
      int ret;

      FD_ZERO(&rset);
      FD_SET(fd, &rset);
      ts.tv_sec = 1, ts.tv_usec = 0;

      ret = select(fd + 1, &rset, NULL, NULL, &ts);

      if(ret < 0)
	break;
      else if(ret > 0) {
	if((l = fgets(line, sizeof(line), fp)) != NULL) {
	  out->append(l);
	  continue;
	} else
	  break;
      }

      ntop->getTrace()->traceEvent(TRACE_INFO, "Sleeping %s", cmd);

      _usleep(100000);
    } /* while */

    if(ntop->getGlobals()->isShutdownRequested())
      ; /* Do not call pclose() otherwise we need to wait until the command ends */
    else
      pclose(fp);

    ntop->getTrace()->traceEvent(TRACE_INFO, "Executed (%s) completed", cmd);
    return(true);
  } else
#endif
    return(false);
}

/* ******************************* */

void Utils::maximizeSocketBuffer(int sock_fd, bool rx_buffer,
                                 u_int max_buf_mb) {
  int i, rcv_buffsize_base, rcv_buffsize,
      max_buf_size = 1024 * max_buf_mb * 1024, debug = 0;
  socklen_t len = sizeof(rcv_buffsize_base);
  int buf_type = rx_buffer ? SO_RCVBUF /* RX */ : SO_SNDBUF /* TX */;

  if (getsockopt(sock_fd, SOL_SOCKET, buf_type, (char *)&rcv_buffsize_base,
                 &len) < 0) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to read socket receiver buffer size [%s]",
        strerror(errno));
    return;
  } else {
    if (debug)
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "Default socket %s buffer size is %d",
          buf_type == SO_RCVBUF ? "receive" : "send", rcv_buffsize_base);
  }

  for (i = 2;; i++) {
    rcv_buffsize = i * rcv_buffsize_base;
    if (rcv_buffsize > max_buf_size) break;

    if (setsockopt(sock_fd, SOL_SOCKET, buf_type, (const char *)&rcv_buffsize,
                   sizeof(rcv_buffsize)) < 0) {
      if (debug)
        ntop->getTrace()->traceEvent(
            TRACE_ERROR, "Unable to set socket %s buffer size [%s]",
            buf_type == SO_RCVBUF ? "receive" : "send", strerror(errno));
      break;
    } else if (debug)
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s socket buffer size set %d",
                                   buf_type == SO_RCVBUF ? "Receive" : "Send",
                                   rcv_buffsize);
  }
}

/* ****************************************************** */

char *Utils::formatTraffic(float numBits, bool bits, char *buf) {
  char unit;

  if (bits)
    unit = 'b';
  else
    unit = 'B';

  if (numBits < 1024) {
    snprintf(buf, 32, "%lu %c", (unsigned long)numBits, unit);
  } else if (numBits < 1048576) {
    snprintf(buf, 32, "%.2f K%c", (float)(numBits) / 1024, unit);
  } else {
    float tmpMBits = ((float)numBits) / 1048576;

    if (tmpMBits < 1024) {
      snprintf(buf, 32, "%.2f M%c", tmpMBits, unit);
    } else {
      tmpMBits /= 1024;

      if (tmpMBits < 1024) {
        snprintf(buf, 32, "%.2f G%c", tmpMBits, unit);
      } else {
        snprintf(buf, 32, "%.2f T%c", (float)(tmpMBits) / 1024, unit);
      }
    }
  }

  return (buf);
}

/* ****************************************************** */

char *Utils::formatPackets(float numPkts, char *buf) {
  if (numPkts < 1000) {
    snprintf(buf, 32, "%.2f", numPkts);
  } else if (numPkts < 1000000) {
    snprintf(buf, 32, "%.2f K", numPkts / 1000);
  } else {
    numPkts /= 1000000;
    snprintf(buf, 32, "%.2f M", numPkts);
  }

  return (buf);
}

/* ****************************************************** */

bool Utils::str2DetailsLevel(const char *details, DetailsLevel *out) {
  bool rv = false;

  if (!strcmp(details, "normal")) {
    *out = details_normal;
    rv = true;
  } else if (!strcmp(details, "high")) {
    *out = details_high;
    rv = true;
  } else if (!strcmp(details, "higher")) {
    *out = details_higher;
    rv = true;
  } else if (!strcmp(details, "max")) {
    *out = details_max;
    rv = true;
  }

  return rv;
}

/* ****************************************************** */

bool Utils::isCriticalNetworkProtocol(u_int16_t protocol_id) {
  return (protocol_id == NDPI_PROTOCOL_DNS) ||
         (protocol_id == NDPI_PROTOCOL_DHCP);
}

/* ****************************************************** */

u_int32_t Utils::roundTime(u_int32_t now, u_int32_t rounder,
                           int32_t offset_from_utc) {
  /* Align result to rounder. Operations intrinsically work in UTC. */
  u_int32_t result = now - (now % rounder);
  result += rounder;

  /* Aling now to localtime using the local offset from UTC.
     So for example UTC+1, which has a +3600 offset from UTC, will have the
     local time one hour behind, that is, 10PM UTC are 9PM UTC+1. For an UTC-1,
     which has a -3600 offset from UTC, the local time is one hour ahead, that
     is, 10PM UTC are 11PM UTC-1. Hence, in practice, a negative offset needs to
     be added whereas a positive offset needs to be substracted. */
  result += -offset_from_utc;

  /* Don't allow results which are earlier than now. Adjust using rounder until
     now is reached. This can happen when result has been adjusted with a
     positive offset from UTC. */
  while (result <= now) result += rounder;

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
  if (!strncmp(str, "now", 3)) {
    char op = str[3];
    int v;
    char what[64];
    u_int32_t ret = time(NULL);

    if (op == '\0')
      return (ret);
    else if (sscanf(&str[4], "%d%s", &v, what) == 2) {
      if (!strcmp(what, "h"))
        v *= 3600;
      else if (!strcmp(what, "d"))
        v *= 3600 * 24;
      else if (!strcmp(what, "w"))
        v *= 3600 * 24 * 7;
      else if (!strcmp(what, "m"))
        v *= 3600 * 24 * 7 * 30;
      else if (!strcmp(what, "min"))
        v *= 60;
      else if (!strcmp(what, "y"))
        v *= 3600 * 24 * 7 * 365;

      if (op == '-')
        ret -= v;
      else
        ret += v;

      return (ret);
    } else
      return (0);
  } else
    return (atol(str));
}

/* ************************************************* */

u_int64_t Utils::mac2int(const u_int8_t *mac) {
  u_int64_t m = 0;

  memcpy(&m, mac, 6);
  return (m);
}

/* ************************************************* */

u_int8_t *Utils::int2mac(u_int64_t mac, u_int8_t *buf) {
  memcpy(buf, &mac, 6);
  buf[6] = buf[7] = '\0';
  return (buf);
}

/* ************************************************* */

void Utils::init_pcap_header(struct pcap_file_header *const h, int linktype,
                             int snaplen, bool nsec) {
  /*
   * [0000000] c3d4 a1b2 0002 0004 0000 0000 0000 0000
   * [0000010] 05ea 0000 0001 0000
   */
  if (!h) return;

  memset(h, 0, sizeof(*h));

  h->magic = nsec ? PCAP_NSEC_MAGIC : PCAP_MAGIC;
  h->version_major = 2;
  h->version_minor = 4;
  h->thiszone = 0;
  h->sigfigs = 0;
  h->snaplen = snaplen;
  h->linktype = linktype;
}

/* ****************************************************** */

void Utils::listInterfaces(lua_State *vm) {
  ntop_if_t *devpointer, *cur;

  if (Utils::ntop_findalldevs(&devpointer) != 0) return; /* Error */

  for (cur = devpointer; cur; cur = cur->next) {
    lua_newtable(vm);

    if (cur->name) {
      struct sockaddr_in sin;
      struct sockaddr_in6 sin6;
      char buf[64];

      if (cur->module) lua_push_str_table_entry(vm, "module", cur->module);

      sin.sin_family = AF_INET;
      sin.sin_addr.s_addr = Utils::readIPv4(cur->name);

      if (sin.sin_addr.s_addr != 0)
        lua_push_str_table_entry(
            vm, "ipv4",
            Utils::intoaV4(ntohl(sin.sin_addr.s_addr), buf, sizeof(buf)));

#ifndef WIN32
      sin6.sin6_family = AF_INET6;
      if (Utils::readIPv6(cur->name, &sin6.sin6_addr)) {
        struct ndpi_in6_addr *ip6 = (struct ndpi_in6_addr *)&sin6.sin6_addr;
        char *ip = Utils::intoaV6(*ip6, 128, buf, sizeof(buf));

        lua_push_str_table_entry(vm, "ipv6", ip);
      }
#endif
    }

    lua_pushstring(vm, cur->name);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  Utils::ntop_freealldevs(devpointer);
}

/* ****************************************************** */

char *Utils::ntop_lookupdev(char *ifname_out, int ifname_size) {
  char ebuf[PCAP_ERRBUF_SIZE];
  pcap_if_t *pdevs, *pdev;
  bool found = false;

  ifname_out[0] = '\0';

  if (pcap_findalldevs(&pdevs, ebuf) != 0) goto err;

  pdev = pdevs;
  while (pdev != NULL) {
    if (Utils::validInterface(pdev) && Utils::isInterfaceUp(pdev->name)) {
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

  if (!alldevsp) return -1;

  *alldevsp = NULL;

  if (pcap_findalldevs(&pdevs, ebuf) != 0) return -1;

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
        || (Utils::isInterfaceUp(pfdev->system_name) &&
            Utils::validInterface(pdev))) {
      cur = (ntop_if_t *)calloc(1, sizeof(ntop_if_t));

      if (cur) {
        cur->name =
            strdup(pfdev->system_name ? pfdev->system_name : pfdev->name);
        cur->description =
            strdup((pdev && pdev->description) ? pdev->description : "");
        cur->module = strdup(pfdev->module);
        cur->license = pfdev->license;

        if (!*alldevsp) *alldevsp = cur;
        if (tail) tail->next = cur;
        tail = cur;
      }
    }

    pfdev = pfdev->next;
  }
#endif

  pdev = pdevs;
  while (pdev != NULL) {
    if (Utils::validInterface(pdev) && Utils::isInterfaceUp(pdev->name)) {
#ifdef HAVE_PF_RING
      /* check if already listed */
      pfdev = pfdevs;
      while (pfdev != NULL) {
        if (strcmp(pfdev->system_name, pdev->name) == 0) break;
        pfdev = pfdev->next;
      }

      if (pfdev == NULL) {
#endif
        cur = (ntop_if_t *)calloc(1, sizeof(ntop_if_t));

        if (cur) {
          cur->name = strdup(pdev->name);
          cur->description = strdup(pdev->description ? pdev->description : "");

          if (!*alldevsp) *alldevsp = cur;
          if (tail) tail->next = cur;
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

  while (alldevsp) {
    cur = alldevsp;
    alldevsp = alldevsp->next;

    if (cur->name) free(cur->name);
    if (cur->description) free(cur->description);
    if (cur->module) free(cur->module);

    free(cur);
  }
}

/* ****************************************************** */

bool Utils::validInterfaceName(const char *name) {
#if not defined(WIN32)
  if (!name || !strncmp(name, "virbr", 5) /* Ignore virtual interfaces */
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
  for (int i = 0; name[i] != '\0'; i++) {
    if (!isalnum(name[i]) && name[i] != '@' && name[i] != '-' &&
        name[i] != ':' && name[i] != '_')
      return false;
  }
#endif

  return true;
}

/* ****************************************************** */

bool Utils::validInterfaceDescription(const char *description) {
  if (description &&
      (strstr(description, "PPP") /* Skip the PPP interface              */
       || strstr(description, "dialup")   /* Skip the dialup interface   */
       || strstr(description, "Miniport") /* Skip the miniport interface */
       ||
       strstr(description, "ICSHARE") /* Skip the internet sharing interface */
       || strstr(description,
                 "NdisWan"))) { /* Skip the internet sharing interface */
    return false;
  }

  return true;
}

/* ****************************************************** */

bool Utils::validInterface(const ntop_if_t *ntop_if) {
  return Utils::validInterfaceName(ntop_if->name) &&
         Utils::validInterfaceDescription(ntop_if->description);
}

/* ****************************************************** */

bool Utils::validInterface(const pcap_if_t *pcap_if) {
  return Utils::validInterfaceName(pcap_if->name) &&
         Utils::validInterfaceDescription(pcap_if->description);
}

/* ****************************************************** */

const char *Utils::policySource2Str(L7PolicySource_t policy_source) {
  switch (policy_source) {
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

const char *Utils::captureDirection2Str(pcap_direction_t dir) {
  switch (dir) {
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

bool Utils::readInterfaceStats(const char *ifname, ProtoStats *in_stats,
                               ProtoStats *out_stats) {
  bool rv = false;
#ifdef __linux__
  FILE *f = fopen("/proc/net/dev", "r");

  if (f) {
    char line[512];
    char to_find[IFNAMSIZ + 2];

    snprintf(to_find, sizeof(to_find), "%s:", ifname);

    while (fgets(line, sizeof(line), f)) {
      long long unsigned int in_bytes, out_bytes, in_packets, out_packets;

      if (strstr(line, to_find) &&
          sscanf(line, "%*[^:]: %llu %llu %*u %*u %*u %*u %*u %*u %llu %llu",
                 &in_bytes, &in_packets, &out_bytes, &out_packets) == 4) {
        ntop->getTrace()->traceEvent(TRACE_DEBUG,
				     "iface_counters: in_bytes=%llu in_packets=%llu - out_bytes=%llu "
				     "out_packets=%llu",
				     in_bytes, in_packets, out_bytes, out_packets);
        in_stats->incBytes(in_bytes), in_stats->incPkts(in_packets),
	  out_stats->incBytes(out_bytes), out_stats->incPkts(out_packets);
        rv = true;
        break;
      }
    }
  }

  if (f) fclose(f);
#endif

  return rv;
}

/* ****************************************************** */

bool Utils::shouldResolveHost(const char *host_ip) {
  if (!ntop->getPrefs()->is_dns_resolution_enabled()) return false;

  if (!ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
    /*
      In case only local addresses need to be resolved, skip
      remote hosts
    */
    IpAddress ip;

    ip.set((char *)host_ip);
    if (!ip.isLocalHost()) return false;
  }

  return true;
}

/* ****************************************************** */

bool Utils::mg_write_retry(struct mg_connection *conn, u_char *b, int len) {
  int ret, sent = 0;
  time_t max_retry = 1000;

  while (!ntop->getGlobals()->isShutdown() && --max_retry) {
    ret = mg_write_async(conn, &b[sent], len - sent);
    if (ret < 0) return false;
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

    if (json_object_object_get_ex(o, "admin", &w))
      auth->admin = (bool)json_object_get_boolean(w);

    if (json_object_object_get_ex(o, "allowedIfname", &w))
      auth->allowedIfname = strdup((char *)json_object_get_string(w));

    if (json_object_object_get_ex(o, "allowedNets", &w))
      auth->allowedNets = strdup((char *)json_object_get_string(w));

    if (json_object_object_get_ex(o, "language", &w))
      auth->language = strdup((char *)json_object_get_string(w));

    json_object_put(o);
    return true;
  }
  return false;
}

/* ****************************************************** */

void Utils::freeAuthenticator(HTTPAuthenticator *auth) {
  if (auth == NULL) return;
  if (auth->allowedIfname) free(auth->allowedIfname);
  if (auth->allowedNets) free(auth->allowedNets);
  if (auth->language) free(auth->language);
}

/* ****************************************************** */

DetailsLevel Utils::bool2DetailsLevel(bool max, bool higher, bool normal) {
  if (max) {
    return details_max;
  } else if (higher) {
    return details_higher;
  } else if (normal) {
    return details_normal;
  } else {
    return details_high;
  }
}

/* ****************************************************** */

void Utils::containerInfoLua(lua_State *vm, const ContainerInfo *const cont) {
  lua_newtable(vm);

  if (cont->id) lua_push_str_table_entry(vm, "id", cont->id);
  if (cont->data_type == container_info_data_type_k8s) {
    if (cont->name) lua_push_str_table_entry(vm, "k8s.name", cont->name);
    if (cont->data.k8s.pod)
      lua_push_str_table_entry(vm, "k8s.pod", cont->data.k8s.pod);
    if (cont->data.k8s.ns)
      lua_push_str_table_entry(vm, "k8s.ns", cont->data.k8s.ns);
  } else if (cont->data_type == container_info_data_type_docker) {
    if (cont->name) lua_push_str_table_entry(vm, "docker.name", cont->name);
  }
}

/* ****************************************************** */

const char *Utils::periodicityToScriptName(ScriptPeriodicity p) {
  switch (p) {
    case aperiodic_script:
      return ("aperiodic");
    case minute_script:
      return ("min");
    case five_minute_script:
      return ("5mins");
    case hour_script:
      return ("hour");
    case day_script:
      return ("day");
    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unknown periodicity value: %d", p);
      return ("");
  }
}

/* ****************************************************** */

int Utils::periodicityToSeconds(ScriptPeriodicity p) {
  switch (p) {
    case aperiodic_script:
      return (0);
    case minute_script:
      return (60);
    case five_minute_script:
      return (300);
    case hour_script:
      return (3600);
    case day_script:
      return (86400);
    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unknown periodicity value: %d", p);
      return (0);
  }
}

/* ****************************************************** */

/* TODO move into nDPI */
OSType Utils::getOSFromFingerprint(const char *fingerprint, const char *manuf,
                                   DeviceType devtype) {
  /*
    Inefficient with many signatures but ok for the
    time being that we have little data
  */
  if (!fingerprint) return (os_unknown);

  if (!strcmp(fingerprint, "017903060F77FC"))
    return (os_ios);
  else if ((!strcmp(fingerprint, "017903060F77FC5F2C2E")) ||
           (!strcmp(fingerprint, "0103060F775FFC2C2E2F")) ||
           (!strcmp(fingerprint, "0103060F775FFC2C2E")))
    return (os_macos);
  else if ((!strcmp(fingerprint, "0103060F1F212B2C2E2F79F9FC")) ||
           (!strcmp(fingerprint, "010F03062C2E2F1F2179F92B")))
    return (os_windows);
  else if ((!strcmp(fingerprint, "0103060C0F1C2A")) ||
           (!strcmp(fingerprint, "011C02030F06770C2C2F1A792A79F921FC2A")))
    return (os_linux); /* Android is also linux */
  else if ((!strcmp(fingerprint, "0603010F0C2C51452B1242439607")) ||
           (!strcmp(fingerprint, "01032C06070C0F16363A3B45122B7751999A")))
    return (os_laserjet);
  else if (!strcmp(fingerprint, "0102030F060C2C"))
    return (os_apple_airport);
  else if (!strcmp(fingerprint, "01792103060F1C333A3B77"))
    return (os_android);

  /* Below you can find ambiguous signatures */
  if (manuf) {
    if (!strcmp(fingerprint, "0103063633")) {
      if (strstr(manuf, "Apple"))
        return (os_macos);
      else if (devtype == device_unknown)
        return (os_windows);
    }
  }

  return (os_unknown);
}
/*
  Missing OS mapping

  011C02030F06770C2C2F1A792A
  010F03062C2E2F1F2179F92BFC
*/

/* ****************************************************** */

/* TODO move into nDPI? */
DeviceType Utils::getDeviceTypeFromOsDetail(const char *os) {
  if (strcasestr(os, "iPhone") || strcasestr(os, "Android") ||
      strcasestr(os, "mobile"))
    return (device_phone);
  else if (strcasestr(os, "Mac OS") || strcasestr(os, "Windows") ||
           strcasestr(os, "Linux"))
    return (device_workstation);
  else if (strcasestr(os, "iPad") || strcasestr(os, "tablet"))
    return (device_tablet);

  return (device_unknown);
}

/* Bitmap functions */
bool Utils::bitmapIsSet(u_int64_t bitmap, u_int8_t v) {
  if (v > 64) {
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "INTERNAL ERROR: bitmapIsSet out of range (%u > %u)", v,
        sizeof(bitmap));
    return (false);
  }

  return (((bitmap >> v) & 1) ? true : false);
}

u_int64_t Utils::bitmapSet(u_int64_t bitmap, u_int8_t v) {
  if (v > 64)
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "INTERNAL ERROR: bitmapSet out of range (%u > %u)", v,
        sizeof(bitmap));
  else
    bitmap |= ((u_int64_t)1) << v;

  return (bitmap);
}

u_int64_t Utils::bitmapClear(u_int64_t bitmap, u_int8_t v) {
  if (v > 64)
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "INTERNAL ERROR: bitmapClear out of range (%u > %u)", v,
        sizeof(bitmap));
  else
    bitmap &= ~(((u_int64_t)1) << v);

  return (bitmap);
}

/* ****************************************************** */

json_object *Utils::cloneJSONSimple(json_object *src) {
  struct json_object_iterator obj_it = json_object_iter_begin(src);
  struct json_object_iterator obj_itEnd = json_object_iter_end(src);
  json_object *obj = json_object_new_object();

  if (obj == NULL) return NULL;

  while (!json_object_iter_equal(&obj_it, &obj_itEnd)) {
    const char *key = json_object_iter_peek_name(&obj_it);
    json_object *v = json_object_iter_peek_value(&obj_it);
    enum json_type type = json_object_get_type(v);

    if (key != NULL && v != NULL) switch (type) {
        case json_type_int:
          json_object_object_add(
              obj, key, json_object_new_int64(json_object_get_int64(v)));
          break;
        case json_type_double:
          json_object_object_add(
              obj, key, json_object_new_double(json_object_get_double(v)));
          break;
        case json_type_string:
          json_object_object_add(
              obj, key, json_object_new_string(json_object_get_string(v)));
          break;
        case json_type_boolean:
          json_object_object_add(
              obj, key, json_object_new_boolean(json_object_get_boolean(v)));
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

int Utils::exec(const char *command) {
  int rc = 0;

#if defined(__linux__) || defined(__FreeBSD__) || defined(__APPLE__)
  if (!command || command[0] == '\0') return 0;

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
void Utils::deferredExec(const char *command) {
  char command_buf[256];
  int res;

  if (!command || command[0] == '\0') return;

  /* Self-restarting service does not restart with systemd:
     This is a hard limitation imposed by systemd.
     The best suggestions so far are to use at, cron, or systemd timer units.

     https://unix.stackexchange.com/questions/202048/self-restarting-service-does-not-restart-with-systemd
   */
  if ((res = snprintf(command_buf, sizeof(command_buf),
                      "echo \"sleep 1 && %s\" | at now", command)) < 0 ||
      res >= (int)sizeof(command_buf))
    return;

  printf("%s\n", command_buf);

  if (system(command_buf) == -1)
    fprintf(stderr, "Failed command %s: %d/%s", command_buf, errno, strerror(errno));
}
#endif

/* ****************************************************** */

void Utils::tlv2lua(lua_State *vm, ndpi_serializer *serializer) {
  ndpi_deserializer deserializer;
  ndpi_serialization_type kt, et;
  int rc;

  rc = ndpi_init_deserializer(&deserializer, serializer);

  if (rc == -1) return;

  while ((et = ndpi_deserialize_get_item_type(&deserializer, &kt)) != ndpi_serialization_unknown) {
    char key[64];
    u_int32_t k32;
    ndpi_string ks, vs;
    u_int32_t v32;
    int32_t i32;
    float f = 0;
    u_int64_t v64;
    int64_t i64;
    u_int8_t bkp;

    if (et == ndpi_serialization_end_of_record) {
      ndpi_deserialize_next(&deserializer);
      return;
    }

    switch (kt) {
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

    switch (et) {
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

u_int16_t Utils::countryCode2U16(const char *country_code) {
  if (country_code == NULL || strlen(country_code) < 2) return 0;
  return ((((u_int16_t)country_code[0]) << 8) | ((u_int16_t)country_code[1]));
}

/* ****************************************************** */

char *Utils::countryU162Code(u_int16_t country_u16, char *country_code,
                             size_t country_code_size) {
  country_code[0] = (country_u16 >> 8) & 0xFF;
  country_code[1] = country_u16 & 0xFF;
  country_code[2] = '\0';
  return country_code;
}

/* ****************************************************** */

bool Utils::isNumber(const char *s, unsigned int s_len, bool *is_float) {
  unsigned int i;
  bool is_num = true;

  *is_float = false;

  for (i = 0; i < s_len; i++) {
    if (!isdigit(s[i]) && s[i] != '.') {
      is_num = false;
      break;
    }
    if (s[i] == '.') *is_float = true;
  }

  return is_num;
}

/* ****************************************************** */

bool Utils::isPingSupported() {
#ifndef WIN32
  int sd;

#if defined(__APPLE__)
  sd = Utils::openSocket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP, "isPingSupported");
#else
  sd = Utils::openSocket(PF_INET, SOCK_RAW, IPPROTO_ICMP, "isPingSupported");
#endif

  if (sd != -1) {
    Utils::closeSocket(sd);
    return (true);
  }
#endif

  return (false);
}

/* ****************************************************** */

/*
 * Return the linux device name given an interface name
 * to handle PF_RING interfaces like zc:ens2f1@3
 * (it removes '<module>:' prefix or trailing '@<queue>')
 */
char *Utils::ifname2devname(const char *ifname, char *devname,
                            int devname_size) {
  const char *colon;
  char *at;

  /* strip prefix ":" */
  colon = strchr(ifname, ':');
  strncpy(devname, colon != NULL ? colon + 1 : ifname, devname_size);
  devname[devname_size - 1] = '\0';

  /* strip trailing "@" */
  at = strchr(devname, '@');
  if (at != NULL) at[0] = '\0';

  return devname;
}

/* ****************************************************** */

ScoreCategory Utils::mapAlertToScoreCategory(AlertCategory alert_category) {
  if (alert_category == alert_category_security)
    return (score_category_security);
  else
    return (score_category_network);
}

/* ****************************************************** */

AlertLevel Utils::mapScoreToSeverity(u_int32_t score) {
  if (score < SCORE_LEVEL_INFO)
    return alert_level_none;
  else if (score < SCORE_LEVEL_NOTICE)
    return alert_level_info;
  else if (score < SCORE_LEVEL_WARNING)
    return alert_level_notice;
  else if (score < SCORE_LEVEL_ERROR)
    return alert_level_warning;
  else if (score < SCORE_LEVEL_CRITICAL)
    return alert_level_error;
  else if (score < SCORE_LEVEL_EMERGENCY)
    return alert_level_critical;
  else
    return alert_level_emergency;
}

/* ****************************************************** */

u_int8_t Utils::mapSeverityToScore(AlertLevel alert_level) {
  if (alert_level <= alert_level_info)
    return SCORE_LEVEL_INFO;
  else if (alert_level <= alert_level_notice)
    return SCORE_LEVEL_NOTICE;
  else if (alert_level <= alert_level_warning)
    return SCORE_LEVEL_WARNING;
  else if (alert_level <= alert_level_error)
    return SCORE_LEVEL_ERROR;
  else if (alert_level <= alert_level_critical)
    return SCORE_LEVEL_CRITICAL;
  else if (alert_level <= alert_level_emergency)
    return SCORE_LEVEL_EMERGENCY;
  else
    return SCORE_LEVEL_SEVERE;
}

/* ****************************************************** */

AlertLevelGroup Utils::mapAlertLevelToGroup(AlertLevel alert_level) {
  switch (alert_level) {
    case alert_level_debug:
    case alert_level_info:
    case alert_level_notice:
      return alert_level_group_notice_or_lower;
    case alert_level_warning:
      return alert_level_group_warning;
    case alert_level_error:
      return alert_level_group_error;
    case alert_level_critical:
    case alert_level_alert:
      return alert_level_group_critical;
    case alert_level_emergency:
      return alert_level_group_emergency;
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
  if (strcasecmp(facility_text, "auth") == 0)
    return LOG_AUTH;
  else if (strcasecmp(facility_text, "authpriv") == 0)
    return LOG_AUTHPRIV;
  else if (strcasecmp(facility_text, "cron") == 0)
    return LOG_CRON;
  else if (strcasecmp(facility_text, "daemon") == 0)
    return LOG_DAEMON;
  else if (strcasecmp(facility_text, "ftp") == 0)
    return LOG_FTP;
  else if (strcasecmp(facility_text, "kern") == 0)
    return LOG_KERN;
  else if (strcasecmp(facility_text, "lpr") == 0)
    return LOG_LPR;
  else if (strcasecmp(facility_text, "mail") == 0)
    return LOG_MAIL;
  else if (strcasecmp(facility_text, "news") == 0)
    return LOG_NEWS;
  else if (strcasecmp(facility_text, "security") == 0)
    return LOG_AUTH;
  else if (strcasecmp(facility_text, "syslog") == 0)
    return LOG_SYSLOG;
  else if (strcasecmp(facility_text, "user") == 0)
    return LOG_USER;
  else if (strcasecmp(facility_text, "uucp") == 0)
    return LOG_UUCP;
  else if (strcasecmp(facility_text, "local0") == 0)
    return LOG_LOCAL0;
  else if (strcasecmp(facility_text, "local1") == 0)
    return LOG_LOCAL1;
  else if (strcasecmp(facility_text, "local2") == 0)
    return LOG_LOCAL2;
  else if (strcasecmp(facility_text, "local3") == 0)
    return LOG_LOCAL3;
  else if (strcasecmp(facility_text, "local4") == 0)
    return LOG_LOCAL4;
  else if (strcasecmp(facility_text, "local5") == 0)
    return LOG_LOCAL5;
  else if (strcasecmp(facility_text, "local6") == 0)
    return LOG_LOCAL6;
  else if (strcasecmp(facility_text, "local7") == 0)
    return LOG_LOCAL7;
  else
    return -1;
}
#endif

/* ****************************************************** */

static char *appendFilterString(char *filters, char *new_filter) {
  if (!filters)
    filters = strdup(new_filter);
  else {
    filters = (char *)realloc(
        filters, strlen(filters) + strlen(new_filter) + sizeof(" OR "));

    if (filters) {
      strcat(filters, " OR ");
      strcat(filters, new_filter);
    }
  }

  return (filters);
}

struct sqlite_filter_data {
  bool match_all;
  char *hosts_filter;
  char *flows_filter;
};

static void allowed_nets_walker(ndpi_patricia_node_t *node, void *data,
                                void *user_data) {
  struct sqlite_filter_data *filterdata = (sqlite_filter_data *)user_data;
  struct in6_addr lower_addr;
  struct in6_addr upper_addr;
  ndpi_prefix_t *prefix = ndpi_patricia_get_node_prefix(node);
  int bitlen = prefix->bitlen;
  char lower_hex[33], upper_hex[33];
  char hosts_buf[512], flows_buf[512];

  if (filterdata->match_all) return;

  if (bitlen == 0) {
    /* Match all, no filter necessary */
    filterdata->match_all = true;

    if (filterdata->hosts_filter) {
      free(filterdata->hosts_filter);
      filterdata->flows_filter = NULL;
    }

    if (filterdata->flows_filter) {
      free(filterdata->flows_filter);
      filterdata->flows_filter = NULL;
    }

    return;
  }

  if (prefix->family == AF_INET) {
    memset(&lower_addr, 0, sizeof(lower_addr) - 4);
    memcpy(((char *)&lower_addr) + 12, &prefix->add.sin.s_addr, 4);

    bitlen += 96;
  } else
    memcpy(&lower_addr, &prefix->add.sin6, sizeof(lower_addr));

  /* Calculate upper address */
  memcpy(&upper_addr, &lower_addr, sizeof(upper_addr));

  for (int i = 0; i < (128 - bitlen); i++) {
    u_char bit = 127 - i;

    upper_addr.s6_addr[bit / 8] |= (1 << (bit % 8));

    /* Also normalize the lower address */
    lower_addr.s6_addr[bit / 8] &= ~(1 << (bit % 8));
  }

  /* Convert to hex */
  for (int i = 0; i < 16; i++) {
    u_char lval = lower_addr.s6_addr[i];
    u_char uval = upper_addr.s6_addr[i];

    lower_hex[i * 2] = hex_chars[(lval >> 4) & 0xF];
    lower_hex[i * 2 + 1] = hex_chars[lval & 0xF];

    upper_hex[i * 2] = hex_chars[(uval >> 4) & 0xF];
    upper_hex[i * 2 + 1] = hex_chars[uval & 0xF];
  }

  lower_hex[32] = '\0';
  upper_hex[32] = '\0';

  /* Build filter strings */
  snprintf(hosts_buf, sizeof(hosts_buf), "((ip >= x'%s') AND (ip <= x'%s'))",
           lower_hex, upper_hex);

  snprintf(flows_buf, sizeof(flows_buf),
           "(((cli_ip >= x'%s') AND (cli_ip <= x'%s')) OR ((srv_ip >= x'%s') "
           "AND (srv_ip <= x'%s')))",
           lower_hex, upper_hex, lower_hex, upper_hex);

  filterdata->hosts_filter =
      appendFilterString(filterdata->hosts_filter, hosts_buf);

  filterdata->flows_filter =
      appendFilterString(filterdata->flows_filter, flows_buf);
}

/* ******************************************* */

void Utils::buildSqliteAllowedNetworksFilters(lua_State *vm) {
  AddressTree *allowed_nets = getLuaVMUserdata(vm, allowedNets);

  if (allowed_nets) {
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
  snprintf(buf, buf_len, "session_%u_%u", ntop->getPrefs()->get_http_port(),
           ntop->getPrefs()->get_https_port());
}

/* ****************************************************** */

/* Internal function used to set names to lower
 * Use this function only if you need to duplicate the string to be lowered
 * otherwise use Utils::stringtolower(name)
 */
char *Utils::toLowerResolvedNames(const char *const resolvedName) {
  char *name = strdup(resolvedName);
  if (name) {
    name = Utils::stringtolower(name);
  }

  return name;
}

/* ************************************************ */

bool const Utils::isIpEmpty(ipAddress addr) {
  if ((addr.ipVersion == 0) ||
      ((addr.ipVersion == 4) && (addr.ipType.ipv4 == 0))) {
    return true;
  } else if (addr.ipVersion == 6) {
    struct ndpi_in6_addr empty_ipv6;
    memset(&empty_ipv6, 0, sizeof(empty_ipv6));
    return memcmp((void *)&empty_ipv6, (void *)&addr.ipType.ipv6,
                  sizeof(empty_ipv6)) == 0
               ? true
               : false;
  }

  return false;
}

/* ************************************************ */

int8_t Utils::num_files_in_dir(const char *dir) {
  DIR *dir_struct;
  struct dirent *ent;
  u_int8_t num_files = 0;

  if ((dir_struct = opendir(dir)) != NULL) {
    while ((ent = readdir(dir_struct)) != NULL) {
      if (ent->d_name[0] != '.') num_files++;
    }

    closedir(dir_struct);
  }

  return (num_files);
}

/* ******************************************* */

const char *Utils::get_state_label(ThreadedActivityState ta_state) {
  switch (ta_state) {
    case threaded_activity_state_sleeping:
      return ("sleeping");
      break;
    case threaded_activity_state_queued:
      return ("queued");
      break;
    case threaded_activity_state_running:
      return ("running");
      break;
    case threaded_activity_state_unknown:
    default:
      return ("unknown");
      break;
  }
}

/* ******************************************* */

void Utils::splitAddressAndVlan(char *addr, u_int16_t *vlan_id) {
  char *at = NULL;

  if ((at = strchr(addr, '@'))) {
    *vlan_id = atoi(at + 1);
    *at = '\0';
  } else
    vlan_id = 0;
}

/* ******************************************* */

bool Utils::endsWith(const char *base, const char *str) {
  int blen = strlen(base);
  int slen = strlen(str);
  return (blen >= slen) && (0 == strcmp(base + blen - slen, str));
}

/* ******************************************* */

int Utils::openSocket(int domain, int type, int protocol, const char *label) {
  int sock;

  sock = socket(domain, type, protocol);

  if (sock < 0) return sock;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Socket %d (%s) created", sock,
                               label);

  return sock;
}

/* ******************************************* */

void Utils::closeSocket(int sock) {
  if (sock < 0) return;

#if !defined(WIN32) && !defined(closesocket)
  close(sock);
#else
  closesocket(sock);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Socket %d closed", sock);
}

/* ******************************************* */

static const char *message_topics[] = {
    "flow",  "event",           "counter",     "template", "option",
    "hello", "listening-ports", "snmp-ifaces", "message",  NULL};

const char **Utils::getMessagingTopics() {
  return ((const char **)message_topics);
}

/* ******************************************* */

char *Utils::toHex(char *in, u_int in_len, char *out, u_int out_len) {
  u_int i, j;
  static const char hex_digits[] = "0123456789ABCDEF";

  if (in_len > (2 * out_len)) return NULL;

  for (i = 0, j = 0; i < in_len; i++) {
    u_char c = (u_char)in[i];

    out[j++] = hex_digits[c >> 4];
    out[j++] = hex_digits[c & 15];
  }

  out[j] = '\0';

  return out;
}

/* ******************************************* */

bool Utils::fromHex(char *in, u_int in_len, char *out, u_int out_len) {
  u_int i, j;

  if ((in_len / 2) > out_len) return (false);

  for (i = 0, j = 0; i < in_len;) {
    char s[3];

    s[0] = in[i], s[1] = in[i + 1], s[2] = 0;
    out[j++] = strtoul(s, NULL, 16);

    i += 2;
  }

  out[j] = '\0';

  return (true);
}

/* ******************************************* */

void Utils::swap8(u_int8_t *a, u_int8_t *b) {
  u_int8_t c = *a;
  *a = *b;
  *b = c;
}

void Utils::swap16(u_int16_t *a, u_int16_t *b) {
  u_int16_t c = *a;
  *a = *b;
  *b = c;
}

void Utils::swap32(u_int32_t *a, u_int32_t *b) {
  u_int32_t c = *a;
  *a = *b;
  *b = c;
}

void Utils::swapfloat(float *a, float *b) {
  float c = *a;
  *a = *b;
  *b = c;
}

/* ******************************************* */

char* Utils::createRandomString(char *buf, size_t buf_len) {
  const char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.-#'?!";
  int charset_len = (int)(sizeof(charset) -1);

  for (u_int i = 0; i < buf_len; i++)
    buf[i] = charset[rand() % charset_len];

  buf[buf_len-1] = '\0';

  return(buf);
}

/* ******************************************* */

/* IMPORTANT: the returned IpAddress* must be freed by the caller */
IpAddress* Utils::parseHostString(char *host_ip, u_int16_t *vlan_id /* out */) {
  IpAddress *ip_addr = NULL;
  char *ip = NULL, *vlan = NULL;

  if (host_ip != NULL && host_ip[0] != 0) {
    char *tmp = NULL;
    char *token = strtok_r(host_ip, "@", &tmp);
    int h = 0;

    while (token != NULL)  {
      if(h == 0)
	ip = token;
      else if (h == 1)
	vlan = token;

      token = strtok_r(NULL, "@", &tmp);
      h++;
    }
  }

  if(ip != NULL) {
    ip_addr = new IpAddress();
    if(ip_addr) ip_addr->set(ip);
  } else
    ip_addr = NULL;

  *vlan_id = vlan ? stoi(vlan) : 0;

  return(ip_addr);
}

/* ******************************************* */

bool Utils::nwInterfaceExists(char *if_name) {
#ifdef WIN32
 return(true);
 #else
#ifdef __linux__
  char path[64];
  struct stat buf;

  snprintf(path, sizeof(path), "/sys/class/net/%s", if_name);
  return((stat(path, &buf) == 0) ? true : false);
#else
  bool found = false;
  struct if_nameindex *ifp, *ifpsave;

  ifpsave = ifp = if_nameindex();

  if(!ifp)
    return(false);

  while(ifp->if_index) {
    if(strcmp(ifp->if_name, if_name) == 0){
      found = true;
      break;
    }

    ifp++;
  }

  if_freenameindex(ifpsave);

  return(found);
#endif
#endif
}

/* ******************************************* */

bool Utils::readModbusDeviceInfo(char *device_ip, u_int8_t timeout_sec, lua_State *vm) {
  struct hostent *server = NULL;
  struct sockaddr_in serv_addr;
  int sockfd = -1;
  int retval;
  bool rc = false;
  struct timeval tv_timeout;
  char response[512], modbus_query[] = {
    0x0, 0x0, /* Trsnsaction Id */
    0x0, 0x0, /* Protocol Id    */
    0x0, 0x5, /* Lenght         */
    0x1,      /* Unit Id        */
    0x2b,     /* Function code  */
    0x0e,     /* MEI type (Read Device Identification) */
    0x01,     /* Read Device Id */
    0x0       /* Vendor Name    */
  };

  server = gethostbyname(device_ip);
  if(server == NULL) return(false);

  memset((char *)&serv_addr, 0, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  memcpy((char *)&serv_addr.sin_addr.s_addr, (char *)server->h_addr,
         server->h_length);
  serv_addr.sin_port = htons(502 /* Modbus */);

  sockfd = Utils::openSocket(AF_INET, SOCK_STREAM, 0, "readModbusDeviceInfo");

  if(sockfd < 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
    return(false);
  }

#ifndef WIN32
  if(timeout_sec == 0) {
    retval = fcntl(sockfd, F_SETFL, fcntl(sockfd, F_GETFL, 0) | O_NONBLOCK);

    if(retval == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Error setting NONBLOCK flag");
      Utils::closeSocket(sockfd);
      return(false);
    }
  } else {
    tv_timeout.tv_sec = timeout_sec, tv_timeout.tv_usec = 0;
    retval = setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &tv_timeout,
                        sizeof(tv_timeout));
    if(retval == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Error setting send timeout: %s",
				   strerror(errno));
      Utils::closeSocket(sockfd);
      return(false);
    }
  }
#endif

  if(connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0 &&
      (errno == ECONNREFUSED || errno == EALREADY || errno == EAGAIN ||
       errno == ENETUNREACH || errno == ETIMEDOUT)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Could not connect to remote party");
    Utils::closeSocket(sockfd);
    return(false);
  }

  rc = true;
  retval = send(sockfd, modbus_query, sizeof(modbus_query), 0);

  if(retval <= 0)
    rc = false;
  else {
    fd_set rset;
    int ret;

    tv_timeout.tv_sec = timeout_sec, tv_timeout.tv_usec = 0;

    FD_ZERO(&rset);
    FD_SET(sockfd, &rset);
    ret = select(sockfd + 1, &rset, NULL, NULL, &tv_timeout);

    if(ret > 0) {
      int len = read(sockfd, response, sizeof(response));

      lua_newtable(vm);

      ntop->getTrace()->traceEvent(TRACE_INFO, "Read %u bytes", len);

      if(len > 7 /* Modbus/TCP Len */) {
	int response_len = ntohs(*((u_int16_t*)&response[4]));

	if((response_len + 7) <= len) {
	  u_int16_t offset = 13;
	  u_int8_t num_objects = response[offset++];
	  char buf[128];

	  while(num_objects > 0) {
	    u_int8_t object_id     = response[offset++];
	    u_int8_t l, object_len = response[offset++];

	    if((object_len+offset) < len) {
	      switch(object_id) {
	      case 0:
		strncpy(buf, &response[offset], l = ndpi_min(sizeof(buf)-1, object_len)); buf[l] = '\0';
		lua_push_str_table_entry(vm, "vendor_name", buf);
		break;

	      case 1:
		strncpy(buf, &response[offset], l = ndpi_min(sizeof(buf)-1, object_len)); buf[l] = '\0';
		lua_push_str_table_entry(vm, "product_code", buf);
		break;

	      case 2:
		strncpy(buf, &response[offset], l = ndpi_min(sizeof(buf)-1, object_len)); buf[l] = '\0';
		lua_push_str_table_entry(vm, "product_revision", buf);
		break;
	      }
	    }

	    offset += object_len, num_objects--;
	  } /* while */
	}
      } else
	rc = false;
    } else
      rc = false;
  }

  Utils::closeSocket(sockfd);

  return(rc);
}

/* ******************************************* */

/* From Wireshark packet-cip.c */
struct value_string {
  u_int32_t          value;
  const char         *name;
};

static const value_string vendors[] = {
   {    0,   "Reserved" },
   {    1,   "Rockwell Automation/Allen-Bradley" },
   {    2,   "Namco Controls Corp." },
   {    3,   "Honeywell Inc." },
   {    4,   "Parker Hannifin Corp. (Veriflo Division)" },
   {    5,   "Rockwell Automation/Reliance Elec." },
   {    6,   "Reserved" },
   {    7,   "SMC Corporation" },
   {    8,   "Molex Incorporated" },
   {    9,   "Western Reserve Controls Corp." },
   {   10,   "Advanced Micro Controls Inc. (AMCI)" },
   {   11,   "ASCO Pneumatic Controls" },
   {   12,   "Banner Engineering Corp." },
   {   13,   "Belden Wire & Cable Company" },
   {   14,   "Cooper Interconnect" },
   {   15,   "Reserved" },
   {   16,   "Daniel Woodhead Co. (Woodhead Connectivity)" },
   {   17,   "Dearborn Group Inc." },
   {   18,   "Reserved" },
   {   19,   "Helm Instrument Company" },
   {   20,   "Huron Net Works" },
   {   21,   "Lumberg, Inc." },
   {   22,   "Online Development Inc.(Automation Value)" },
   {   23,   "Vorne Industries, Inc." },
   {   24,   "ODVA Special Reserve" },
   {   25,   "Reserved" },
   {   26,   "Festo Corporation" },
   {   27,   "Reserved" },
   {   28,   "Reserved" },
   {   29,   "Reserved" },
   {   30,   "Unico, Inc." },
   {   31,   "Ross Controls" },
   {   32,   "Reserved" },
   {   33,   "Reserved" },
   {   34,   "Hohner Corp." },
   {   35,   "Micro Mo Electronics, Inc." },
   {   36,   "MKS Instruments, Inc." },
   {   37,   "Yaskawa Electric America formerly Magnetek Drives" },
   {   38,   "Reserved" },
   {   39,   "AVG Automation (Uticor)" },
   {   40,   "Wago Corporation" },
   {   41,   "Kinetics (Unit Instruments)" },
   {   42,   "IMI Norgren Limited" },
   {   43,   "BALLUFF, Inc." },
   {   44,   "Yaskawa Electric America, Inc." },
   {   45,   "Eurotherm Controls Inc" },
   {   46,   "ABB Industrial Systems" },
   {   47,   "Omron Corporation" },
   {   48,   "TURCk, Inc." },
   {   49,   "Grayhill Inc." },
   {   50,   "Real Time Automation (C&ID)" },
   {   51,   "Reserved" },
   {   52,   "Numatics, Inc." },
   {   53,   "Lutze, Inc." },
   {   54,   "Reserved" },
   {   55,   "Reserved" },
   {   56,   "Softing GmbH" },
   {   57,   "Pepperl + Fuchs" },
   {   58,   "Spectrum Controls, Inc." },
   {   59,   "D.I.P. Inc. MKS Inst." },
   {   60,   "Applied Motion Products, Inc." },
   {   61,   "Sencon Inc." },
   {   62,   "High Country Tek" },
   {   63,   "SWAC Automation Consult GmbH" },
   {   64,   "Clippard Instrument Laboratory" },
   {   65,   "Reserved" },
   {   66,   "Reserved" },
   {   67,   "Reserved" },
   {   68,   "Eaton Electrical" },
   {   69,   "Reserved" },
   {   70,   "Reserved" },
   {   71,   "Toshiba International Corp." },
   {   72,   "Control Technology Incorporated" },
   {   73,   "TCS (NZ) Ltd." },
   {   74,   "Hitachi, Ltd." },
   {   75,   "ABB Robotics Products AB" },
   {   76,   "NKE Corporation" },
   {   77,   "Rockwell Software, Inc." },
   {   78,   "Escort Memory Systems (A Datalogic Group Co.)" },
   {   79,   "Reserved" },
   {   80,   "Industrial Devices Corporation" },
   {   81,   "IXXAT Automation GmbH" },
   {   82,   "Mitsubishi Electric Automation, Inc." },
   {   83,   "OPTO-22" },
   {   84,   "Reserved" },
   {   85,   "Reserved" },
   {   86,   "Horner Electric" },
   {   87,   "Burkert Werke GmbH & Co. KG" },
   {   88,   "Reserved" },
   {   89,   "Industrial Indexing Systems, Inc." },
   {   90,   "HMS Industrial Networks AB" },
   {   91,   "Robicon" },
   {   92,   "Helix Technology (Granville-Phillips)" },
   {   93,   "Arlington Laboratory" },
   {   94,   "Advantech Co. Ltd." },
   {   95,   "Square D Company" },
   {   96,   "Digital Electronics Corp." },
   {   97,   "Danfoss" },
   {   98,   "Reserved" },
   {   99,   "Reserved" },
   {  100,   "Bosch Rexroth Corporation, Pneumatics" },
   {  101,   "Applied Materials, Inc." },
   {  102,   "Showa Electric Wire & Cable Co." },
   {  103,   "Pacific Scientific (API Controls Inc.)" },
   {  104,   "Sharp Manufacturing Systems Corp." },
   {  105,   "Olflex Wire & Cable, Inc." },
   {  106,   "Reserved" },
   {  107,   "Unitrode" },
   {  108,   "Beckhoff Automation GmbH" },
   {  109,   "National Instruments" },
   {  110,   "Mykrolis Corporations (Millipore)" },
   {  111,   "International Motion Controls Corp." },
   {  112,   "Reserved" },
   {  113,   "SEG Kempen GmbH" },
   {  114,   "Reserved" },
   {  115,   "Reserved" },
   {  116,   "MTS Systems Corp." },
   {  117,   "Krones, Inc" },
   {  118,   "Reserved" },
   {  119,   "EXOR Electronic R & D" },
   {  120,   "SIEI S.p.A." },
   {  121,   "KUKA Roboter GmbH" },
   {  122,   "Reserved" },
   {  123,   "SEC (Samsung Electronics Co., Ltd)" },
   {  124,   "Binary Electronics Ltd" },
   {  125,   "Flexible Machine Controls" },
   {  126,   "Reserved" },
   {  127,   "ABB Inc. (Entrelec)" },
   {  128,   "MAC Valves, Inc." },
   {  129,   "Auma Actuators Inc" },
   {  130,   "Toyoda Machine Works, Ltd" },
   {  131,   "Reserved" },
   {  132,   "Reserved" },
   {  133,   "Balogh T.A.G., Corporation" },
   {  134,   "TR Systemtechnik GmbH" },
   {  135,   "UNIPULSE Corporation" },
   {  136,   "Reserved" },
   {  137,   "Reserved" },
   {  138,   "Conxall Corporation Inc." },
   {  139,   "Reserved" },
   {  140,   "Reserved" },
   {  141,   "Kuramo Electric Co., Ltd." },
   {  142,   "Creative Micro Designs" },
   {  143,   "GE Industrial Systems" },
   {  144,   "Leybold Vacuum GmbH" },
   {  145,   "Siemens Energy & Automation/Drives" },
   {  146,   "Kodensha Ltd" },
   {  147,   "Motion Engineering, Inc." },
   {  148,   "Honda Engineering Co., Ltd" },
   {  149,   "EIM Valve Controls" },
   {  150,   "Melec Inc." },
   {  151,   "Sony Manufacturing Systems Corporation" },
   {  152,   "North American Mfg." },
   {  153,   "WATLOW" },
   {  154,   "Japan Radio Co., Ltd" },
   {  155,   "NADEX Co., Ltd" },
   {  156,   "Ametek Automation & Process Technologies" },
   {  157,   "Reserved" },
   {  158,   "KVASER AB" },
   {  159,   "IDEC IZUMI Corporation" },
   {  160,   "Mitsubishi Heavy Industries Ltd" },
   {  161,   "Mitsubishi Electric Corporation" },
   {  162,   "Horiba-STEC Inc." },
   {  163,   "esd electronic system design gmbh" },
   {  164,   "DAIHEN Corporation" },
   {  165,   "Tyco Valves & Controls/Keystone" },
   {  166,   "EBARA Corporation" },
   {  167,   "Reserved" },
   {  168,   "Reserved" },
   {  169,   "Hokuyo Electric Co. Ltd" },
   {  170,   "Pyramid Solutions, Inc." },
   {  171,   "Denso Wave Incorporated" },
   {  172,   "HLS Hard-Line Solutions Inc" },
   {  173,   "Caterpillar, Inc." },
   {  174,   "PDL Electronics Ltd." },
   {  175,   "Reserved" },
   {  176,   "Red Lion Controls" },
   {  177,   "ANELVA Corporation" },
   {  178,   "Toyo Denki Seizo KK" },
   {  179,   "Sanyo Denki Co., Ltd" },
   {  180,   "Advanced Energy Japan K.K. (Aera Japan)" },
   {  181,   "Pilz GmbH & Co" },
   {  182,   "Marsh Bellofram-Bellofram PCD Division" },
   {  183,   "Reserved" },
   {  184,   "M-SYSTEM Co. Ltd" },
   {  185,   "Nissin Electric Co., Ltd" },
   {  186,   "Hitachi Metals Ltd." },
   {  187,   "Oriental Motor Company" },
   {  188,   "A&D Co., Ltd" },
   {  189,   "Phasetronics, Inc." },
   {  190,   "Cummins Engine Company" },
   {  191,   "Deltron Inc." },
   {  192,   "Geneer Corporation" },
   {  193,   "Anatol Automation, Inc." },
   {  194,   "Reserved" },
   {  195,   "Reserved" },
   {  196,   "Medar, Inc." },
   {  197,   "Comdel Inc." },
   {  198,   "Advanced Energy Industries, Inc" },
   {  199,   "Reserved" },
   {  200,   "DAIDEN Co., Ltd" },
   {  201,   "CKD Corporation" },
   {  202,   "Toyo Electric Corporation" },
   {  203,   "Reserved" },
   {  204,   "AuCom Electronics Ltd" },
   {  205,   "Shinko Electric Co., Ltd" },
   {  206,   "Vector Informatik GmbH" },
   {  207,   "Reserved" },
   {  208,   "Moog Inc." },
   {  209,   "Contemporary Controls" },
   {  210,   "Tokyo Sokki Kenkyujo Co., Ltd" },
   {  211,   "Schenck-AccuRate, Inc." },
   {  212,   "The Oilgear Company" },
   {  213,   "Reserved" },
   {  214,   "ASM Japan K.K." },
   {  215,   "HIRATA Corp." },
   {  216,   "SUNX Limited" },
   {  217,   "Meidensha Corp." },
   {  218,   "NIDEC SANKYO CORPORATION (Sankyo Seiki Mfg. Co., Ltd)" },
   {  219,   "KAMRO Corp." },
   {  220,   "Nippon System Development Co., Ltd" },
   {  221,   "EBARA Technologies Inc." },
   {  222,   "Reserved" },
   {  223,   "Reserved" },
   {  224,   "SG Co., Ltd" },
   {  225,   "Vaasa Institute of Technology" },
   {  226,   "MKS Instruments (ENI Technology)" },
   {  227,   "Tateyama System Laboratory Co., Ltd." },
   {  228,   "QLOG Corporation" },
   {  229,   "Matric Limited Inc." },
   {  230,   "NSD Corporation" },
   {  231,   "Reserved" },
   {  232,   "Sumitomo Wiring Systems, Ltd" },
   {  233,   "Group 3 Technology Ltd" },
   {  234,   "CTI Cryogenics" },
   {  235,   "POLSYS CORP" },
   {  236,   "Ampere Inc." },
   {  237,   "Reserved" },
   {  238,   "Simplatroll Ltd" },
   {  239,   "Reserved" },
   {  240,   "Reserved" },
   {  241,   "Leading Edge Design" },
   {  242,   "Humphrey Products" },
   {  243,   "Schneider Automation, Inc." },
   {  244,   "Westlock Controls Corp." },
   {  245,   "Nihon Weidmuller Co., Ltd" },
   {  246,   "Brooks Instrument (Div. of Emerson)" },
   {  247,   "Reserved" },
   {  248,   "Moeller GmbH" },
   {  249,   "Varian Vacuum Products" },
   {  250,   "Yokogawa Electric Corporation" },
   {  251,   "Electrical Design Daiyu Co., Ltd" },
   {  252,   "Omron Software Co., Ltd" },
   {  253,   "BOC Edwards" },
   {  254,   "Control Technology Corporation" },
   {  255,   "Bosch Rexroth" },
   {  256,   "Turck" },
   {  257,   "Control Techniques PLC" },
   {  258,   "Hardy Instruments, Inc." },
   {  259,   "LS Industrial Systems" },
   {  260,   "E.O.A. Systems Inc." },
   {  261,   "Reserved" },
   {  262,   "New Cosmos Electric Co., Ltd." },
   {  263,   "Sense Eletronica LTDA" },
   {  264,   "Xycom, Inc." },
   {  265,   "Baldor Electric" },
   {  266,   "Reserved" },
   {  267,   "Patlite Corporation" },
   {  268,   "Reserved" },
   {  269,   "Mogami Wire & Cable Corporation" },
   {  270,   "Welding Technology Corporation (WTC)" },
   {  271,   "Reserved" },
   {  272,   "Deutschmann Automation GmbH" },
   {  273,   "ICP Panel-Tec Inc." },
   {  274,   "Bray Controls USA" },
   {  275,   "Reserved" },
   {  276,   "Status Technologies" },
   {  277,   "Trio Motion Technology Ltd" },
   {  278,   "Sherrex Systems Ltd" },
   {  279,   "Adept Technology, Inc." },
   {  280,   "Spang Power Electronics" },
   {  281,   "Reserved" },
   {  282,   "Acrosser Technology Co., Ltd" },
   {  283,   "Hilscher GmbH" },
   {  284,   "IMAX Corporation" },
   {  285,   "Electronic Innovation, Inc. (Falter Engineering)" },
   {  286,   "Netlogic Inc." },
   {  287,   "Bosch Rexroth Corporation, Indramat" },
   {  288,   "Reserved" },
   {  289,   "Reserved" },
   {  290,   "Murata  Machinery Ltd." },
   {  291,   "MTT Company Ltd." },
   {  292,   "Kanematsu Semiconductor Corp." },
   {  293,   "Takebishi Electric Sales Co." },
   {  294,   "Tokyo Electron Device Ltd" },
   {  295,   "PFU Limited" },
   {  296,   "Hakko Automation Co., Ltd." },
   {  297,   "Advanet Inc." },
   {  298,   "Tokyo Electron Software Technologies Ltd." },
   {  299,   "Reserved" },
   {  300,   "Shinagawa Electric Wire Co., Ltd." },
   {  301,   "Yokogawa M&C Corporation" },
   {  302,   "KONAN Electric Co., Ltd." },
   {  303,   "Binar Elektronik AB" },
   {  304,   "Furukawa Electric Co." },
   {  305,   "Cooper Energy Services" },
   {  306,   "Schleicher GmbH & Co." },
   {  307,   "Hirose Electric Co., Ltd" },
   {  308,   "Western Servo Design Inc." },
   {  309,   "Prosoft Technology" },
   {  310,   "Reserved" },
   {  311,   "Towa Shoko Co., Ltd" },
   {  312,   "Kyopal Co., Ltd" },
   {  313,   "Extron Co." },
   {  314,   "Wieland Electric GmbH" },
   {  315,   "SEW Eurodrive GmbH" },
   {  316,   "Aera Corporation" },
   {  317,   "STA Reutlingen" },
   {  318,   "Reserved" },
   {  319,   "Fuji Electric Co., Ltd." },
   {  320,   "Reserved" },
   {  321,   "Reserved" },
   {  322,   "ifm efector, inc." },
   {  323,   "Reserved" },
   {  324,   "IDEACOD-Hohner Automation S.A." },
   {  325,   "CommScope Inc." },
   {  326,   "GE Fanuc Automation North America, Inc." },
   {  327,   "Matsushita Electric Industrial Co., Ltd" },
   {  328,   "Okaya Electronics Corporation" },
   {  329,   "KASHIYAMA Industries, Ltd" },
   {  330,   "JVC" },
   {  331,   "Interface Corporation" },
   {  332,   "Grape Systems Inc." },
   {  333,   "Reserved" },
   {  334,   "Reserved" },
   {  335,   "Toshiba IT & Control Systems Corporation" },
   {  336,   "Sanyo Machine Works, Ltd." },
   {  337,   "Vansco Electronics Ltd." },
   {  338,   "Dart Container Corp." },
   {  339,   "Livingston & Co., Inc." },
   {  340,   "Alfa Laval LKM as" },
   {  341,   "BF ENTRON Ltd. (British Federal)" },
   {  342,   "Bekaert Engineering NV" },
   {  343,   "Ferran  Scientific Inc." },
   {  344,   "KEBA AG" },
   {  345,   "Endress + Hauser" },
   {  346,   "Reserved" },
   {  347,   "ABB ALSTOM Power UK Ltd. (EGT)" },
   {  348,   "Berger Lahr GmbH" },
   {  349,   "Reserved" },
   {  350,   "Federal Signal Corp." },
   {  351,   "Kawasaki Robotics (USA), Inc." },
   {  352,   "Bently Nevada Corporation" },
   {  353,   "Reserved" },
   {  354,   "FRABA Posital GmbH" },
   {  355,   "Elsag Bailey, Inc." },
   {  356,   "Fanuc Robotics America" },
   {  357,   "Reserved" },
   {  358,   "Surface Combustion, Inc." },
   {  359,   "Reserved" },
   {  360,   "AILES Electronics Ind. Co., Ltd." },
   {  361,   "Wonderware Corporation" },
   {  362,   "Particle Measuring Systems, Inc." },
   {  363,   "Reserved" },
   {  364,   "Reserved" },
   {  365,   "BITS Co., Ltd" },
   {  366,   "Japan Aviation Electronics Industry Ltd" },
   {  367,   "Keyence Corporation" },
   {  368,   "Kuroda Precision Industries Ltd." },
   {  369,   "Mitsubishi Electric Semiconductor Application" },
   {  370,   "Nippon Seisen Cable, Ltd." },
   {  371,   "Omron ASO Co., Ltd" },
   {  372,   "Seiko Seiki Co., Ltd." },
   {  373,   "Sumitomo Heavy Industries, Ltd." },
   {  374,   "Tango Computer Service Corporation" },
   {  375,   "Technology Service, Inc." },
   {  376,   "Toshiba Information Systems (Japan) Corporation" },
   {  377,   "TOSHIBA Schneider Inverter Corporation" },
   {  378,   "Toyooki Kogyo Co., Ltd." },
   {  379,   "XEBEC" },
   {  380,   "Madison Cable Corporation" },
   {  381,   "Hitati Engineering & Services Co., Ltd" },
   {  382,   "TEM-TECH Lab Co., Ltd" },
   {  383,   "International Laboratory Corporation" },
   {  384,   "Dyadic Systems Co., Ltd." },
   {  385,   "SETO Electronics Industry Co., Ltd" },
   {  386,   "Tokyo Electron Kyushu Limited" },
   {  387,   "KEI System Co., Ltd" },
   {  388,   "Reserved" },
   {  389,   "Asahi Engineering Co., Ltd" },
   {  390,   "Contrex Inc." },
   {  391,   "Paradigm Controls Ltd." },
   {  392,   "Reserved" },
   {  393,   "Ohm Electric Co., Ltd." },
   {  394,   "RKC Instrument Inc." },
   {  395,   "Suzuki Motor Corporation" },
   {  396,   "Custom Servo Motors Inc." },
   {  397,   "PACE Control Systems" },
   {  398,   "Reserved" },
   {  399,   "Reserved" },
   {  400,   "LINTEC Co., Ltd." },
   {  401,   "Hitachi Cable Ltd." },
   {  402,   "BUSWARE Direct" },
   {  403,   "Eaton Electric B.V. (former Holec Holland N.V.)" },
   {  404,   "VAT Vakuumventile AG" },
   {  405,   "Scientific Technologies Incorporated" },
   {  406,   "Alfa Instrumentos Eletronicos Ltda" },
   {  407,   "TWK Elektronik GmbH" },
   {  408,   "ABB Welding Systems AB" },
   {  409,   "BYSTRONIC Maschinen AG" },
   {  410,   "Kimura Electric Co., Ltd" },
   {  411,   "Nissei Plastic Industrial Co., Ltd" },
   {  412,   "Reserved" },
   {  413,   "Kistler-Morse Corporation" },
   {  414,   "Proteous Industries Inc." },
   {  415,   "IDC Corporation" },
   {  416,   "Nordson Corporation" },
   {  417,   "Rapistan Systems" },
   {  418,   "LP-Elektronik GmbH" },
   {  419,   "GERBI & FASE S.p.A.(Fase Saldatura)" },
   {  420,   "Phoenix Digital Corporation" },
   {  421,   "Z-World Engineering" },
   {  422,   "Honda R&D Co., Ltd." },
   {  423,   "Bionics Instrument Co., Ltd." },
   {  424,   "Teknic, Inc." },
   {  425,   "R.Stahl, Inc." },
   {  426,   "Reserved" },
   {  427,   "Ryco Graphic Manufacturing Inc." },
   {  428,   "Giddings & Lewis, Inc." },
   {  429,   "Koganei Corporation" },
   {  430,   "Reserved" },
   {  431,   "Nichigoh Communication Electric Wire Co., Ltd." },
   {  432,   "Reserved" },
   {  433,   "Fujikura Ltd." },
   {  434,   "AD Link Technology Inc." },
   {  435,   "StoneL Corporation" },
   {  436,   "Computer Optical Products, Inc." },
   {  437,   "CONOS Inc." },
   {  438,   "Erhardt + Leimer GmbH" },
   {  439,   "UNIQUE Co. Ltd" },
   {  440,   "Roboticsware, Inc." },
   {  441,   "Nachi Fujikoshi Corporation" },
   {  442,   "Hengstler GmbH" },
   {  443,   "Reserved" },
   {  444,   "SUNNY GIKEN Inc." },
   {  445,   "Lenze Drive Systems GmbH" },
   {  446,   "CD Systems B.V." },
   {  447,   "FMT/Aircraft Gate Support Systems AB" },
   {  448,   "Axiomatic Technologies Corp" },
   {  449,   "Embedded System Products, Inc." },
   {  450,   "Reserved" },
   {  451,   "Mencom Corporation" },
   {  452,   "Reserved" },
   {  453,   "Matsushita Welding Systems Co., Ltd." },
   {  454,   "Dengensha Mfg. Co. Ltd." },
   {  455,   "Quinn Systems Ltd." },
   {  456,   "Tellima Technology Ltd" },
   {  457,   "MDT, Software" },
   {  458,   "Taiwan Keiso Co., Ltd" },
   {  459,   "Pinnacle Systems" },
   {  460,   "Ascom Hasler Mailing Sys" },
   {  461,   "INSTRUMAR Limited" },
   {  462,   "Reserved" },
   {  463,   "Navistar International Transportation Corp" },
   {  464,   "Huettinger Elektronik GmbH + Co. KG" },
   {  465,   "OCM Technology Inc." },
   {  466,   "Professional Supply Inc." },
   {  467,   "Control Solutions" },
   {  468,   "Baumer IVO GmbH & Co. KG" },
   {  469,   "Worcester Controls Corporation" },
   {  470,   "Pyramid Technical Consultants, Inc." },
   {  471,   "Reserved" },
   {  472,   "Apollo Fire Detectors Limited" },
   {  473,   "Avtron Manufacturing, Inc." },
   {  474,   "Reserved" },
   {  475,   "Tokyo Keiso Co., Ltd." },
   {  476,   "Daishowa Swiki Co., Ltd." },
   {  477,   "Kojima Instruments Inc." },
   {  478,   "Shimadzu Corporation" },
   {  479,   "Tatsuta Electric Wire & Cable Co., Ltd." },
   {  480,   "MECS Corporation" },
   {  481,   "Tahara Electric" },
   {  482,   "Koyo Electronics" },
   {  483,   "Clever Devices" },
   {  484,   "GCD Hardware & Software GmbH" },
   {  485,   "Reserved" },
   {  486,   "Miller Electric Mfg Co." },
   {  487,   "GEA Tuchenhagen GmbH" },
   {  488,   "Riken Keiki Co., LTD" },
   {  489,   "Keisokugiken Corporation" },
   {  490,   "Fuji Machine Mfg. Co., Ltd" },
   {  491,   "Reserved" },
   {  492,   "Nidec-Shimpo Corp." },
   {  493,   "UTEC Corporation" },
   {  494,   "Sanyo Electric Co. Ltd." },
   {  495,   "Reserved" },
   {  496,   "Reserved" },
   {  497,   "Okano Electric Wire Co. Ltd" },
   {  498,   "Shimaden Co. Ltd." },
   {  499,   "Teddington Controls Ltd" },
   {  500,   "Reserved" },
   {  501,   "VIPA GmbH" },
   {  502,   "Warwick Manufacturing Group" },
   {  503,   "Danaher Controls" },
   {  504,   "Reserved" },
   {  505,   "Reserved" },
   {  506,   "American Science & Engineering" },
   {  507,   "Accutron Controls International Inc." },
   {  508,   "Norcott Technologies Ltd" },
   {  509,   "TB Woods, Inc" },
   {  510,   "Proportion-Air, Inc." },
   {  511,   "SICK Stegmann GmbH" },
   {  512,   "Reserved" },
   {  513,   "Edwards Signaling" },
   {  514,   "Sumitomo Metal Industries, Ltd" },
   {  515,   "Cosmo Instruments Co., Ltd." },
   {  516,   "Denshosha Co., Ltd." },
   {  517,   "Kaijo Corp." },
   {  518,   "Michiproducts Co., Ltd." },
   {  519,   "Miura Corporation" },
   {  520,   "TG Information Network Co., Ltd." },
   {  521,   "Fujikin , Inc." },
   {  522,   "Estic Corp." },
   {  523,   "GS Hydraulic Sales" },
   {  524,   "Reserved" },
   {  525,   "MTE Limited" },
   {  526,   "Hyde Park Electronics, Inc." },
   {  527,   "Pfeiffer Vacuum GmbH" },
   {  528,   "Cyberlogic Technologies" },
   {  529,   "OKUMA Corporation FA Systems Division" },
   {  530,   "Reserved" },
   {  531,   "Hitachi Kokusai Electric Co., Ltd." },
   {  532,   "SHINKO TECHNOS Co., Ltd." },
   {  533,   "Itoh Electric Co., Ltd." },
   {  534,   "Colorado Flow Tech Inc." },
   {  535,   "Love Controls Division/Dwyer Inst." },
   {  536,   "Alstom Drives and Controls" },
   {  537,   "The Foxboro Company" },
   {  538,   "Tescom Corporation" },
   {  539,   "Reserved" },
   {  540,   "Atlas Copco Controls UK" },
   {  541,   "Reserved" },
   {  542,   "Autojet Technologies" },
   {  543,   "Prima Electronics S.p.A." },
   {  544,   "PMA GmbH" },
   {  545,   "Shimafuji Electric Co., Ltd" },
   {  546,   "Oki Electric Industry Co., Ltd" },
   {  547,   "Kyushu Matsushita Electric Co., Ltd" },
   {  548,   "Nihon Electric Wire & Cable Co., Ltd" },
   {  549,   "Tsuken Electric Ind Co., Ltd" },
   {  550,   "Tamadic Co." },
   {  551,   "MAATEL SA" },
   {  552,   "OKUMA America" },
   {  553,   "Control Techniques PLC-NA" },
   {  554,   "TPC Wire & Cable" },
   {  555,   "ATI Industrial Automation" },
   {  556,   "Microcontrol (Australia) Pty Ltd" },
   {  557,   "Serra Soldadura, S.A." },
   {  558,   "Southwest Research Institute" },
   {  559,   "Cabinplant International" },
   {  560,   "Sartorius Mechatronics T&H GmbH" },
   {  561,   "Comau S.p.A. Robotics & Final Assembly Division" },
   {  562,   "Phoenix Contact" },
   {  563,   "Yokogawa MAT Corporation" },
   {  564,   "asahi sangyo co., ltd." },
   {  565,   "Reserved" },
   {  566,   "Akita Myotoku Ltd." },
   {  567,   "OBARA Corp." },
   {  568,   "Suetron Electronic GmbH" },
   {  569,   "Reserved" },
   {  570,   "Serck Controls Limited" },
   {  571,   "Fairchild Industrial Products Company" },
   {  572,   "ARO S.A." },
   {  573,   "M2C GmbH" },
   {  574,   "Shin Caterpillar Mitsubishi Ltd." },
   {  575,   "Santest Co., Ltd." },
   {  576,   "Cosmotechs Co., Ltd." },
   {  577,   "Hitachi Electric Systems" },
   {  578,   "Smartscan Ltd" },
   {  579,   "Woodhead Software & Electronics France" },
   {  580,   "Athena Controls, Inc." },
   {  581,   "Syron Engineering & Manufacturing, Inc." },
   {  582,   "Asahi Optical Co., Ltd." },
   {  583,   "Sansha Electric Mfg. Co., Ltd." },
   {  584,   "Nikki Denso Co., Ltd." },
   {  585,   "Star Micronics, Co., Ltd." },
   {  586,   "Ecotecnia Socirtat Corp." },
   {  587,   "AC Technology Corp." },
   {  588,   "West Instruments Limited" },
   {  589,   "NTI Limited" },
   {  590,   "Delta Computer Systems, Inc." },
   {  591,   "FANUC Ltd." },
   {  592,   "Hearn-Gu Lee" },
   {  593,   "ABB Automation Products" },
   {  594,   "Orion Machinery Co., Ltd." },
   {  595,   "Reserved" },
   {  596,   "Wire-Pro, Inc." },
   {  597,   "Beijing Huakong Technology Co. Ltd." },
   {  598,   "Yokoyama Shokai Co., Ltd." },
   {  599,   "Toyogiken Co., Ltd." },
   {  600,   "Coester Equipamentos Eletronicos Ltda." },
   {  601,   "Reserved" },
   {  602,   "Electroplating Engineers of Japan Ltd." },
   {  603,   "ROBOX S.p.A." },
   {  604,   "Spraying Systems Company" },
   {  605,   "Benshaw Inc." },
   {  606,   "ZPA-DP A.S." },
   {  607,   "Wired Rite Systems" },
   {  608,   "Tandis Research, Inc." },
   {  609,   "SSD Drives GmbH" },
   {  610,   "ULVAC Japan Ltd." },
   {  611,   "DYNAX Corporation" },
   {  612,   "Nor-Cal Products, Inc." },
   {  613,   "Aros Electronics AB" },
   {  614,   "Jun-Tech Co., Ltd." },
   {  615,   "HAN-MI Co. Ltd." },
   {  616,   "uniNtech (formerly SungGi Internet)" },
   {  617,   "Hae Pyung Electronics Reserch Institute" },
   {  618,   "Milwaukee Electronics" },
   {  619,   "OBERG Industries" },
   {  620,   "Parker Hannifin/Compumotor Division" },
   {  621,   "TECHNO DIGITAL CORPORATION" },
   {  622,   "Network Supply Co., Ltd." },
   {  623,   "Union Electronics Co., Ltd." },
   {  624,   "Tritronics Services PM Ltd." },
   {  625,   "Rockwell Automation-Sprecher+Schuh" },
   {  626,   "Matsushita Electric Industrial Co., Ltd/Motor Co." },
   {  627,   "Rolls-Royce Energy Systems, Inc." },
   {  628,   "JEONGIL INTERCOM CO., LTD" },
   {  629,   "Interroll Corp." },
   {  630,   "Hubbell Wiring Device-Kellems (Delaware)" },
   {  631,   "Intelligent Motion Systems" },
   {  632,   "Reserved" },
   {  633,   "INFICON AG" },
   {  634,   "Hirschmann, Inc." },
   {  635,   "The Siemon Company" },
   {  636,   "YAMAHA Motor Co. Ltd." },
   {  637,   "aska corporation" },
   {  638,   "Woodhead Connectivity" },
   {  639,   "Trimble AB" },
   {  640,   "Murrelektronik GmbH" },
   {  641,   "Creatrix Labs, Inc." },
   {  642,   "TopWorx" },
   {  643,   "Kumho Industrial Co., Ltd." },
   {  644,   "Wind River Systems, Inc." },
   {  645,   "Bihl & Wiedemann GmbH" },
   {  646,   "Harmonic Drive Systems Inc." },
   {  647,   "Rikei Corporation" },
   {  648,   "BL Autotec, Ltd." },
   {  649,   "Hana Information & Technology Co., Ltd." },
   {  650,   "Seoil Electric Co., Ltd." },
   {  651,   "Fife Corporation" },
   {  652,   "Shanghai Electrical Apparatus Research Institute" },
   {  653,   "Reserved" },
   {  654,   "Parasense Development Centre" },
   {  655,   "Reserved" },
   {  656,   "Reserved" },
   {  657,   "Six Tau S.p.A." },
   {  658,   "Aucos GmbH" },
   {  659,   "Rotork Controls" },
   {  660,   "Automationdirect.com" },
   {  661,   "Thermo BLH" },
   {  662,   "System Controls, Ltd." },
   {  663,   "Univer S.p.A." },
   {  664,   "MKS-Tenta Technology" },
   {  665,   "Lika Electronic SNC" },
   {  666,   "Mettler-Toledo, Inc." },
   {  667,   "DXL USA Inc." },
   {  668,   "Rockwell Automation/Entek IRD Intl." },
   {  669,   "Nippon Otis Elevator Company" },
   {  670,   "Sinano Electric, Co., Ltd." },
   {  671,   "Sony Manufacturing Systems" },
   {  672,   "Reserved" },
   {  673,   "Contec Co., Ltd." },
   {  674,   "Automated Solutions" },
   {  675,   "Controlweigh" },
   {  676,   "Reserved" },
   {  677,   "Fincor Electronics" },
   {  678,   "Cognex Corporation" },
   {  679,   "Qualiflow" },
   {  680,   "Weidmuller, Inc." },
   {  681,   "Morinaga Milk Industry Co., Ltd." },
   {  682,   "Takagi Industrial Co., Ltd." },
   {  683,   "Wittenstein AG" },
   {  684,   "Sena Technologies, Inc." },
   {  685,   "Reserved" },
   {  686,   "APV Products Unna" },
   {  687,   "Creator Teknisk Utvedkling AB" },
   {  688,   "Reserved" },
   {  689,   "Mibu Denki Industrial Co., Ltd." },
   {  690,   "Takamastsu Machineer Section" },
   {  691,   "Startco Engineering Ltd." },
   {  692,   "Reserved" },
   {  693,   "Holjeron" },
   {  694,   "ALCATEL High Vacuum Technology" },
   {  695,   "Taesan LCD Co., Ltd." },
   {  696,   "POSCON" },
   {  697,   "VMIC" },
   {  698,   "Matsushita Electric Works, Ltd." },
   {  699,   "IAI Corporation" },
   {  700,   "Horst GmbH" },
   {  701,   "MicroControl GmbH & Co." },
   {  702,   "Leine & Linde AB" },
   {  703,   "Reserved" },
   {  704,   "EC Elettronica Srl" },
   {  705,   "VIT Software HB" },
   {  706,   "Bronkhorst High-Tech B.V." },
   {  707,   "Optex Co., Ltd." },
   {  708,   "Yosio Electronic Co." },
   {  709,   "Terasaki Electric Co., Ltd." },
   {  710,   "Sodick Co., Ltd." },
   {  711,   "MTS Systems Corporation-Automation Division" },
   {  712,   "Mesa Systemtechnik" },
   {  713,   "SHIN HO SYSTEM Co., Ltd." },
   {  714,   "Goyo Electronics Co, Ltd." },
   {  715,   "Loreme" },
   {  716,   "SAB Brockskes GmbH & Co. KG" },
   {  717,   "Trumpf Laser GmbH + Co. KG" },
   {  718,   "Niigata Electronic Instruments Co., Ltd." },
   {  719,   "Yokogawa Digital Computer Corporation" },
   {  720,   "O.N. Electronic Co., Ltd." },
   {  721,   "Industrial Control  Communication, Inc." },
   {  722,   "ABB, Inc." },
   {  723,   "ElectroWave USA, Inc." },
   {  724,   "Industrial Network Controls, LLC" },
   {  725,   "KDT Systems Co., Ltd." },
   {  726,   "SEFA Technology Inc." },
   {  727,   "Nippon POP Rivets and Fasteners Ltd." },
   {  728,   "Yamato Scale Co., Ltd." },
   {  729,   "Zener Electric" },
   {  730,   "GSE Scale Systems" },
   {  731,   "ISAS (Integrated Switchgear & Sys. Pty Ltd)" },
   {  732,   "Beta LaserMike Limited" },
   {  733,   "TOEI Electric Co., Ltd." },
   {  734,   "Hakko Electronics Co., Ltd" },
   {  735,   "Reserved" },
   {  736,   "RFID, Inc." },
   {  737,   "Adwin Corporation" },
   {  738,   "Osaka Vacuum, Ltd." },
   {  739,   "A-Kyung Motion, Inc." },
   {  740,   "Camozzi S.P. A." },
   {  741,   "Crevis Co., LTD" },
   {  742,   "Rice Lake Weighing Systems" },
   {  743,   "Linux Network Services" },
   {  744,   "KEB Antriebstechnik GmbH" },
   {  745,   "Hagiwara Electric Co., Ltd." },
   {  746,   "Glass Inc. International" },
   {  747,   "Reserved" },
   {  748,   "DVT Corporation" },
   {  749,   "Woodward Governor" },
   {  750,   "Mosaic Systems, Inc." },
   {  751,   "Laserline GmbH" },
   {  752,   "COM-TEC, Inc." },
   {  753,   "Weed Instrument" },
   {  754,   "Prof-face European Technology Center" },
   {  755,   "Fuji Automation Co., Ltd." },
   {  756,   "Matsutame Co., Ltd." },
   {  757,   "Hitachi Via Mechanics, Ltd." },
   {  758,   "Dainippon Screen Mfg. Co. Ltd." },
   {  759,   "FLS Automation A/S" },
   {  760,   "ABB Stotz Kontakt GmbH" },
   {  761,   "Technical Marine Service" },
   {  762,   "Advanced Automation Associates, Inc." },
   {  763,   "Baumer Ident GmbH" },
   {  764,   "Tsubakimoto Chain Co." },
   {  765,   "Reserved" },
   {  766,   "Furukawa Co., Ltd." },
   {  767,   "Active Power" },
   {  768,   "CSIRO Mining Automation" },
   {  769,   "Matrix Integrated Systems" },
   {  770,   "Digitronic Automationsanlagen GmbH" },
   {  771,   "SICK STEGMANN Inc." },
   {  772,   "TAE-Antriebstechnik GmbH" },
   {  773,   "Electronic Solutions" },
   {  774,   "Rocon L.L.C." },
   {  775,   "Dijitized Communications Inc." },
   {  776,   "Asahi Organic Chemicals Industry Co., Ltd." },
   {  777,   "Hodensha" },
   {  778,   "Harting, Inc. NA" },
   {  779,   "Kubler GmbH" },
   {  780,   "Yamatake Corporation" },
   {  781,   "JEOL" },
   {  782,   "Yamatake Industrial Systems Co., Ltd." },
   {  783,   "HAEHNE Elektronische Messgerate GmbH" },
   {  784,   "Ci Technologies Pty Ltd (for Pelamos Industries)" },
   {  785,   "N. SCHLUMBERGER & CIE" },
   {  786,   "Teijin Seiki Co., Ltd." },
   {  787,   "DAIKIN Industries, Ltd" },
   {  788,   "RyuSyo Industrial Co., Ltd." },
   {  789,   "SAGINOMIYA SEISAKUSHO, INC." },
   {  790,   "Seishin Engineering Co., Ltd." },
   {  791,   "Japan Support System Ltd." },
   {  792,   "Decsys" },
   {  793,   "Metronix Messgerate u. Elektronik GmbH" },
   {  794,   "Reserved" },
   {  795,   "Vaccon Company, Inc." },
   {  796,   "Siemens Energy & Automation, Inc." },
   {  797,   "Ten X Technology, Inc." },
   {  798,   "Tyco Electronics" },
   {  799,   "Delta Power Electronics Center" },
   {  800,   "Denker" },
   {  801,   "Autonics Corporation" },
   {  802,   "JFE Electronic Engineering Pty. Ltd." },
   {  803,   "Reserved" },
   {  804,   "Electro-Sensors, Inc." },
   {  805,   "Digi International, Inc." },
   {  806,   "Texas Instruments" },
   {  807,   "ADTEC Plasma Technology Co., Ltd" },
   {  808,   "SICK AG" },
   {  809,   "Ethernet Peripherals, Inc." },
   {  810,   "Animatics Corporation" },
   {  811,   "Reserved" },
   {  812,   "Process Control Corporation" },
   {  813,   "SystemV. Inc." },
   {  814,   "Danaher Motion SRL" },
   {  815,   "SHINKAWA Sensor Technology, Inc." },
   {  816,   "Tesch GmbH & Co. KG" },
   {  817,   "Reserved" },
   {  818,   "Trend Controls Systems Ltd." },
   {  819,   "Guangzhou ZHIYUAN Electronic Co., Ltd." },
   {  820,   "Mykrolis Corporation" },
   {  821,   "Bethlehem Steel Corporation" },
   {  822,   "KK ICP" },
   {  823,   "Takemoto Denki Corporation" },
   {  824,   "The Montalvo Corporation" },
   {  825,   "Reserved" },
   {  826,   "LEONI Special Cables GmbH" },
   {  827,   "Reserved" },
   {  828,   "ONO SOKKI CO.,LTD." },
   {  829,   "Rockwell Samsung Automation" },
   {  830,   "SHINDENGEN ELECTRIC MFG. CO. LTD" },
   {  831,   "Origin Electric Co. Ltd." },
   {  832,   "Quest Technical Solutions, Inc." },
   {  833,   "LS Cable, Ltd." },
   {  834,   "Enercon-Nord Electronic GmbH" },
   {  835,   "Northwire Inc." },
   {  836,   "Engel Elektroantriebe GmbH" },
   {  837,   "The Stanley Works" },
   {  838,   "Celesco Transducer Products, Inc." },
   {  839,   "Chugoku Electric Wire and Cable Co." },
   {  840,   "Kongsberg Simrad AS" },
   {  841,   "Panduit Corporation" },
   {  842,   "Spellman High Voltage Electronics Corp." },
   {  843,   "Kokusai Electric Alpha Co., Ltd." },
   {  844,   "Brooks Automation, Inc." },
   {  845,   "ANYWIRE CORPORATION" },
   {  846,   "Honda Electronics Co. Ltd" },
   {  847,   "REO Elektronik AG" },
   {  848,   "Fusion UV Systems, Inc." },
   {  849,   "ASI Advanced Semiconductor Instruments GmbH" },
   {  850,   "Datalogic, Inc." },
   {  851,   "SoftPLC Corporation" },
   {  852,   "Dynisco Instruments LLC" },
   {  853,   "WEG Industrias SA" },
   {  854,   "Frontline Test Equipment, Inc." },
   {  855,   "Tamagawa Seiki Co., Ltd." },
   {  856,   "Multi Computing Co., Ltd." },
   {  857,   "RVSI" },
   {  858,   "Commercial Timesharing Inc." },
   {  859,   "Tennessee Rand Automation LLC" },
   {  860,   "Wacogiken Co., Ltd" },
   {  861,   "Reflex Integration Inc." },
   {  862,   "Siemens AG, A&D PI Flow Instruments" },
   {  863,   "G. Bachmann Electronic GmbH" },
   {  864,   "NT International" },
   {  865,   "Schweitzer Engineering Laboratories" },
   {  866,   "ATR Industrie-Elektronik GmbH Co." },
   {  867,   "PLASMATECH Co., Ltd" },
   {  868,   "Reserved" },
   {  869,   "GEMU GmbH & Co. KG" },
   {  870,   "Alcorn McBride Inc." },
   {  871,   "MORI SEIKI CO., LTD" },
   {  872,   "NodeTech Systems Ltd" },
   {  873,   "Emhart Teknologies" },
   {  874,   "Cervis, Inc." },
   {  875,   "FieldServer Technologies (Div Sierra Monitor Corp)" },
   {  876,   "NEDAP Power Supplies" },
   {  877,   "Nippon Sanso Corporation" },
   {  878,   "Mitomi Giken Co., Ltd." },
   {  879,   "PULS GmbH" },
   {  880,   "Reserved" },
   {  881,   "Japan Control Engineering Ltd" },
   {  882,   "Embedded Systems Korea (Former Zues Emtek Co Ltd.)" },
   {  883,   "Automa SRL" },
   {  884,   "Harms+Wende GmbH & Co KG" },
   {  885,   "SAE-STAHL GmbH" },
   {  886,   "Microwave Data Systems" },
   {  887,   "B&R Industrial Automation GmbH" },
   {  888,   "Hiprom Technologies" },
   {  889,   "Reserved" },
   {  890,   "Nitta Corporation" },
   {  891,   "Kontron Modular Computers GmbH" },
   {  892,   "Marlin Controls" },
   {  893,   "ELCIS s.r.l." },
   {  894,   "Acromag, Inc." },
   {  895,   "Avery Weigh-Tronix" },
   {  896,   "Reserved" },
   {  897,   "Reserved" },
   {  898,   "Reserved" },
   {  899,   "Practicon Ltd" },
   {  900,   "Schunk GmbH & Co. KG" },
   {  901,   "MYNAH Technologies" },
   {  902,   "Defontaine Groupe" },
   {  903,   "Emerson Process Management Power & Water Solutions" },
   {  904,   "F.A. Elec" },
   {  905,   "Hottinger Baldwin Messtechnik GmbH" },
   {  906,   "Coreco Imaging, Inc." },
   {  907,   "London Electronics Ltd." },
   {  908,   "HSD SpA" },
   {  909,   "Comtrol Corporation" },
   {  910,   "TEAM, S.A. (Tecnica Electronica de Automatismo Y Medida)" },
   {  911,   "MAN B&W Diesel Ltd. Regulateurs Europa" },
   {  912,   "Reserved" },
   {  913,   "Reserved" },
   {  914,   "Micro Motion, Inc." },
   {  915,   "Eckelmann AG" },
   {  916,   "Hanyoung Nux" },
   {  917,   "Ransburg Industrial Finishing KK" },
   {  918,   "Kun Hung Electric Co. Ltd." },
   {  919,   "Brimos wegbebakening b.v." },
   {  920,   "Nitto Seiki Co., Ltd" },
   {  921,   "PPT Vision, Inc." },
   {  922,   "Yamazaki Machinery Works" },
   {  923,   "SCHMIDT Technology GmbH" },
   {  924,   "Parker Hannifin SpA (SBC Division)" },
   {  925,   "HIMA Paul Hildebrandt GmbH" },
   {  926,   "RivaTek, Inc." },
   {  927,   "Misumi Corporation" },
   {  928,   "GE Multilin" },
   {  929,   "Measurement Computing Corporation" },
   {  930,   "Jetter AG" },
   {  931,   "Tokyo Electronics Systems Corporation" },
   {  932,   "Togami Electric Mfg. Co., Ltd." },
   {  933,   "HK Systems" },
   {  934,   "CDA Systems Ltd." },
   {  935,   "Aerotech Inc." },
   {  936,   "JVL Industrie Elektronik A/S" },
   {  937,   "NovaTech Process Solutions LLC" },
   {  938,   "Reserved" },
   {  939,   "Cisco Systems" },
   {  940,   "Grid Connect" },
   {  941,   "ITW Automotive Finishing" },
   {  942,   "HanYang System" },
   {  943,   "ABB K.K. Technical Center" },
   {  944,   "Taiyo Electric Wire & Cable Co., Ltd." },
   {  945,   "Reserved" },
   {  946,   "SEREN IPS INC" },
   {  947,   "Belden CDT Electronics Division" },
   {  948,   "ControlNet International" },
   {  949,   "Gefran S.P.A." },
   {  950,   "Jokab Safety AB" },
   {  951,   "SUMITA OPTICAL GLASS, INC." },
   {  952,   "Biffi Italia srl" },
   {  953,   "Beck IPC GmbH" },
   {  954,   "Copley Controls Corporation" },
   {  955,   "Fagor Automation S. Coop." },
   {  956,   "DARCOM" },
   {  957,   "Frick Controls (div. of York International)" },
   {  958,   "SymCom, Inc." },
   {  959,   "Infranor" },
   {  960,   "Kyosan Cable, Ltd." },
   {  961,   "Varian Vacuum Technologies" },
   {  962,   "Messung Systems" },
   {  963,   "Xantrex Technology, Inc." },
   {  964,   "StarThis Inc." },
   {  965,   "Chiyoda Co., Ltd." },
   {  966,   "Flowserve Corporation" },
   {  967,   "Spyder Controls Corp." },
   {  968,   "IBA AG" },
   {  969,   "SHIMOHIRA ELECTRIC MFG.CO.,LTD" },
   {  970,   "Reserved" },
   {  971,   "Siemens L&A" },
   {  972,   "Micro Innovations AG" },
   {  973,   "Switchgear & Instrumentation" },
   {  974,   "PRE-TECH CO., LTD." },
   {  975,   "National Semiconductor" },
   {  976,   "Invensys Process Systems" },
   {  977,   "Ametek HDR Power Systems" },
   {  978,   "Reserved" },
   {  979,   "TETRA-K Corporation" },
   {  980,   "C & M Corporation" },
   {  981,   "Siempelkamp Maschinen" },
   {  982,   "Reserved" },
   {  983,   "Daifuku America Corporation" },
   {  984,   "Electro-Matic Products Inc." },
   {  985,   "BUSSAN MICROELECTRONICS CORP." },
   {  986,   "ELAU AG" },
   {  987,   "Hetronic USA" },
   {  988,   "NIIGATA POWER SYSTEMS Co., Ltd." },
   {  989,   "Software Horizons Inc." },
   {  990,   "B3 Systems, Inc." },
   {  991,   "Moxa Networking Co., Ltd." },
   {  992,   "Reserved" },
   {  993,   "S4 Integration" },
   {  994,   "Elettro Stemi S.R.L." },
   {  995,   "AquaSensors" },
   {  996,   "Ifak System GmbH" },
   {  997,   "SANKEI MANUFACTURING Co.,LTD." },
   {  998,   "Emerson Network Power Co., Ltd." },
   {  999,   "Fairmount Automation, Inc." },
   { 1000,   "Bird Electronic Corporation" },
   { 1001,   "Nabtesco Corporation" },
   { 1002,   "AGM Electronics, Inc." },
   { 1003,   "ARCX Inc." },
   { 1004,   "DELTA I/O Co." },
   { 1005,   "Chun IL Electric Ind. Co." },
   { 1006,   "N-Tron" },
   { 1007,   "Nippon Pneumatics/Fludics System CO.,LTD." },
   { 1008,   "DDK Ltd." },
   { 1009,   "Seiko Epson Corporation" },
   { 1010,   "Halstrup-Walcher GmbH" },
   { 1011,   "ITT" },
   { 1012,   "Ground Fault Systems bv" },
   { 1013,   "Scolari Engineering S.p.A." },
   { 1014,   "Vialis Traffic bv" },
   { 1015,   "Weidmueller Interface GmbH & Co. KG" },
   { 1016,   "Shanghai Sibotech Automation Co. Ltd" },
   { 1017,   "AEG Power Supply Systems GmbH" },
   { 1018,   "Komatsu Electronics Inc." },
   { 1019,   "Souriau" },
   { 1020,   "Baumuller Chicago Corp." },
   { 1021,   "J. Schmalz GmbH" },
   { 1022,   "SEN Corporation" },
   { 1023,   "Korenix Technology Co. Ltd" },
   { 1024,   "Cooper Power Tools" },
   { 1025,   "INNOBIS" },
   { 1026,   "Shinho System" },
   { 1027,   "Xm Services Ltd." },
   { 1028,   "KVC Co., Ltd." },
   { 1029,   "Sanyu Seiki Co., Ltd." },
   { 1030,   "TuxPLC" },
   { 1031,   "Northern Network Solutions" },
   { 1032,   "Converteam GmbH" },
   { 1033,   "Symbol Technologies" },
   { 1034,   "S-TEAM Lab" },
   { 1035,   "Maguire Products, Inc." },
   { 1036,   "AC&T" },
   { 1037,   "MITSUBISHI HEAVY INDUSTRIES, LTD. KOBE SHIPYARD & MACHINERY WORKS" },
   { 1038,   "Hurletron Inc." },
   { 1039,   "Chunichi Denshi Co., Ltd" },
   { 1040,   "Cardinal Scale Mfg. Co." },
   { 1041,   "BTR NETCOM via RIA Connect, Inc." },
   { 1042,   "Base2" },
   { 1043,   "ASRC Aerospace" },
   { 1044,   "Beijing Stone Automation" },
   { 1045,   "Changshu Switchgear Manufacture Ltd." },
   { 1046,   "METRONIX Corp." },
   { 1047,   "WIT" },
   { 1048,   "ORMEC Systems Corp." },
   { 1049,   "ASATech (China) Inc." },
   { 1050,   "Controlled Systems Limited" },
   { 1051,   "Mitsubishi Heavy Ind. Digital System Co., Ltd. (M.H.I.)" },
   { 1052,   "Electrogrip" },
   { 1053,   "TDS Automation" },
   { 1054,   "T&C Power Conversion, Inc." },
   { 1055,   "Robostar Co., Ltd" },
   { 1056,   "Scancon A/S" },
   { 1057,   "Haas Automation, Inc." },
   { 1058,   "Eshed Technology" },
   { 1059,   "Delta Electronic Inc." },
   { 1060,   "Innovasic Semiconductor" },
   { 1061,   "SoftDEL Systems Limited" },
   { 1062,   "FiberFin, Inc." },
   { 1063,   "Nicollet Technologies Corp." },
   { 1064,   "B.F. Systems" },
   { 1065,   "Empire Wire and Supply LLC" },
   { 1066,   "Reserved" },
   { 1067,   "Elmo Motion Control LTD" },
   { 1068,   "Reserved" },
   { 1069,   "Asahi Keiki Co., Ltd." },
   { 1070,   "Joy Mining Machinery" },
   { 1071,   "MPM Engineering Ltd" },
   { 1072,   "Wolke Inks & Printers GmbH" },
   { 1073,   "Mitsubishi Electric Engineering Co., Ltd." },
   { 1074,   "COMET AG" },
   { 1075,   "Real Time Objects & Systems, LLC" },
   { 1076,   "MISCO Refractometer" },
   { 1077,   "JT Engineering Inc." },
   { 1078,   "Automated Packing Systems" },
   { 1079,   "Niobrara R&D Corp." },
   { 1080,   "Garmin Ltd." },
   { 1081,   "Japan Mobile Platform Co., Ltd" },
   { 1082,   "Advosol Inc." },
   { 1083,   "ABB Global Services Limited" },
   { 1084,   "Sciemetric Instruments Inc." },
   { 1085,   "Tata Elxsi Ltd." },
   { 1086,   "TPC Mechatronics, Co., Ltd." },
   { 1087,   "Cooper Bussmann" },
   { 1088,   "Trinite Automatisering B.V." },
   { 1089,   "Peek Traffic B.V." },
   { 1090,   "Acrison, Inc" },
   { 1091,   "Applied Robotics, Inc." },
   { 1092,   "FireBus Systems, Inc." },
   { 1093,   "Beijing Sevenstar Huachuang Electronics" },
   { 1094,   "Magnetek" },
   { 1095,   "Microscan" },
   { 1096,   "Air Water Inc." },
   { 1097,   "Sensopart Industriesensorik GmbH" },
   { 1098,   "Tiefenbach Control Systems GmbH" },
   { 1099,   "INOXPA S.A" },
   { 1100,   "Zurich University of Applied Sciences" },
   { 1101,   "Ethernet Direct" },
   { 1102,   "GSI-Micro-E Systems" },
   { 1103,   "S-Net Automation Co., Ltd." },
   { 1104,   "Power Electronics S.L." },
   { 1105,   "Renesas Technology Corp." },
   { 1106,   "NSWCCD-SSES" },
   { 1107,   "Porter Engineering Ltd." },
   { 1108,   "Meggitt Airdynamics, Inc." },
   { 1109,   "Inductive Automation" },
   { 1110,   "Neural ID" },
   { 1111,   "EEPod LLC" },
   { 1112,   "Hitachi Industrial Equipment Systems Co., Ltd." },
   { 1113,   "Salem Automation" },
   { 1114,   "port GmbH" },
   { 1115,   "B & PLUS" },
   { 1116,   "Graco Inc." },
   { 1117,   "Altera Corporation" },
   { 1118,   "Technology Brewing Corporation" },
   { 1121,   "CSE Servelec" },
   { 1124,   "Fluke Networks" },
   { 1125,   "Tetra Pak Packaging Solutions SPA" },
   { 1126,   "Racine Federated, Inc." },
   { 1127,   "Pureron Japan Co., Ltd." },
   { 1130,   "Brother Industries, Ltd." },
   { 1132,   "Leroy Automation" },
   { 1134,   "THK CO., LTD." },
   { 1137,   "TR-Electronic GmbH" },
   { 1138,   "ASCON S.p.A." },
   { 1139,   "Toledo do Brasil Industria de Balancas Ltda." },
   { 1140,   "Bucyrus DBT Europe GmbH" },
   { 1141,   "Emerson Process Management Valve Automation" },
   { 1142,   "Alstom Transport" },
   { 1144,   "Matrox Electronic Systems" },
   { 1145,   "Littelfuse" },
   { 1146,   "PLASMART, Inc." },
   { 1147,   "Miyachi Corporation" },
   { 1150,   "Promess Incorporated" },
   { 1151,   "COPA-DATA GmbH" },
   { 1152,   "Precision Engine Controls Corporation" },
   { 1153,   "Alga Automacao e controle LTDA" },
   { 1154,   "U.I. Lapp GmbH" },
   { 1155,   "ICES" },
   { 1156,   "Philips Lighting bv" },
   { 1157,   "Aseptomag AG" },
   { 1158,   "ARC Informatique" },
   { 1159,   "Hesmor GmbH" },
   { 1160,   "Kobe Steel, Ltd." },
   { 1161,   "FLIR Systems" },
   { 1162,   "Simcon A/S" },
   { 1163,   "COPALP" },
   { 1164,   "Zypcom, Inc." },
   { 1165,   "Swagelok" },
   { 1166,   "Elspec" },
   { 1167,   "ITT Water & Wastewater AB" },
   { 1168,   "Kunbus GmbH Industrial Communication" },
   { 1170,   "Performance Controls, Inc." },
   { 1171,   "ACS Motion Control, Ltd." },
   { 1173,   "IStar Technology Limited" },
   { 1174,   "Alicat Scientific, Inc." },
   { 1176,   "ADFweb.com SRL" },
   { 1177,   "Tata Consultancy Services Limited" },
   { 1178,   "CXR Ltd." },
   { 1179,   "Vishay Nobel AB" },
   { 1181,   "SolaHD" },
   { 1182,   "Endress+Hauser" },
   { 1183,   "Bartec GmbH" },
   { 1185,   "AccuSentry, Inc." },
   { 1186,   "Exlar Corporation" },
   { 1187,   "ILS Technology" },
   { 1188,   "Control Concepts Inc." },
   { 1190,   "Procon Engineering Limited" },
   { 1191,   "Hermary Opto Electronics Inc." },
   { 1192,   "Q-Lambda" },
   { 1194,   "VAMP Ltd" },
   { 1195,   "FlexLink" },
   { 1196,   "Office FA.com Co., Ltd." },
   { 1197,   "SPMC (Changzhou) Co. Ltd." },
   { 1198,   "Anton Paar GmbH" },
   { 1199,   "Zhuzhou CSR Times Electric Co., Ltd." },
   { 1200,   "DeStaCo" },
   { 1201,   "Synrad, Inc" },
   { 1202,   "Bonfiglioli Vectron GmbH" },
   { 1203,   "Pivotal Systems" },
   { 1204,   "TKSCT" },
   { 1205,   "Randy Nuernberger" },
   { 1206,   "CENTRALP" },
   { 1207,   "Tengen Group" },
   { 1208,   "OES, Inc." },
   { 1209,   "Actel Corporation" },
   { 1210,   "Monaghan Engineering, Inc." },
   { 1211,   "wenglor sensoric gmbh" },
   { 1212,   "HSA Systems" },
   { 1213,   "MK Precision Co., Ltd." },
   { 1214,   "Tappan Wire and Cable" },
   { 1215,   "Heinzmann GmbH & Co. KG" },
   { 1216,   "Process Automation International Ltd." },
   { 1217,   "Secure Crossing" },
   { 1218,   "SMA Railway Technology GmbH" },
   { 1219,   "FMS Force Measuring Systems AG" },
   { 1220,   "ABT Endustri Enerji Sistemleri Sanayi Tic. Ltd. Sti." },
   { 1221,   "MagneMotion Inc." },
   { 1222,   "STS Co., Ltd." },
   { 1223,   "MERAK SIC, SA" },
   { 1224,   "ABOUNDI, Inc." },
   { 1225,   "Rosemount Inc." },
   { 1226,   "GEA FES, Inc." },
   { 1227,   "TMG Technologie und Engineering GmbH" },
   { 1228,   "embeX GmbH" },
   { 1229,   "GH Electrotermia, S.A." },
   { 1230,   "Tolomatic" },
   { 1231,   "Dukane" },
   { 1232,   "Elco (Tian Jin) Electronics Co., Ltd." },
   { 1233,   "Jacobs Automation" },
   { 1234,   "Noda Radio Frequency Technologies Co., Ltd." },
   { 1235,   "MSC Tuttlingen GmbH" },
   { 1236,   "Hitachi Cable Manchester" },
   { 1237,   "ACOREL SAS" },
   { 1238,   "Global Engineering Solutions Co., Ltd." },
   { 1239,   "ALTE Transportation, S.L." },
   { 1240,   "Penko Engineering B.V." },

   { 0, NULL }
};

bool Utils::readEthernetIPDeviceInfo(char *device_ip, u_int8_t timeout_sec, lua_State *vm) {
  struct hostent *server = NULL;
  struct sockaddr_in serv_addr;
  int sockfd = -1;
  int retval;
  bool rc = false;
  struct timeval tv_timeout;
  u_char response[512], etherip_query[] = {
    0x63, 0x0,           /* Command */
    0x0,  0x0,           /* Lenght  */
    0x0,  0x0, 0x0, 0x0, /* Session */
    0x0,  0x0, 0x0, 0x0, /* Status  */
    0x0,  0x0,           /* Max Rsp Delay  */
    0x0,  0x0, 0xc1, 0xde, 0xbe, 0xd1, /* Sender Content */
    0x0,  0x0, 0x0, 0x0 /* Options */
  };

  server = gethostbyname(device_ip);
  if(server == NULL) return(false);

  sockfd = Utils::openSocket(AF_INET, SOCK_DGRAM, 0, "readEtheripDeviceInfo");

  if(sockfd < 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create socket");
    return(false);
  }

  rc = true;

  memset((char *)&serv_addr, 0, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  memcpy((char *)&serv_addr.sin_addr.s_addr, (char *)server->h_addr, server->h_length);
  serv_addr.sin_port = htons(44818);

  retval = sendto(sockfd, (const char*) etherip_query, sizeof(etherip_query),
	      0, (struct sockaddr *)&serv_addr,
	      sizeof(serv_addr));

  if(retval <= 0)
    rc = false;
  else {
    fd_set rset;
    int ret;

    tv_timeout.tv_sec = timeout_sec, tv_timeout.tv_usec = 0;

    FD_ZERO(&rset);
    FD_SET(sockfd, &rset);
    ret = select(sockfd + 1, &rset, NULL, NULL, &tv_timeout);

    if(ret > 0) {
      struct sockaddr_in from;
      socklen_t from_len = sizeof(from);
      int len = recvfrom(sockfd, (char *)response, sizeof(response), 0,
			 (struct sockaddr *)&from, &from_len);

      lua_newtable(vm);

      ntop->getTrace()->traceEvent(TRACE_INFO, "Read %u bytes", len);

      if(len > 24 /* EtherIP/TCP Len */) {
	u_int16_t response_id  = /* ntohs */(*((u_int16_t*)&response[0]));
	u_int16_t response_len = /* ntohs */(*((u_int16_t*)&response[2]));

	if((response_id == 0x63) /* List Indentity */
	   && ((response_len + 24) <= len)) {
	  u_int16_t offset = 24;
	  u_int16_t num_objects = /* ntohs */(*((u_int16_t*)&response[offset]));

	  while(num_objects > 0) {
	    u_int16_t type_id     = /* ntohs */(*((u_int16_t*)&response[offset+2]));
	    u_int8_t l;
	    u_int16_t object_len = /* ntohs */(*((u_int16_t*)&response[offset+4]));

	    if((type_id == 0x0c /* CIP Identity */) && ((object_len+offset) < len)) {
	      offset += 6;
	      l = /* ntohs */(*((u_int16_t*)&response[offset])); offset += 2;

	      if(l == 1 /* Protocol version */) {
		char str[64];
		u_int32_t u32;
		bool found = false;

		offset += 16; /* Skip socket address */

		l = /* ntohs */(*((u_int16_t*)&response[offset])); offset += 2;
		for(int i=0; vendors[i].name != NULL; i++) {
		  if(vendors[i].value == l) {
		    lua_push_str_table_entry(vm, "vendor_id", vendors[i].name);
		    found = true;
		    break;
		  }
		}

		if(!found)
		  lua_push_int32_table_entry(vm, "vendor_id", l);

		l = /* ntohs */(*((u_int16_t*)&response[offset])); offset += 2;
		lua_push_int32_table_entry(vm, "device_type", l);

		l = /* ntohs */(*((u_int16_t*)&response[offset])); offset += 2;
		lua_push_int32_table_entry(vm, "product_code", l);

		snprintf(str, sizeof(str), "%u.%02u", response[offset], response[offset+1]); offset += 2;
		lua_push_str_table_entry(vm, "revision", str);

		l = /* ntohs */(*((u_int16_t*)&response[offset])); offset += 2;
		lua_push_int32_table_entry(vm, "status", l);

		u32 = /* ntohl */(*((u_int32_t*)&response[offset])); offset += 4;
		lua_push_uint32_table_entry(vm, "serial_number", u32);

		l = response[offset];
		strncpy(str, (char*)&response[offset+1], ndpi_min(sizeof(str)-1, l)); str[l] = '\0';
		offset += l + 1;
		lua_push_str_table_entry(vm, "product_name", str);

		offset++; /* Skip state */
	      }
	    }

	    num_objects--;
	  } /* while */
	}
      } else
	rc = false;
    } else
      rc = false;
  }

  Utils::closeSocket(sockfd);

  return(rc);
}
