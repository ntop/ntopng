#include "asn1.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>

#define MAX_OID_PARTS   256

static void *render_byte(int byte, void *dest)
{
  
  *(unsigned char *) dest = (unsigned char) byte;
  return (unsigned char *)dest + 1;
}

static void *read_byte(void *src, int *x)
{
  *x = *(unsigned char *) src;
  return (unsigned char *)src + 1;
}

static int length_length(int len)
{
  if (len <= 127)
    return 1;
  else
    {
      int size = 1;
      while (len > 255)
        {
	  len >>= 8;
	  size += 1;
        }
            
      return size + 1;
    }
}

static void *render_length(int data_len, void *dest)
{
  if (data_len <= 127)
    {
      return render_byte(data_len, dest);
    }
  else
    {
      int size = length_length(data_len) - 1;
      int i;
        
      dest = render_byte(size | 0x80, dest);
      for (i = size - 1; i >= 0; i--)
        {
	  int v = (data_len >> (8 * i)) & 0xFF;
	  dest = render_byte(v, dest);
        }
      return dest;
    }
}

static void *read_length(void *src, int *len)
{
  int v;
  src = read_byte(src, &v);
  if (v <= 127)
    {
      *len = v;
    }
  else
    {
      int size = v & 0x7F;
      int val = 0;
      int i;
        
      for (i = 0; i < size; i++)
        {
	  src = read_byte(src, &v);
	  val = (val << 8) + v;
        }
      *len = val;
    }
  return src;
}

int header_length(int type, int data_len)
{
  return 1 + length_length(data_len);
}

void *render_header(int type, int data_len, void *dest)
{
  dest = render_byte(type, dest);
  return render_length(data_len, dest);
}

int sequence_header_length(int data_len)
{
  return header_length(ASN1_SEQUENCE_TYPE, data_len);
}

void *render_sequence_header(int data_len, void *dest)
{
  return render_header(ASN1_SEQUENCE_TYPE, data_len, dest);
}

static int null_length()
{
  return 0;
}

static void *render_null(void *dest)
{
  return dest;
}

int integer_length(int x)
{
  return 4;
  //assert(x <= 255);
  //int data_len = 1;
  //return data_len;
}

static void *render_integer(int x, void *dest)
{
  //TODO optimise
  dest = render_byte((x >> 24) & 0xFF, dest);
  dest = render_byte((x >> 16) & 0xFF, dest);
  dest = render_byte((x >> 8) & 0xFF, dest);
  dest = render_byte(x & 0xFF, dest);
  return dest;
  //assert(x <= 255);
  //return render_byte(x, dest);
}

void *render_integer_object(int x, void *dest)
{
  int data_len = integer_length(x);
  dest = render_header(ASN1_INTEGER_TYPE, data_len, dest);
  return render_integer(x, dest);
}

int string_length(char *str)
{
  int data_len = strlen(str);
  return data_len;
}

static void *render_string(char *str, void *dest)
{
  int len = strlen(str);
  memmove(dest, str, len);
  return (unsigned char *)dest + len;
}

void *render_string_object(char *str, void *dest)
{
  int data_len = string_length(str);
  dest = render_header(ASN1_STRING_TYPE, data_len, dest);
  return render_string(str, dest);
}

static int oid_parts(char *oid)
{
  int parts = 1;
  char *p = oid;
    
  while (*p)
    {
      if (*p == '.')
	parts++;
      p++;
    }
  return parts;
}

static void oid_split(char *oid, int *dest)
{
  int next_part = 0;
  char *temp = strdup(oid);
  char *save_ptr;
    
  char *p = strtok_r(temp, ".", &save_ptr);
  while (p)
    {
      dest[next_part] = atoi(p);
      next_part++;
      p = strtok_r(NULL, ".", &save_ptr);
    }
    
  free(temp);
}

static int oid_part_length(int part)
{
  int len = 1;
    
  while (part > 127)
    {
      part >>= 7;
      len++;
    }
    
  return len;
}

static void *render_oid_part(int part, void *dest)
{
  int len = oid_part_length(part);
  int i;
    
  for (i = len-1; i >= 0; i--)
    {
      int v = part & 0x7F;
      if (i != len-1)
	v |= 0x80;
      part >>= 7;
      *(unsigned char *) ((unsigned char *)dest + i) = (char) v;
    }
    
  return (unsigned char *)dest + len;
}

int oid_length(char *oid)
{
  int data_len = 1;
  int num_parts = oid_parts(oid);
  int parts[MAX_OID_PARTS];
  int i;
    
  oid_split(oid, parts);
    
  for (i = 2; i < num_parts; i++)
    {
      data_len += oid_part_length(parts[i]);
    }
    
  return data_len;
}

static void *render_oid(char *oid, void *dest)
{
  int num_parts = oid_parts(oid);
  int parts[MAX_OID_PARTS];
  int i;
  int first_two;
    
  oid_split(oid, parts);
        
  first_two = parts[0] * 40 + parts[1];
  dest = render_byte(first_two, dest);
  for (i = 2; i < num_parts; i++)
    dest = render_oid_part(parts[i], dest);
    
  return dest;
}

void *render_oid_object(char *oid, void *dest)
{
  int data_len = oid_length(oid);
  dest = render_header(ASN1_OID_TYPE, data_len, dest);
  return render_oid(oid, dest);
}

static void *read_oid_part(void *src, int *part)
{
  int v;
  int val = 0;
  do
    {
      src = read_byte(src, &v);
      val = (val << 7) + (v & 0x7F);
    }
  while (v > 127);
  *part = val;
  return src;
}

static void *read_oid(void *src, char **oid, int size)
{
	int parts[MAX_OID_PARTS + 1];
  int first_byte;
  int i;
  void *endp = (unsigned char *)src + size;
  int num_parts;
  int len;
  char *p;
    
  src = read_byte(src, &first_byte);
  parts[0] = first_byte / 40;
  parts[1] = first_byte % 40;
    
  i = 2;
    
  while (src < endp)
    {
      src = read_oid_part(src, &parts[i]);
      i++;
    }
  num_parts = i;
    
  len = num_parts-1;
  for (i = 0; i < num_parts; i++)
    {
      len += snprintf(NULL, 0, "%d", parts[i]);
    }
    
  *oid = (char*)malloc(len+1);
  p = *oid;
  p += sprintf(p, "%d", parts[0]);
  for (i =1; i < num_parts; i++)
    {
      p += sprintf(p, ".%d", parts[i]);
    }
    
  return src;
}

int value_length(int render_as_type, Value value)
{
  switch (render_as_type)
    {
    case ASN1_NULL_TYPE:
      return null_length();
    case ASN1_INTEGER_TYPE:
      return integer_length(value.int_value);
    case ASN1_STRING_TYPE:
      return string_length(value.str_value);
    default:
      abort();
    }
}

char *render_value(int render_as_type, Value value, char *dest)
{
  switch (render_as_type)
    {
    case ASN1_NULL_TYPE:
      return (char*)render_null(dest);
    case ASN1_INTEGER_TYPE:
      return (char*)render_integer(value.int_value, dest);
    case ASN1_STRING_TYPE:
      return (char*)render_string(value.str_value, dest);
    default:
      abort();
    }
}

char *render_value_object(int value_type, int render_as_type, Value value, char *dest)
{
  int data_len = value_length(render_as_type, value);
  dest = (char*)render_header(value_type, data_len, dest);
    
  switch (render_as_type)
    {
    case ASN1_NULL_TYPE:
      return (char*)render_null(dest);
    case ASN1_INTEGER_TYPE:
      return (char*)render_integer(value.int_value, dest);
    case ASN1_STRING_TYPE:
      return (char*)render_string(value.str_value, dest);
    default:
      abort();
    }
}


int object_length(int data_len)
{
  return header_length(0, data_len) + data_len;
}

typedef struct ASN1ParserState
{
  void *buffer;
  int remaining;
    
  struct ASN1ParserState *next;
} ASN1ParserState;


struct ASN1Parser
{
  ASN1ParserState *state;
    
  int depth;
};

static int next_type(ASN1Parser *parser)
{
  if (parser->state->remaining == 0)
    return 0;
  return ((unsigned char *) parser->state->buffer)[0];
}

static int next_len(ASN1Parser *parser)
{
  int len;
  if (parser->state->remaining < 2)
    return 0;
  read_length((char*)parser->state->buffer + 1, &len);
  return len;
}

static void *next_payload(ASN1Parser *parser)
{
  int len;
  void *p;
  if (parser->state->remaining < 2)
    return 0;
  p = read_length((char*)parser->state->buffer + 1, &len);
  return p;
}

static void push_state(ASN1Parser *parser, void *buffer, int remaining)
{
  ASN1ParserState *state = (ASN1ParserState*)malloc(sizeof(ASN1ParserState));
  state->buffer = buffer;
  state->remaining = remaining;
  state->next = parser->state;
  parser->state = state;
  parser->depth++;
}

static void pop_state(ASN1Parser *parser)
{
  ASN1ParserState *next_state = parser->state->next;
  free(parser->state);
  parser->state = next_state;
  parser->depth--;
}

static void consume(ASN1Parser *parser)
{
  int len = next_len(parser);
  void *payload = next_payload(parser);
  parser->state->remaining -= len + (char*)payload - (char*)parser->state->buffer;
  parser->state->buffer = (char*)payload + len;
}

ASN1Parser *asn1_create_parser(void *buffer, int len)
{
  ASN1Parser *parser = (ASN1Parser*)malloc(sizeof(ASN1Parser));
  parser->state = NULL;
  push_state(parser, buffer, len);
  parser->depth = 0;
  return parser;
}

void asn1_destroy_parser(ASN1Parser *parser)
{
  while (parser->depth >= 0)
    {
      pop_state(parser);
    }
        
  free(parser);
}

int asn1_parse_peek(ASN1Parser *parser, int *type, int *len)
{
  if (parser->state->remaining == 0)
    return 0;
    
  if (type)
    *type = next_type(parser);
  if (len)
    *len = next_len(parser);
  return 1;
}

int asn1_parse_sequence(ASN1Parser *parser)
{
  int type;
  if (next_type(parser) != ASN1_SEQUENCE_TYPE)
    return 0;
  return asn1_parse_structure(parser, &type);
}

int asn1_parse_structure(ASN1Parser *parser, int *type)
{
  int t = next_type(parser);
  if (!(t & 0x20))
    return 0;
    
  if (type)
    *type = t;
    
  int len = next_len(parser);
  void *payload = next_payload(parser);
  if ((char*)payload + len > (char*)parser->state->buffer + parser->state->remaining)
    return 0;
  consume(parser);
  push_state(parser, payload, len);
  return 1;
}

int asn1_parse_integer_type(ASN1Parser *parser, int *type, int *dest)
{
  int size;
  void *payload;
  int i;
  int val;
    
  if (type)
    *type = next_type(parser);
    
  size = next_len(parser);
  payload = next_payload(parser);
    
  val = 0;
  for (i = 0; i < size; i++)
    {
      int v;
      payload = read_byte(payload, &v);
      val = (val << 8) + v;
    }
    
  *dest = val;
  consume(parser);
  return 1;
}

int asn1_parse_integer(ASN1Parser *parser, int *dest)
{
  if (next_type(parser) != ASN1_INTEGER_TYPE)
    return 0;
    
  return asn1_parse_integer_type(parser, NULL, dest);
}

int asn1_parse_string_type(ASN1Parser *parser, int *type, char **dest)
{
  int size;
  void *payload;
  int i;

  if (type)
    *type = next_type(parser);
    
  size = next_len(parser);
  payload = next_payload(parser);
    
  *dest = (char*)malloc(size + 1);
    
  for (i = 0; i < size; i++)
    {
      int v;
      payload = read_byte(payload, &v);
      (*dest)[i] = v;
    }
  (*dest)[i] = 0;
  
  /* Patch for detecting MAC addresses and thus format them properly */
  if(size == 6) {
    u_int all_printable = 1;

    for(i = 0; i<size; i++) {
      if(!isprint((*dest)[i])) {
	all_printable = 0;
	break;
      }
    }

    if(!all_printable) {
      /* This looks like a MAC address */
      char tmp[24];

      snprintf(tmp, sizeof(tmp), "%02X:%02X:%02X:%02X:%02X:%02X",
	       (*dest)[0] & 0xFF, (*dest)[1] & 0xFF, (*dest)[2] & 0xFF, 
	       (*dest)[3] & 0xFF, (*dest)[4] & 0xFF, (*dest)[5] & 0xFF);

      free(*dest);
      *dest = strdup(tmp);
    }
  }
  
  consume(parser);
  return 1;
}

int asn1_parse_string(ASN1Parser *parser, char **dest)
{
  if (next_type(parser) != ASN1_STRING_TYPE)
    return 0;
  return asn1_parse_string_type(parser, NULL, dest);
}

int asn1_parse_oid(ASN1Parser *parser, char **dest)
{
  int size;
  void *payload;
    
  if (next_type(parser) != ASN1_OID_TYPE)
    return 0;
  size = next_len(parser);
  payload = next_payload(parser);
    
  read_oid(payload, dest, size);
    
  consume(parser);
  return 1;
}

int asn1_parse_primitive_value(ASN1Parser *parser, int *type, Value *value)
{
  int the_type = next_type(parser);
    
  if (type)
    *type = the_type;
    
  switch (the_type)
    {
    case ASN1_NULL_TYPE:
      consume(parser);
      return 1;
        
    case ASN1_INTEGER_TYPE:
      return asn1_parse_integer(parser, &value->int_value);
        
    case ASN1_STRING_TYPE:
      return asn1_parse_string(parser, &value->str_value);
        
    default:
      return 0;
    }
}

int asn1_parse_pop(ASN1Parser *parser)
{
  if (parser->depth == 0)
    return 0;
    
  if (parser->state->remaining != 0)
    return 0;
    
  parser->depth--;
  parser->state = parser->state->next;
  return 1;
}
