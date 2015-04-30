/*
 * gcc -o utf8 utf8.c -I/home/y/include -L./.libs -ljson
 */

#include <stdio.h>
#include <string.h>
#include "config.h"

#include "json_inttypes.h"
#include "json_object.h"
#include "json_tokener.h"

void print_hex( const char* s)
{
	const char *iter = s;
	unsigned char ch;
	while ((ch = *iter++) != 0)
	{
		if( ',' != ch)
			printf("%x ", ch);
		else
			printf( ",");
	}
	printf("\n");
}

int main()
{
	const char *input = "\"\\ud840\\udd26,\\ud840\\udd27,\\ud800\\udd26,\\ud800\\udd27\"";
	const char *expected = "\xF0\xA0\x84\xA6,\xF0\xA0\x84\xA7,\xF0\x90\x84\xA6,\xF0\x90\x84\xA7";
	struct json_object *parse_result = json_tokener_parse((char*)input);
	const char *unjson = json_object_get_string(parse_result);

	printf("input: %s\n", input);

	int strings_match = !strcmp( expected, unjson);
	int retval = 0;
	if (strings_match)
	{
		printf("JSON parse result is correct: %s\n", unjson);
		printf("PASS\n");
	} else {
		printf("JSON parse result doesn't match expected string\n");
		printf("expected string bytes: ");
		print_hex( expected);
		printf("parsed string bytes:   ");
		print_hex( unjson);
		printf("FAIL\n");
		retval = 1;
	}
	json_object_put(parse_result);
	return retval;
}
