/*
 *
 * (C) 2013-20 - ntop.org
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
#define SOL_IP          0
#endif

#define PACKETSIZE	64

struct ping_packet {
  struct ndpi_icmphdr hdr;
  char msg[PACKETSIZE-sizeof(struct ndpi_icmphdr)];
};

// #define TRACE_PING 1

/* ****************************************** */

static void* resultPollerFctn(void* ptr) {
  Utils::setThreadName("PingLoop");

  ((Ping*)ptr)->pollResults(false);
  return(NULL);
}

/* ****************************************** */

void Ping::setOpts(int fd) {
  const int val = 255;

  setsockopt(fd, SOL_IP, IP_TTL, &val, sizeof(val));
  fcntl(fd, F_SETFL, O_NONBLOCK);
}

/* ****************************************** */

bool Ping::isSupported() {
  int sd;

#if defined(__APPLE__)
  sd  = socket(AF_INET,  SOCK_DGRAM, IPPROTO_ICMP);
#else
  sd  = socket(PF_INET, SOCK_RAW, IPPROTO_ICMP);
#endif

  if(sd != -1) {
    close(sd);

    return(true);
  }

  return(false);
}

/* ****************************************** */

Ping::Ping() {
  ping_id = rand(), cnt = 0;
  running = true;

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
  if(Utils::gainWriteCapabilities() == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

#if defined(__APPLE__)
  sd  = socket(AF_INET,  SOCK_DGRAM, IPPROTO_ICMP);
  sd6 = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6);
#else
  sd  = socket(PF_INET, SOCK_RAW, IPPROTO_ICMP);
  sd6 = socket(PF_INET6, SOCK_RAW, IPPROTO_ICMPV6);
#endif
  
#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
  Utils::dropWriteCapabilities();
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
  if(sd != -1)  close(sd);
  if(sd6 != -1) close(sd6);
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
  struct sockaddr_in6 addr6;
  struct ping_packet pckt;
  u_int i;
  struct timeval *tv;
  ssize_t res;

#ifdef TRACE_PING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%s, v6: %u)", __FUNCTION__, _addr, use_v6 ? 1 : 0);
#endif
  
  if(hname == NULL)
    return(-1);

  if(use_v6) {
    bzero(&addr6, sizeof(addr6));
    
    addr6.sin6_family = hname->h_addrtype;
    addr6.sin6_port = 0;
    memcpy(&addr6.sin6_addr, hname->h_addr, sizeof(addr6.sin6_addr));
  } else {
    bzero(&addr, sizeof(addr));
    
    addr.sin_family = hname->h_addrtype;
    addr.sin_port = 0;
    addr.sin_addr.s_addr = *(long*)hname->h_addr;
  }

  bzero(&pckt, sizeof(pckt));
  pckt.hdr.type = use_v6 ? ICMP6_ECHO_REQUEST : ICMP_ECHO;
  
  /*
    NOTE:
    each connection must have a unique ID, otherwise some replies
    will not arrive.
  */
  pckt.hdr.un.echo.id = ping_id + cnt;

  for(i = 0; i < sizeof(pckt.msg)-1; i++) pckt.msg[i] = i+'0';
  
  pckt.msg[i] = 0;
  pckt.hdr.un.echo.sequence = cnt++;
  tv = (struct timeval*)pckt.msg;
  gettimeofday(tv, NULL);

  pckt.hdr.checksum = checksum(&pckt, sizeof(ping_packet));

  if(use_v6)
    res = sendto(sd6, &pckt, sizeof(pckt), 0,
		 (struct sockaddr*)&addr6,
		 sizeof(addr6));
  else
    res = sendto(sd, &pckt, sizeof(pckt), 0,
		 (struct sockaddr*)&addr,
		 sizeof(addr));

#ifdef TRACE_PING
  if(res == -1)
    /* NOTE: This also happens when network is unreachable */
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to send ping [address: %s][v6: %u][reason: %s]",
				 _addr, use_v6 ? 1 : 0, strerror(errno));
  else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Pinging [address: %s][v6: %u]", _addr, use_v6 ? 1 : 0);
#endif
  
  return res;
}

/* ****************************************** */

void Ping::pollResults(bool wait_forever) {
  while(running) {
    int bytes, fd_max = max(sd, sd6);
    fd_set mask;
    struct timeval wait_time = { 1, 0 };

    FD_ZERO(&mask);
    if(sd != -1)  FD_SET(sd, &mask);
    if(sd6 != -1) FD_SET(sd6, &mask);

    if(select(fd_max+1, &mask, 0, 0, &wait_time) > 0) {
      unsigned char buf[1024];

      if(FD_ISSET(sd, &mask)) {
	struct sockaddr_in addr;
	socklen_t len = sizeof(addr);
	
	bytes = recvfrom(sd, buf, sizeof(buf), 0, (struct sockaddr*)&addr, &len);
	handleICMPResponse(buf, bytes, &addr.sin_addr, NULL);
      }

      if(FD_ISSET(sd6, &mask)) {
	struct sockaddr_in6 addr;
	socklen_t len = sizeof(addr);
	
	bytes = recvfrom(sd6, buf, sizeof(buf), 0, (struct sockaddr*)&addr, &len);
	handleICMPResponse(buf, bytes, NULL, &addr.sin6_addr);
      }
    } else {
      if(!wait_forever)
	break;
    }
  }
}

/* ****************************************************** */

void Ping::handleICMPResponse(unsigned char *buf, u_int buf_len,
			      struct in_addr *ip, struct in6_addr *ip6) {
  struct ndpi_icmphdr *icmp;
  struct ping_packet *pckt;
  bool overflow = ((u_int16_t)(ping_id + cnt) < ping_id);

 if(ip) {
   struct ndpi_iphdr *ip4 = (struct ndpi_iphdr*)buf;

   icmp = (struct ndpi_icmphdr*)(buf+ip4->ihl*4);
   pckt  = (struct ping_packet*)icmp;   
 } else {
   icmp = (struct ndpi_icmphdr*)buf;
   pckt  = (struct ping_packet*)icmp;
 }

#ifdef TRACE_PING
 ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s()", __FUNCTION__);
#endif
 
 if((ip && (icmp->type != ICMP_ECHOREPLY))
    || (ip6 && (icmp->type != ICMP6_ECHO_REPLY)))
   return;

  /* The PING ID must be between ping_id (inclusive) and ping_id + cnt (exclusive) */
  if((!overflow && ((icmp->un.echo.id >= ping_id) && (icmp->un.echo.id < (ping_id + cnt)))) ||
     (overflow && ((icmp->un.echo.id >= ping_id) || (icmp->un.echo.id <= ((u_int16_t)ping_id + cnt))))) {
    float rtt;
    struct timeval end, *begin = (struct timeval*)pckt->msg;
    char *h, buf[64];
    
    gettimeofday(&end, NULL);

    rtt = ms_timeval_diff(begin, &end);

    m.lock(__FILE__, __LINE__);

    if(ip)
      h = Utils::intoaV4(ntohl(ip->s_addr), buf, sizeof(buf));
    else
      h = Utils::intoaV6(*((struct ndpi_in6_addr*)ip6), 128, buf, sizeof(buf));

    results[std::string(h)] = rtt;
    
    m.unlock(__FILE__, __LINE__);
  }
}

/* ****************************************************** */

void Ping::collectResponses(lua_State* vm) {
  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for(std::map<std::string,float>::iterator it=results.begin(); it!=results.end(); ++it) {
    if(it->first.c_str()[0])
      lua_push_float_table_entry(vm, it->first.c_str(), it->second);
  }

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

/* ****************************************************** */

float Ping::getRTT(std::string who) {  
  std::map<std::string /* IP */, float /* RTT */>::iterator it;
  float f;
  
  m.lock(__FILE__, __LINE__);
  
  it = results.find(who);

  if(it != results.end())
    f = it->second;
  else
    f = -1;

  m.unlock(__FILE__, __LINE__);

  return(f);
}

/* ****************************************************** */

void Ping::cleanup() {
  m.lock(__FILE__, __LINE__);
  results.clear();
  m.unlock(__FILE__, __LINE__);
}

/* ****************************************************** */

#endif /* WIN32 */
