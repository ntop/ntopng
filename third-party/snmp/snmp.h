#ifndef SNMP_H
#define SNMP_H

#include <stdio.h>

enum {
  SNMP_COUNTER_TYPE = 0x41,
  SNMP_GAUGE_TYPE = 0x42,
  SNMP_TIMETICKS_TYPE = 0x43,
  SNMP_GET_REQUEST_TYPE = 0xA0,
  SNMP_GETNEXT_REQUEST_TYPE = 0xA1,
  SNMP_GET_RESPONSE_TYPE = 0xA2,
  SNMP_SET_REQUEST_TYPE = 0xA3
};

typedef struct SNMPMessage SNMPMessage;

SNMPMessage *snmp_create_message();
void snmp_destroy_message(SNMPMessage *message);
void snmp_set_version(SNMPMessage *message, int version);
void snmp_set_community(SNMPMessage *message, char *community);
void snmp_set_pdu_type(SNMPMessage *message, int type);
void snmp_set_request_id(SNMPMessage *message, int request_id);
void snmp_set_error(SNMPMessage *message, int error);
void snmp_set_error_index(SNMPMessage *message, int error_index);
void snmp_add_varbind_null(SNMPMessage *message, char *oid);
void snmp_add_varbind_integer_type(SNMPMessage *message, char *oid, int type, int value);
void snmp_add_varbind_integer(SNMPMessage *message, char *oid, int value);
void snmp_add_varbind_string(SNMPMessage *message, char *oid, char *value);
int snmp_message_length(SNMPMessage *message);
void snmp_render_message(SNMPMessage *message, void *buffer);
SNMPMessage *snmp_parse_message(void *buffer, int len);
void snmp_print_message(SNMPMessage *message, FILE *stream);

int snmp_get_pdu_type(SNMPMessage *message);

int snmp_get_varbind_integer(SNMPMessage *message, int num, char **oid, int *type, int *int_value);
int snmp_get_varbind_string(SNMPMessage *message, int num, char **oid, int *type, char **str_value);
int snmp_get_varbind_as_string(SNMPMessage *message, int num, char **oid, int *type, char **value_str);

#endif
