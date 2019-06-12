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

#ifndef SOL_IP
#define SOL_IP          0
#endif

#define PACKETSIZE	64

struct ping_packet {
  struct ndpi_icmphdr hdr;
  char msg[PACKETSIZE-sizeof(struct ndpi_icmphdr)];
};

/* ****************************************** */

static void* resultPollerFctn(void* ptr) {
  Utils::setThreadName("PingLoop");

  ((Ping*)ptr)->pollResults();
  return(NULL);
}

/* ****************************************** */

void Ping::setOpts(int fd) {
  const int val = 255;

  setsockopt(fd, SOL_IP, IP_TTL, &val, sizeof(val));
  fcntl(fd, F_SETFL, O_NONBLOCK);
}

/* ****************************************** */

Ping::Ping() {
  pid = getpid(), cnt = 0;
  running = true;

#if defined(__APPLE__)
  sd  = socket(AF_INET,  SOCK_DGRAM, IPPROTO_ICMP);
  sd6 = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6);
#else
  sd  = socket(PF_INET, SOCK_RAW, IPPROTO_ICMP);
  sd6 = socket(PF_INET6, SOCK_RAW, IPPROTO_ICMPV6);
#endif

  if(sd == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ping IPv4 socket creation error: %s",
				 strerror(errno));
  else
    setOpts(sd);

  if(sd6 == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ping IPv6 socket creation error: %s",
				 strerror(errno));
  else
    setOpts(sd6);

  if((sd == -1) && (sd6 == -1))
    throw "Socket creation error";

  pthread_create(&resultPoller, NULL, resultPollerFctn, (void*)this);
}

/* ****************************************** */

Ping::~Ping() {
  running = false;
  pthread_join(resultPoller, NULL);
}

/* ****************************************** */

u_int16_t Ping::checksum(void *b, int len) {
  u_int16_t *buf = (u_int16_t*)b;
  u_int32_t sum=0;
  u_int16_t result;

  for(sum = 0; len > 1; len -= 2) sum += *buf++;
  if(len == 1) sum += *(unsigned char*)buf;
  sum = (sum >> 16) + (sum & 0xFFFF);
  sum += (sum >> 16);
  result = ~sum;

  return(result);
}

/* ****************************************** */

int Ping::ping(char *_addr, bool use_v6) {
  struct hostent *hname = gethostbyname2(_addr, use_v6 ? AF_INET6 : AF_INET);
  struct sockaddr_in addr;
  struct ping_packet pckt;
  u_int i;
  struct timeval *tv;

  if(hname == NULL)
    return(-1);

  bzero(&addr, sizeof(addr));
  addr.sin_family = hname->h_addrtype;
  addr.sin_port = 0;
  addr.sin_addr.s_addr = *(long*)hname->h_addr;

  bzero(&pckt, sizeof(pckt));
  pckt.hdr.type = ICMP_ECHO;
  pckt.hdr.un.echo.id = pid;
  for(i = 0; i < sizeof(pckt.msg)-1; i++) pckt.msg[i] = i+'0';
  pckt.msg[i] = 0;
  pckt.hdr.un.echo.sequence = cnt++;
  tv = (struct timeval*)pckt.msg;
  gettimeofday(tv, NULL);

  pckt.hdr.checksum = checksum(&pckt, sizeof(ping_packet));

  return(sendto(sd, &pckt, sizeof(pckt), 0,
		(struct sockaddr*)&addr,
		sizeof(struct sockaddr_in)));
}

/* ****************************************** */

void Ping::pollResults() {
  while(running) {
    struct sockaddr_in addr;
    int bytes, fd_max = max(sd, sd6);
    fd_set mask;
    struct timeval wait_time = { 1, 0 };

    FD_ZERO(&mask);
    if(sd != -1)  FD_SET(sd, &mask);
    if(sd6 != -1) FD_SET(sd6, &mask);

    if(select(fd_max+1, &mask, 0, 0, &wait_time) > 0) {
      socklen_t len = sizeof(addr);
      unsigned char buf[1024];

      if(FD_ISSET(sd, &mask)) {
	bytes = recvfrom(sd, buf, sizeof(buf), 0, (struct sockaddr*)&addr, &len);
	handleICMPResponse(buf, bytes, false);
      }

      if(FD_ISSET(sd6, &mask)) {
	bytes = recvfrom(sd6, buf, sizeof(buf), 0, (struct sockaddr*)&addr, &len);
	handleICMPResponse(buf, bytes, true);
      }
    }
  }
}

/* ****************************************************** */

void Ping::handleICMPResponse(unsigned char *buf, socklen_t buf_len, bool is_v6) {
  struct ndpi_iphdr *ip     = (struct ndpi_iphdr*)buf;
  struct ndpi_ipv6hdr *ip6  = (struct ndpi_ipv6hdr*)buf;
  u_int offset              = (!is_v6) ? (ip->ihl*4) : sizeof(const struct ndpi_ipv6hdr);
  struct ndpi_icmphdr *icmp;
  struct ping_packet *pckt;

  if(is_v6) {
    if((ip6->ip6_hdr.ip6_un1_nxt == 0x3C /* IPv6 destination option */) ||
       (ip6->ip6_hdr.ip6_un1_nxt == 0x0 /* Hop-by-hop option */)) {
      u_int8_t *options = (u_int8_t*)ip6 + offset;
      
      offset += 8 * (options[1] + 1);
    }
  }
  
  if(offset >= buf_len)
    return;

  icmp = (struct ndpi_icmphdr*)(buf+offset);
  pckt  = (struct ping_packet*)icmp;

  if(icmp->un.echo.id == pid) {
    float rtt;
    struct timeval end, *begin = (struct timeval*)pckt->msg;
    char *h, buf[64];
    
    gettimeofday(&end, NULL);

    rtt = ms_timeval_diff(begin, &end);

    m.lock(__FILE__, __LINE__);

    if(!is_v6)
      h = Utils::intoaV4(ntohl(ip->saddr), buf, sizeof(buf));
    else
      h = Utils::intoaV6(ip6->ip6_src, 128, buf, sizeof(buf));

    results[std::string(h)] = rtt;
    
    m.unlock(__FILE__, __LINE__);
  }
}

/* ****************************************************** */

void Ping::collectResponses(lua_State* vm) {
  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for(std::map<std::string,float>::iterator it=results.begin(); it!=results.end(); ++it)
    lua_push_float_table_entry(vm, it->first.c_str(), it->second);  

  results.clear();

  m.unlock(__FILE__, __LINE__);
}

/* ****************************************************** */

float Ping::ms_timeval_diff(struct timeval *begin, struct timeval *end) {
  if(end->tv_sec >= begin->tv_sec) {
    struct timeval result;

    result.tv_sec = end->tv_sec-begin->tv_sec;

    if((end->tv_usec - begin->tv_usec) < 0) {
      result.tv_usec = 1000000 + end->tv_usec - begin->tv_usec;
      if(result.tv_usec > 1000000) begin->tv_usec = 1000000;
      result.tv_sec--;
    } else
      result.tv_usec = end->tv_usec-begin->tv_usec;

    return((result.tv_sec*1000) + ((float)result.tv_usec/(float)1000));
  } else
    return(0);
}
