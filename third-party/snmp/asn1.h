#ifndef ASN1_H
#define ASN1_H

enum {
  ASN1_INTEGER_TYPE = 0x02,
  ASN1_STRING_TYPE = 0x04,
  ASN1_NULL_TYPE = 0x05,
  ASN1_OID_TYPE = 0x06,
  ASN1_SEQUENCE_TYPE = 0x30
};

typedef union {
  char *str_value;
  int int_value;
  void *value;
} Value;

int header_length(int type, int data_len);

int sequence_header_length(int data_len);

int integer_length(int x);

int string_length(char *str);

int oid_length(char *oid);

int object_length(int data_len);


void *render_header(int type, int len, void *dest);

void *render_sequence_header(int len, void *dest);

void *render_null_object(void *dest);

void *render_integer_object(int x, void *dest);

void *render_string_object(char *str, void *dest);

void *render_oid_object(char *oid, void *dest);

int value_length(int render_as_type, Value value);

char *render_value(int render_as_type, Value value, char *dest);

char *render_value_object(int value_type, int render_as_type, Value value, char *dest);


typedef struct ASN1Parser ASN1Parser;

ASN1Parser *asn1_create_parser(void *buffer, int len);
int asn1_parse_peek(ASN1Parser *parser, int *type, int *len);
int asn1_parse_sequence(ASN1Parser *parser);
int asn1_parse_structure(ASN1Parser *parser, int *type);
int asn1_parse_integer_type(ASN1Parser *parser, int *type, int *dest);
int asn1_parse_integer(ASN1Parser *parser, int *dest);
int asn1_parse_string_type(ASN1Parser *parser, int *type, char **dest);
int asn1_parse_string(ASN1Parser *parser, char **dest);
int asn1_parse_oid(ASN1Parser *parser, char **dest);
int asn1_parse_primitive_value(ASN1Parser *parser, int *type, Value *value);
int asn1_parse_pop(ASN1Parser *parser);
void asn1_destroy_parser(ASN1Parser *parser);

#endif
