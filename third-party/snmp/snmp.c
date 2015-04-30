#include "snmp.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>

#include "asn1.h"


typedef struct VarbindList
{
  char *oid;
  int value_type;
    
  /** Will be a primtive ASN.1 type; effects how value will be interpreted. */
  int render_as_type;
    
  Value value;
    
  struct VarbindList *next;
} VarbindList;

struct SNMPMessage
{
  int version;
  char *community;
  int pdu_type;
  int request_id;
  int error;
  int error_index;
  VarbindList *varbind_list;
};

SNMPMessage *snmp_create_message()
{
  SNMPMessage *message = (SNMPMessage*)malloc(sizeof(SNMPMessage));
  message->version = 0;
  message->community = NULL;
  message->pdu_type = 0;
  message->request_id = 0;
  message->error = 0;
  message->error_index = 0;
  message->varbind_list = NULL;
  return message;
}

static void destroy_varbind_list(VarbindList *list)
{
  if (list == NULL)
    return;
    
  free(list->oid);
  if (list->render_as_type == ASN1_STRING_TYPE)
    free(list->value.str_value);
  destroy_varbind_list(list->next);
  free(list);
}

void snmp_destroy_message(SNMPMessage *message)
{
  free(message->community);
  destroy_varbind_list(message->varbind_list);
}

void snmp_set_version(SNMPMessage *message, int version)
{
  message->version = version;
}

void snmp_set_community(SNMPMessage *message, char *community)
{
  free(message->community);
  message->community = strdup(community);
}

void snmp_set_pdu_type(SNMPMessage *message, int type)
{
  message->pdu_type = type;
}

void snmp_set_request_id(SNMPMessage *message, int request_id)
{
  message->request_id = request_id;
}

void snmp_set_error(SNMPMessage *message, int error)
{
  message->error = error;
}

void snmp_set_error_index(SNMPMessage *message, int error_index)
{
  message->error_index = error_index;
}

void snmp_add_varbind(SNMPMessage *message, VarbindList *vb)
{
  if (message->varbind_list == NULL)
    message->varbind_list = vb;
  else
    {
      VarbindList *parent = message->varbind_list;
        
      while (parent->next != NULL)
	parent = parent->next;
        
      parent->next = vb;
    }
}

void snmp_add_varbind_null(SNMPMessage *message, char *oid)
{
  VarbindList *vb = (VarbindList*)malloc(sizeof (VarbindList));
  vb->oid = strdup(oid);
  vb->value_type = ASN1_NULL_TYPE;
  vb->render_as_type = ASN1_NULL_TYPE;
  vb->next = NULL;
    
  snmp_add_varbind(message, vb);
}

void snmp_add_varbind_integer_type(SNMPMessage *message, char *oid, int type, int value)
{
  VarbindList *vb = (VarbindList*)malloc(sizeof (VarbindList));
  vb->oid = strdup(oid);
  vb->value_type = type;
  vb->render_as_type = ASN1_INTEGER_TYPE;
  vb->value.int_value = value;
  vb->next = NULL;
    
  snmp_add_varbind(message, vb);
}

void snmp_add_varbind_integer(SNMPMessage *message, char *oid, int value)
{
  snmp_add_varbind_integer_type(message, oid, ASN1_INTEGER_TYPE, value);
}

void snmp_add_varbind_string(SNMPMessage *message, char *oid, char *value)
{
  VarbindList *vb = (VarbindList*)malloc(sizeof (VarbindList));
  vb->oid = strdup(oid);
  vb->value_type = ASN1_STRING_TYPE;
  vb->render_as_type = ASN1_STRING_TYPE;
  vb->value.str_value = strdup(value);
  vb->next = NULL;
    
  snmp_add_varbind(message, vb);
}

static void get_msg_lens(SNMPMessage *message, int *msg_len, int *pdu_len, int *vbl_len)
{
  *vbl_len = 0;
  VarbindList *vb = message->varbind_list;
  while (vb != NULL)
    {
      int oid_obj_len = object_length(oid_length(vb->oid));
      int value_obj_len = object_length(value_length(vb->render_as_type, vb->value));
      *vbl_len += object_length(oid_obj_len + value_obj_len);
        
      vb = vb->next;
    }
    
  *pdu_len = object_length(integer_length(message->request_id));
  *pdu_len += object_length(integer_length(message->error));
  *pdu_len += object_length(integer_length(message->error_index));
  *pdu_len += sequence_header_length(*vbl_len) + *vbl_len;
    
  *msg_len = object_length(integer_length(message->version));
  *msg_len += object_length(string_length(message->community));
    
  *msg_len += header_length(message->pdu_type, *pdu_len) + *pdu_len;
}

int snmp_message_length(SNMPMessage *message)
{
  int msg_len, pdu_len, vbl_len;
    
  get_msg_lens(message, &msg_len, &pdu_len, &vbl_len);
    
  return sequence_header_length(msg_len) + msg_len;
}

void snmp_render_message(SNMPMessage *message, void *buffer)
{
  int msg_len, pdu_len, vbl_len;
  VarbindList *vb;
  void *p = buffer;
    
  get_msg_lens(message, &msg_len, &pdu_len, &vbl_len);
    
  p = render_sequence_header(msg_len, p);
  p = render_integer_object(message->version, p);
  p = render_string_object(message->community, p);
    
  p = render_header(message->pdu_type, pdu_len, p);
  p = render_integer_object(message->request_id, p);
  p = render_integer_object(message->error, p);
  p = render_integer_object(message->error_index, p);
    
  p = render_sequence_header(vbl_len, p);
  vb = message->varbind_list;
  while (vb != NULL)
    {
      int oid_obj_len = object_length(oid_length(vb->oid));
      int value_obj_len = object_length(value_length(vb->render_as_type, vb->value));
      p = render_sequence_header(oid_obj_len + value_obj_len, p);
      p = render_oid_object(vb->oid, p);
      p = render_value_object(vb->value_type, vb->render_as_type, vb->value, (char*)p);
        
      vb = vb->next;
    }
}

SNMPMessage *snmp_parse_message(void *buffer, int len)
{
  SNMPMessage *message = snmp_create_message();
  ASN1Parser *parser = asn1_create_parser(buffer, len);
    
  asn1_parse_sequence(parser);
  asn1_parse_integer(parser, &message->version);
  asn1_parse_string(parser, &message->community);
  asn1_parse_structure(parser, &message->pdu_type);
  asn1_parse_integer(parser, &message->request_id);
  asn1_parse_integer(parser, &message->error);
  asn1_parse_integer(parser, &message->error_index);
  asn1_parse_sequence(parser);
  while (asn1_parse_sequence(parser))
    {
      char *oid;
      int type;
      Value value;
      asn1_parse_oid(parser, &oid);
      asn1_parse_peek(parser, &type, NULL);
        
      switch (type)
        {
	case ASN1_NULL_TYPE:
	case ASN1_OID_TYPE: // <--- FIX
	  asn1_parse_primitive_value(parser, NULL, &value);
	  snmp_add_varbind_null(message, oid);
	  break;

	case SNMP_GAUGE_TYPE:
	case SNMP_COUNTER_TYPE:
	case SNMP_TIMETICKS_TYPE:
	case ASN1_INTEGER_TYPE:
	  asn1_parse_integer_type(parser, NULL, &value.int_value);
	  snmp_add_varbind_integer_type(message, oid, type, value.int_value);
	  break;
            
	case ASN1_STRING_TYPE:
	  asn1_parse_string_type(parser, NULL, &value.str_value);
	  snmp_add_varbind_string(message, oid, value.str_value);
	  free(value.str_value);
	  break;
        }
        
      asn1_parse_pop(parser);
    }
  asn1_parse_pop(parser);
  asn1_parse_pop(parser);
  asn1_parse_pop(parser);
  asn1_destroy_parser(parser);
    
  return message;
}

void snmp_print_message(SNMPMessage *message, FILE *stream)
{
  VarbindList *vb;
    
  fprintf(stream, "SNMP Message:\n");
  fprintf(stream, "    Version: %d\n", message->version);
  fprintf(stream, "    Community: %s\n", message->community);
  fprintf(stream, "    PDU Type: %d\n", message->pdu_type);
  fprintf(stream, "    Request ID: %d\n", message->request_id);
  fprintf(stream, "    Error: %d\n", message->error);
  fprintf(stream, "    Error Index: %d\n", message->error_index);
    
  vb = message->varbind_list;
  while (vb)
    {
      char type_str[20] = "";
      if (vb->value_type != vb->render_as_type)
	snprintf(type_str, sizeof(type_str), " (type 0x%02x)", vb->value_type);
        
      fprintf(stream, "        OID: %s\n", vb->oid);
      switch (vb->render_as_type)
        {
	case ASN1_NULL_TYPE:
	  fprintf(stream, "            Null%s\n", type_str);
	  break;
	case ASN1_INTEGER_TYPE:
	  fprintf(stream, "            Integer%s: %d\n", type_str, vb->value.int_value);
	  break;
	case ASN1_STRING_TYPE:
	  fprintf(stream, "            String%s: %s\n", type_str, vb->value.str_value);
	  break;
	default:
	  abort();
        }
      vb = vb->next;
    }
}

int snmp_get_pdu_type(SNMPMessage *message)
{
  return message->pdu_type;
}

static VarbindList *get_varbind(SNMPMessage *message, int num)
{
  int i = 0;
  VarbindList *vb = message->varbind_list;
    
  while (vb)
    {
      if (i == num)
	return vb;
        
      vb = vb->next;
      i++;
    }
    
  return NULL;
}

static int get_varbind_value(SNMPMessage *message, int num, char **oid, int *type, int *render_as_type, Value *value)
{
  VarbindList *vb = get_varbind(message, num);
  if (!vb)
    return 0;
    
  if (oid)
    *oid = vb->oid;
    
  if (type)
    *type = vb->value_type;
    
  if (render_as_type)
    *render_as_type = vb->render_as_type;
    
  if (value)
    *value = vb->value;
    
  return 1;
}

int snmp_get_varbind_integer(SNMPMessage *message, int num, char **oid, int *type, int *int_value)
{
  int render_as_type;
  Value value;
    
  if (!get_varbind_value(message, num, oid, type, &render_as_type, &value))
    return 0;
    
  //TODO return value of 0 also indicates end of list
  //handle non-integer data differently?
  if (render_as_type != ASN1_INTEGER_TYPE)
    return 0;

  if (int_value)
    *int_value = value.int_value;
    
  return 1;
}

int snmp_get_varbind_string(SNMPMessage *message, int num, char **oid, int *type, char **str_value)
{
  int render_as_type;
  Value value;
    
  if (!get_varbind_value(message, num, oid, type, &render_as_type, &value))
    return 0;
    
  //TODO return value of 0 also indicates end of list
  //handle non-string data differently?
  if (render_as_type != ASN1_STRING_TYPE)
    return 0;

  if (str_value)
    *str_value = value.str_value;
    
  return 1;
}

int snmp_get_varbind_as_string(SNMPMessage *message, int num, char **oid, int *type, char **value_str)
{
  int render_as_type;
  Value value;
  char buf[20];
    
  if (!get_varbind_value(message, num, oid, type, &render_as_type, &value))
    return 0;

  if (!value_str)
    return 1;
    
  switch (render_as_type)
    {
    case ASN1_NULL_TYPE:
      *value_str = strdup("");
      break;
    case ASN1_INTEGER_TYPE:
      snprintf(buf, sizeof(buf), "%d", value.int_value);
      *value_str = strdup(buf);
      break;
    case ASN1_STRING_TYPE:
      *value_str = strdup(value.str_value);
      break;
    default:
      abort();
    }
    
  return 1;
}
