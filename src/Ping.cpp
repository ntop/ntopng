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

Ping::Ping() {
  const int val = 255;

  pid = getpid(), cnt = 0;
  running = true;

#if defined(__APPLE__)
  sd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
#else
  sd = socket(PF_INET, SOCK_RAW, IPPROTO_ICMP);
#endif

  if(sd == -1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ping socket creation error: %s", strerror(errno));
    throw("Unable to create socket");
  }

  setsockopt(sd, SOL_IP, IP_TTL, &val, sizeof(val));
  fcntl(sd, F_SETFL, O_NONBLOCK);

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

int Ping::ping(char *_addr) {
  struct hostent *hname = gethostbyname(_addr);
  struct sockaddr_in addr;
  struct ping_packet pckt;
  u_int i;
  struct timeval *tv;

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
    int bytes;
    fd_set mask;
    struct timeval wait_time = { 1, 0 };

    FD_ZERO(&mask);
    FD_SET(sd, &mask);

    if(select(sd+1, &mask, 0, 0, &wait_time) > 0) {
      socklen_t len = sizeof(addr);
      unsigned char buf[1024];

      // bzero(buf, sizeof(buf));
      bytes = recvfrom(sd, buf, sizeof(buf), 0, (struct sockaddr*)&addr, &len);

      if(bytes > 0) {
	struct ndpi_iphdr *ip = (struct ndpi_iphdr*)buf;
	struct ndpi_icmphdr *icmp = (struct ndpi_icmphdr*)(buf+ip->ihl*4);
	struct ping_packet *pckt = (struct ping_packet*)icmp;
	struct in_addr s;

	s.s_addr = ip->saddr;
	
	if(icmp->un.echo.id == pid) {
	  float rtt;
	  struct timeval end, *begin = (struct timeval*)pckt->msg;

	  gettimeofday(&end, NULL);

	  rtt = ms_timeval_diff(begin, &end);

	  ntop->getTrace()->traceEvent(TRACE_INFO,
				       "ICMP response from %s [%.2f ms]",
				       inet_ntoa(s), rtt);
	  m.lock(__FILE__, __LINE__);
	  results[ip->saddr] = rtt;
	  m.unlock(__FILE__, __LINE__);
	} else {
	  ntop->getTrace()->traceEvent(TRACE_INFO,
				       "Discarding ICMP response from %s",
				       inet_ntoa(s));
	}
      } else
	break;
    }
  }
}

/* ****************************************************** */

void Ping::collectResponses(lua_State* vm) {
  lua_newtable(vm);
  
  m.lock(__FILE__, __LINE__);

  for(std::map<u_int32_t,float>::iterator it=results.begin(); it!=results.end(); ++it) {
    struct in_addr s;

    s.s_addr = it->first;    
    lua_push_float_table_entry(vm, inet_ntoa(s), it->second);  
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
