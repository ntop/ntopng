/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef WIN32

#include "ntop_includes.h"

#ifndef SOL_IP
#define SOL_IP 0
#endif

#define PACKETSIZE 64

// #define TRACE_PING 1

/* ****************************************** */

struct ping_packet {
  struct ndpi_icmphdr hdr;
  char msg[PACKETSIZE - sizeof(struct ndpi_icmphdr)];
};

/* ****************************************** */

static void *resultPollerFctn(void *ptr) {
  ((Ping *)ptr)->pollResults();
  return (NULL);
}

/* ****************************************** */

void Ping::setOpts(int fd) {
  const int val = 255;

  setsockopt(fd, SOL_IP, IP_TTL, &val, sizeof(val));
  fcntl(fd, F_SETFL, O_NONBLOCK);
}

/* ****************************************** */

Ping::Ping(char *_ifname) {
  ping_id = rand(), cnt = 0;
  running = false;

#ifndef __linux__
  _ifname = NULL; /* Too much of a hassle supporting it without capabilities */
#endif

  ifname = _ifname ? strdup(_ifname) : NULL;

#if 0 /* Not needed as privileges are not yet dropped */
#ifdef __linux__
  if(Utils::gainWriteCapabilities() == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities [%s]", strerror(errno));
#endif
#endif

  errno = 0;
#if defined(__APPLE__)
  sd = Utils::openSocket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP, "Ping");
#else
  sd = Utils::openSocket(PF_INET, SOCK_RAW, IPPROTO_ICMP, "Ping");
#endif

  if ((sd == -1) && (errno != 0)) {
    if (errno !=
        EPROTONOSUPPORT /* Avoid flooding logs when IPv4 is not supported */)
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Ping IPv4 socket creation error: %s", strerror(errno));
  } else {
    setOpts(sd);

    if (_ifname && (_ifname[0] != '\0')) {
      struct sockaddr_in sin;

      sin.sin_family = AF_INET;
      sin.sin_addr.s_addr = Utils::readIPv4(_ifname);

      if (sin.sin_addr.s_addr != 0) {
        if (::bind(sd, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) ==
            -1)
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "Unable to bind socket to IPv4 Address, error: %s",
              strerror(errno));
      }
    }
  }

  errno = 0;
#if defined(__APPLE__)
  sd6 = Utils::openSocket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6, "Ping6");
#else
  sd6 = Utils::openSocket(PF_INET6, SOCK_RAW, IPPROTO_ICMPV6, "Ping6");
#endif

#if 0 /* Not needed as privileges are not yet dropped */
#ifdef __linux
  Utils::dropWriteCapabilities();
#endif
#endif

  if ((sd6 < 0) && (errno != 0)) {
    if (errno != EPROTONOSUPPORT &&
        errno !=
            EAFNOSUPPORT) /* Avoid flooding logs when IPv6 is not supported */
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Ping IPv6 socket creation error: %s", strerror(errno));
  } else {
    setOpts(sd6);

    if (_ifname) {
      struct sockaddr_in6 sin;

      memset(&sin, 0, sizeof(sin));
      sin.sin6_family = AF_INET6;

      if (Utils::readIPv6(_ifname, &sin.sin6_addr)) {
        if (::bind(sd6, (struct sockaddr *)&sin, sizeof(struct sockaddr_in6)) ==
            -1)
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "Unable to bind socket to IPv6 Address, error %s",
              strerror(errno));
      }
    }
  }

  if ((sd < 0) && (sd6 < 0)) throw "Socket creation error";
}

/* ****************************************** */

Ping::~Ping() {
  if (running) {
    running = false;
    pthread_join(resultPoller, NULL);
  }

  Utils::closeSocket(sd);
  Utils::closeSocket(sd6);

  if (ifname) free(ifname);
}

/* ****************************************** */

void Ping::start() {
  if (!running) {
    pthread_create(&resultPoller, NULL, resultPollerFctn, (void *)this);
    running = true;
  }
}

/* ****************************************** */

u_int16_t Ping::checksum(void *b, int len) {
  u_int16_t *buf = (u_int16_t *)b;
  u_int32_t sum = 0;
  u_int16_t result;

  for (sum = 0; len > 1; len -= 2) sum += *buf++;
  if (len == 1) sum += *(unsigned char *)buf;
  sum = (sum >> 16) + (sum & 0xFFFF);
  sum += (sum >> 16);
  result = ~sum;

  return (result);
}

/* ****************************************** */

int Ping::ping(char *_addr, bool use_v6) {
  struct hostent *hname = gethostbyname2(_addr, use_v6 ? AF_INET6 : AF_INET);
  struct sockaddr_in addr;
  struct sockaddr_in6 addr6;
  struct ping_packet pckt;
  u_int i;
  struct timeval *tv;
  ssize_t res;

  if (hname == NULL) return (-1);

  start(); /* In case thread is not started yet */

  if (use_v6) {
    bzero(&addr6, sizeof(addr6));

    addr6.sin6_family = hname->h_addrtype;
    addr6.sin6_port = 0;
    memcpy(&addr6.sin6_addr, hname->h_addr, sizeof(addr6.sin6_addr));
  } else {
    bzero(&addr, sizeof(addr));

    addr.sin_family = hname->h_addrtype;
    addr.sin_port = 0;
    memcpy(&addr.sin_addr.s_addr, hname->h_addr_list[0],
           sizeof(addr.sin_addr.s_addr));
    ;
  }

  bzero(&pckt, sizeof(pckt));
  pckt.hdr.type = use_v6 ? ICMP6_ECHO_REQUEST : ICMP_ECHO;

  /*
    NOTE:
    each connection must have a unique ID, otherwise some replies
    will not arrive.
  */
  pckt.hdr.un.echo.id = htons(ping_id);

  for (i = 0; i < sizeof(pckt.msg) - 1; i++) pckt.msg[i] = i + '0';

  pckt.msg[i] = 0;
  pckt.hdr.un.echo.sequence = htons(cnt++);
  tv = (struct timeval *)pckt.msg;
  gettimeofday(tv, NULL);

  pckt.hdr.checksum = checksum(&pckt, sizeof(ping_packet));

  if (use_v6)
    res = sendto(sd6, &pckt, sizeof(pckt), 0, (struct sockaddr *)&addr6,
                 sizeof(addr6));
  else
    res = sendto(sd, &pckt, sizeof(pckt), 0, (struct sockaddr *)&addr,
                 sizeof(addr));

  if (res == -1) {
    /* NOTE: This also happens when network is unreachable */
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(
        TRACE_WARNING,
        "Unable to send ping [pinger: %p][address: %s][v6: %u][reason: %s]",
        this, _addr, use_v6 ? 1 : 0, strerror(errno));
#endif
  } else {
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Pinging [pinger: %p][address: %s][echo id: "
                                 "%u][sequence: %u][cnt: %u][v6: %u]",
                                 this, _addr, ntohs(pckt.hdr.un.echo.id),
                                 ntohs(pckt.hdr.un.echo.sequence), cnt,
                                 use_v6 ? 1 : 0);
#endif

    m.lock(__FILE__, __LINE__);

    if (use_v6)
      pinged_v6[std::string(_addr)] = true;
    else
      pinged_v4[std::string(_addr)] = true;

    m.unlock(__FILE__, __LINE__);
  }

  return res;
}

/* ****************************************** */

void Ping::pollResults() {
  int bytes, fd_max = max(sd, sd6);
  fd_set mask;
  struct timeval wait_time;
  char thread_name[64];

  if (ifname)
    snprintf(thread_name, sizeof(thread_name), "ntopng-ping-%s", ifname);
  else
    snprintf(thread_name, sizeof(thread_name), "ntopng-ping");

  Utils::setThreadName(thread_name);

#ifdef TRACE_PING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Started polling...");
#endif

  while (running && (!ntop->getGlobals()->isShutdown())) {
    FD_ZERO(&mask);
    if (sd >= 0) FD_SET(sd, &mask);
    if (sd6 >= 0) FD_SET(sd6, &mask);

    wait_time.tv_sec = 1, wait_time.tv_usec = 0;

    if (select(fd_max + 1, &mask, 0, 0, &wait_time) > 0) {
      unsigned char buf[1024];

      if ((sd >= 0) && FD_ISSET(sd, &mask)) {
        struct sockaddr_in addr;
        socklen_t len = sizeof(addr);

        bytes =
            recvfrom(sd, buf, sizeof(buf), 0, (struct sockaddr *)&addr, &len);
        handleICMPResponse(buf, bytes, &addr.sin_addr, NULL);
      }

      if ((sd6 >= 0) && FD_ISSET(sd6, &mask)) {
        struct sockaddr_in6 addr;
        socklen_t len = sizeof(addr);

        bytes =
            recvfrom(sd6, buf, sizeof(buf), 0, (struct sockaddr *)&addr, &len);
        handleICMPResponse(buf, bytes, NULL, &addr.sin6_addr);
      }
    }
  }

#ifdef TRACE_PING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "... polling done");
#endif
}

/* ****************************************************** */

void Ping::handleICMPResponse(unsigned char *buf, u_int buf_len,
                              struct in_addr *ip, struct in6_addr *ip6) {
  struct ndpi_icmphdr *icmp = NULL;
  struct ping_packet *pckt = NULL;
  u_int16_t echo_id;

  if (ip) {
    if (buf_len != sizeof(ndpi_iphdr) + sizeof(ping_packet)) {
      return; /* Response doesn't match the expected response size */
    }

    struct ndpi_iphdr *ip4 = (struct ndpi_iphdr *)buf;
    icmp = (struct ndpi_icmphdr *)(buf + ip4->ihl * 4);
    pckt = (struct ping_packet *)icmp;
  } else {
    icmp = (struct ndpi_icmphdr *)buf;
    pckt = (struct ping_packet *)icmp;
  }

  echo_id = ntohs(icmp->un.echo.id);

#ifdef TRACE_PING
  u_int16_t echo_seq = ntohs(icmp->un.echo.sequence);
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "Handling response [pinger: %p][%s][overflow: "
                               "%u][echo id: %u][sequence: %u][ping_id: %u]",
                               this, ip ? "ipv4" : "ipv6", overflow ? 1 : 0,
                               echo_id, echo_seq, ping_id);
#endif

  if ((ip && (icmp->type != ICMP_ECHOREPLY)) ||
      (ip6 && (icmp->type != ICMP6_ECHO_REPLY)))
    return;

  /* The PING ID must have ping_id */
  if (echo_id == ping_id) {
    float rtt;
    struct timeval end, *begin = (struct timeval *)pckt->msg;
    char *h, buf[64];

    gettimeofday(&end, NULL);
    rtt = ((float)Utils::usecTimevalDiff(&end, begin)) / 1000.0;

    m.lock(__FILE__, __LINE__);

    if (ip) {
      h = Utils::intoaV4(ntohl(ip->s_addr), buf, sizeof(buf));
      results_v4[std::string(h)] = rtt;
    } else {
      h = Utils::intoaV6(*((struct ndpi_in6_addr *)ip6), 128, buf, sizeof(buf));
      results_v6[std::string(h)] = rtt;
    }

#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Response received [pinger: %p][%s]", this, h);
#endif

    m.unlock(__FILE__, __LINE__);
  } else {
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "[pinger: %p] Received unexpected ICMP [echo_id: %u]",
        this, echo_id);
#endif
  }
}

/* ****************************************************** */

void Ping::collectResponses(lua_State *vm, bool v6) {
  std::map<std::string /* IP */, float /* RTT */> *results =
      v6 ? &results_v6 : &results_v4;
  std::map<std::string /* IP */, bool> *pinged = v6 ? &pinged_v6 : &pinged_v4;

  /* The lua_newtable() below is added by  Ntop::collectResponses() */
  /* lua_newtable(vm); */

  m.lock(__FILE__, __LINE__);

  for (std::map<std::string, float>::const_iterator it = results->begin();
       it != results->end(); ++it) {
    if (it->first.c_str()[0])
      lua_push_float_table_entry(vm, it->first.c_str(), it->second);

    pinged->erase(it->first);
  }

#ifdef TRACE_PING
  for (std::map<std::string, bool>::const_iterator it = pinged->begin();
       it != pinged->end(); ++it)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "No response received from %s",
                                 it->first.c_str());
#endif

  pinged->clear();
  results->clear();
  cnt = 0; /* Reset counter */

  m.unlock(__FILE__, __LINE__);
}

/* ****************************************************** */

float Ping::getRTT(std::string who, bool v6) {
  std::map<std::string /* IP */, float /* RTT */>::const_iterator it;
  std::map<std::string /* IP */, float /* RTT */> *results =
      v6 ? &results_v6 : &results_v4;
  float f;

  m.lock(__FILE__, __LINE__);

  it = results->find(who);

  if (it != results->end())
    f = it->second;
  else
    f = -1;

  m.unlock(__FILE__, __LINE__);

  return (f);
}

/* ****************************************************** */

void Ping::cleanup() {
  m.lock(__FILE__, __LINE__);

  /* Clear any received result so far */
  results_v4.clear(), results_v6.clear();

  /* Clear also any outstanding request without response */
  pinged_v4.clear(), pinged_v6.clear();

  /* Start over with a new ping id */
  ping_id = rand(), cnt = 0;

  m.unlock(__FILE__, __LINE__);
}

/* ****************************************************** */

#endif /* WIN32 */
