
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#ifndef WIN32
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <errno.h>
#endif

#ifndef __USE_GNU
#define __USE_GNU
#endif

#ifdef WIN32
#define gethostbyname2(a, b) gethostbyname(a)
#else
#include <unistd.h>
#endif

#define BUFLEN 65535

void diep(char *s)
{
  perror(s);
  exit(1);
}

int split_host_port(char *input, int default_port, char **host, int *port)
{
  char *p;
    
  *host = strdup(input);
    
  if ((p = strchr(*host, ':')))
    {
      *port = strtol(p+1, NULL, 0);
      *p = 0;
    }
  else
    {
      *port = default_port;
    }
    
  return 1;
}

int open_udp_socket(int port)
{
  struct sockaddr_in si_me;
  int s;
  int reuse = 1;
    
  if ((s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1)
    return(-1); // diep("socket");

  if (setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (const char*)&reuse, sizeof(reuse)) != 0)
    return(-1); //diep("setsockaopt");

  memset((char *) &si_me, 0, sizeof(si_me));
  si_me.sin_family = AF_INET;
  si_me.sin_port = htons(port);
  si_me.sin_addr.s_addr = htonl(INADDR_ANY);
  if (bind(s, (struct sockaddr *) &si_me, sizeof(si_me)) != 0)
    return(-1); //diep("bind");
    
  return s;
}

void send_udp_datagram(void *buf, int len, int socket, char *target_host, int target_port)
{
  struct sockaddr_in target_si;
  struct hostent *he;
    
  memset((char *) &target_si, 0, sizeof(target_si));
  target_si.sin_family = AF_INET;
  target_si.sin_port = htons(target_port);
    
  if (!(he = gethostbyname2(target_host, AF_INET)))
    return; //diep("gethostbyname2");
    
  memmove(&target_si.sin_addr.s_addr, he->h_addr, he->h_length);
    
  if (sendto(socket, (const char*)buf, len, 0, (struct sockaddr *) &target_si, sizeof(target_si)) == -1)
    return; //diep("sendto");
}    

int receive_udp_datagram(void *buf, int max, int socket, char **sender_host, int *sender_port)
{
  struct sockaddr_in sender_si;
  int slen = sizeof(sender_si);
  int nr;
    
  nr = recvfrom(socket, (char*)buf, BUFLEN, 
#ifdef WIN32
	  0,
#else
	  MSG_DONTWAIT, // TODO: add select() to avoid waiting forever
#endif
	  (struct sockaddr *) &sender_si, (socklen_t*)&slen);
  if (nr == -1)
    {
      if (errno == EAGAIN || errno == EWOULDBLOCK)
	return 0;
        
      return(-1); //diep("recvfrom");
    }
    
  if (sender_host)
    *sender_host = inet_ntoa(sender_si.sin_addr);
    
  if (sender_port)
    *sender_port = ntohs(sender_si.sin_port);
    
  return nr;
}

/* Borrowed from the GNU libc manual. */
int input_timeout(int filedes, unsigned int seconds)
{
  fd_set set;
  struct timeval timeout;

  /* Initialize the file descriptor set. */
  FD_ZERO(&set);
  FD_SET(filedes, &set);

  /* Initialize the timeout data structure. */
  timeout.tv_sec = seconds;
  timeout.tv_usec = 0;

  /* `select' returns 0 if timeout, 1 if input available, -1 if error. */
  return /* TEMP_FAILURE_RETRY*/(select(FD_SETSIZE,
					&set, NULL, NULL,
					&timeout));
}
