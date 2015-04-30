
#include "snmp.h"
#include "asn1.h"
#include "net.h"

#include "snmp.c"
#include "asn1.c"
#include "net.c"

#include <time.h>


/* ************************************************* */

unsigned long int next_request_id = 1;

unsigned int send_request(int socket, char *agent_host, int agent_port, char *oid, int verbose)
{
  SNMPMessage *message;
  int len;
  unsigned char *buf;
  unsigned long int request_id = next_request_id++;
  
  message = snmp_create_message();
  snmp_set_version(message, 0);
  snmp_set_community(message, "public");
  snmp_set_pdu_type(message, SNMP_GET_REQUEST_TYPE);
  snmp_set_request_id(message, request_id);
  snmp_set_error(message, 0);
  snmp_set_error_index(message, 0);
  snmp_add_varbind_null(message, oid);
    
  len = snmp_message_length(message);
  buf = malloc(len);
  snmp_render_message(message, buf);
    
  if (verbose)
    snmp_print_message(message, stderr);
    
  snmp_destroy_message(message);
    
  if (verbose)
    fprintf(stderr, "Sending datagram to %s:%d\n", agent_host, agent_port);

  send_udp_datagram(buf, len, socket, agent_host, agent_port);
    
  free(buf);
    
  return request_id;
}

/* ************************************************* */

void get_time_str(char *buf, int size)
{
  time_t time_buf;
  struct tm tm_buf;
    
  time(&time_buf);
  localtime_r(&time_buf, &tm_buf);
  strftime(buf, size, "%Y-%m-%d %H:%M:%S", &tm_buf);    
}

/* ************************************************* */

void log_message(SNMPMessage *message, char *sender_host)
{
  char *host_str = sender_host;
  char timestamp_str[20];
  char *oid_str;
  char *value_str;
  int i = 0;
    
  get_time_str(timestamp_str, sizeof(timestamp_str));
    
  while (snmp_get_varbind_as_string(message, i, &oid_str, NULL, &value_str))
    {
      printf("%s\t%s\t%s\t%s\n", host_str, timestamp_str, oid_str, value_str);
      i++;
    }
}

/* ************************************************* */

unsigned int get_response(int socket, u_int timeout, int verbose) {
  char buf[BUFLEN];
  SNMPMessage *message;
  char *sender_host;
  int sender_port;        
  int nr;

  nr = input_timeout(socket, timeout);
  if (nr == 0) return(0);
  
  nr = receive_udp_datagram(buf, BUFLEN, socket, &sender_host, &sender_port);
        
  if (nr == 0) return(0);
        
  if (verbose)
    fprintf(stderr, "Received packet from %s:%d\n", 
	    sender_host, sender_port);
        
  message = snmp_parse_message(buf, nr);
        
  if (verbose)
    snmp_print_message(message, stderr);
        
  if (snmp_get_pdu_type(message) == SNMP_GET_RESPONSE_TYPE)
    log_message(message, sender_host);
        
  snmp_destroy_message(message);
  return(1);
}

/* ************************************************* */

int main(int argc, char *argv[]) {
  int sock;

  // unsigned int send_request(int socket, char *agent_host, int agent_port, char *oid, int verbose)

  sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  send_request(sock, "192.168.1.252", 161, "1.3.6.1.2.1.1.5.0", 1 /* verbose */);
  get_response(sock, 5, 1);
  close(sock);
  return(0);
}


