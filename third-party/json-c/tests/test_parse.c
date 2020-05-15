#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "json.h"
#include "json_tokener.h"
#include "json_visit.h"

static void test_basic_parse(void);
static void test_utf8_parse(void);
static void test_verbose_parse(void);
static void test_incremental_parse(void);

int main(void)
{
	MC_SET_DEBUG(1);

	static const char separator[] = "==================================";
	test_basic_parse();
	puts(separator);
	test_utf8_parse();
	puts(separator);
	test_verbose_parse();
	puts(separator);
	test_incremental_parse();
	puts(separator);

	return 0;
}

static json_c_visit_userfunc clear_serializer;
static void do_clear_serializer(json_object *jso);

static void single_basic_parse(const char *test_string, int clear_serializer)
{
	json_object *new_obj;

	new_obj = json_tokener_parse(test_string);
	if (clear_serializer)
		do_clear_serializer(new_obj);
	printf("new_obj.to_string(%s)=%s\n", test_string, json_object_to_json_string(new_obj));
	json_object_put(new_obj);
}
static void test_basic_parse()
{
	single_basic_parse("\"\003\"", 0);
	single_basic_parse("/* hello */\"foo\"", 0);
	single_basic_parse("// hello\n\"foo\"", 0);
	single_basic_parse("\"foo\"blue", 0);
	single_basic_parse("\'foo\'", 0);
	single_basic_parse("\"\\u0041\\u0042\\u0043\"", 0);
	single_basic_parse("\"\\u4e16\\u754c\\u00df\"", 0);
	single_basic_parse("\"\\u4E16\"", 0);
	single_basic_parse("\"\\u4e1\"", 0);
	single_basic_parse("\"\\u4e1@\"", 0);
	single_basic_parse("\"\\ud840\\u4e16\"", 0);
	single_basic_parse("\"\\ud840\"", 0);
	single_basic_parse("\"\\udd27\"", 0);
	// Test with a "short" high surrogate
	single_basic_parse("[9,'\\uDAD", 0);
	single_basic_parse("null", 0);
	single_basic_parse("NaN", 0);
	single_basic_parse("-NaN", 0); /* non-sensical, returns null */

	single_basic_parse("Inf", 0); /* must use full string, returns null */
	single_basic_parse("inf", 0); /* must use full string, returns null */
	single_basic_parse("Infinity", 0);
	single_basic_parse("infinity", 0);
	single_basic_parse("-Infinity", 0);
	single_basic_parse("-infinity", 0);
	single_basic_parse("{ \"min\": Infinity, \"max\": -Infinity}", 0);

	single_basic_parse("Infinity!", 0);
	single_basic_parse("Infinitynull", 0);
	single_basic_parse("InfinityXXXX", 0);
	single_basic_parse("-Infinitynull", 0);
	single_basic_parse("-InfinityXXXX", 0);
	single_basic_parse("Infinoodle", 0);
	single_basic_parse("InfinAAA", 0);
	single_basic_parse("-Infinoodle", 0);
	single_basic_parse("-InfinAAA", 0);

	single_basic_parse("True", 0);
	single_basic_parse("False", 0);

	/* not case sensitive */
	single_basic_parse("tRue", 0);
	single_basic_parse("fAlse", 0);
	single_basic_parse("nAn", 0);
	single_basic_parse("iNfinity", 0);

	single_basic_parse("12", 0);
	single_basic_parse("12.3", 0);
	single_basic_parse("12.3.4", 0); /* non-sensical, returns null */
	/* was returning (int)2015 before patch, should return null */
	single_basic_parse("2015-01-15", 0);

	/* ...but this works.  It's rather inconsistent, and a future major release
	 * should change the behavior so it either always returns null when extra
	 * bytes are present (preferred), or always return object created from as much
	 * as was able to be parsed.
	 */
	single_basic_parse("12.3xxx", 0);

	single_basic_parse("{\"FoO\"  :   -12.3E512}", 0);
	single_basic_parse("{\"FoO\"  :   -12.3e512}", 0);
	single_basic_parse("{\"FoO\"  :   -12.3E51.2}", 0);   /* non-sensical, returns null */
	single_basic_parse("{\"FoO\"  :   -12.3E512E12}", 0); /* non-sensical, returns null */
	single_basic_parse("[\"\\n\"]", 0);
	single_basic_parse("[\"\\nabc\\n\"]", 0);
	single_basic_parse("[null]", 0);
	single_basic_parse("[]", 0);
	single_basic_parse("[false]", 0);
	single_basic_parse("[\"abc\",null,\"def\",12]", 0);
	single_basic_parse("{}", 0);
	single_basic_parse("{ \"foo\": \"bar\" }", 0);
	single_basic_parse("{ \'foo\': \'bar\' }", 0);
	single_basic_parse("{ \"foo\": \"bar\", \"baz\": null, \"bool0\": true }", 0);
	single_basic_parse("{ \"foo\": [null, \"foo\"] }", 0);
	single_basic_parse("{ \"abc\": 12, \"foo\": \"bar\", \"bool0\": false, \"bool1\": true, "
	                   "\"arr\": [ 1, 2, 3, null, 5 ] }",
	                   0);
	single_basic_parse("{ \"abc\": \"blue\nred\\ngreen\" }", 0);

	// Clear serializer for these tests so we see the actual parsed value.
	single_basic_parse("null", 1);
	single_basic_parse("false", 1);
	single_basic_parse("[0e]", 1);
	single_basic_parse("[0e+]", 1);
	single_basic_parse("[0e+-1]", 1);
	single_basic_parse("\"hello world!\"", 1);

	// uint64/int64 range test
	single_basic_parse("[9223372036854775806]", 1);
	single_basic_parse("[9223372036854775807]", 1);
	single_basic_parse("[9223372036854775808]", 1);
	single_basic_parse("[-9223372036854775807]", 1);
	single_basic_parse("[-9223372036854775808]", 1);
	single_basic_parse("[-9223372036854775809]", 1);
	single_basic_parse("[18446744073709551614]", 1);
	single_basic_parse("[18446744073709551615]", 1);
	single_basic_parse("[18446744073709551616]", 1);
}

static void test_utf8_parse()
{
	// json_tokener_parse doesn't support checking for byte order marks.
	// It's the responsibility of the caller to detect and skip a BOM.
	// Both of these checks return null.
	char utf8_bom[] = {0xEF, 0xBB, 0xBF, 0x00};
	char utf8_bom_and_chars[] = {0xEF, 0xBB, 0xBF, '{', '}', 0x00};
	single_basic_parse(utf8_bom, 0);
	single_basic_parse(utf8_bom_and_chars, 0);
}

// Clear the re-serialization information that the tokener
// saves to ensure that the output reflects the actual
// values we parsed, rather than just the original input.
static void do_clear_serializer(json_object *jso)
{
	json_c_visit(jso, 0, clear_serializer, NULL);
}

static int clear_serializer(json_object *jso, int flags, json_object *parent_jso,
                            const char *jso_key, size_t *jso_index, void *userarg)
{
	if (jso)
		json_object_set_serializer(jso, NULL, NULL, NULL);
	return JSON_C_VISIT_RETURN_CONTINUE;
}

static void test_verbose_parse()
{
	json_object *new_obj;
	enum json_tokener_error error = json_tokener_success;

	new_obj = json_tokener_parse_verbose("{ foo }", &error);
	assert(error == json_tokener_error_parse_object_key_name);
	assert(new_obj == NULL);

	new_obj = json_tokener_parse("{ foo }");
	assert(new_obj == NULL);

	new_obj = json_tokener_parse("foo");
	assert(new_obj == NULL);
	new_obj = json_tokener_parse_verbose("foo", &error);
	assert(new_obj == NULL);

	/* b/c the string starts with 'f' parsing return a boolean error */
	assert(error == json_tokener_error_parse_boolean);

	puts("json_tokener_parse_verbose() OK");
}

struct incremental_step
{
	const char *string_to_parse;
	int length;
	int char_offset;
	enum json_tokener_error expected_error;
	int reset_tokener; /* Set to 1 to call json_tokener_reset() after parsing */
	int tok_flags; /* JSON_TOKENER_* flags to pass to json_tokener_set_flags() */
} incremental_steps[] = {

    /* Check that full json messages can be parsed, both w/ and w/o a reset */
    {"{ \"foo\": 123 }", -1, -1, json_tokener_success, 0},
    {"{ \"foo\": 456 }", -1, -1, json_tokener_success, 1},
    {"{ \"foo\": 789 }", -1, -1, json_tokener_success, 1},

    /* Check the comment parse*/
    {"/* hello */{ \"foo\"", -1, -1, json_tokener_continue, 0},
    {"/* hello */:/* hello */", -1, -1, json_tokener_continue, 0},
    {"\"bar\"/* hello */", -1, -1, json_tokener_continue, 0},
    {"}/* hello */", -1, -1, json_tokener_success, 1},
    {"/ hello ", -1, 1, json_tokener_error_parse_comment, 1},
    {"/* hello\"foo\"", -1, -1, json_tokener_continue, 1},
    {"/* hello*\"foo\"", -1, -1, json_tokener_continue, 1},
    {"// hello\"foo\"", -1, -1, json_tokener_continue, 1},

    /*  Check a basic incremental parse */
    {"{ \"foo", -1, -1, json_tokener_continue, 0},
    {"\": {\"bar", -1, -1, json_tokener_continue, 0},
    {"\":13}}", -1, -1, json_tokener_success, 1},

    /* Check that json_tokener_reset actually resets */
    {"{ \"foo", -1, -1, json_tokener_continue, 1},
    {": \"bar\"}", -1, 0, json_tokener_error_parse_unexpected, 1},

    /* Check incremental parsing with trailing characters */
    {"{ \"foo", -1, -1, json_tokener_continue, 0},
    {"\": {\"bar", -1, -1, json_tokener_continue, 0},
    {"\":13}}XXXX", 10, 6, json_tokener_success, 0},
    {"XXXX", 4, 0, json_tokener_error_parse_unexpected, 1},

    /* Check that trailing characters can change w/o a reset */
    {"{\"x\": 123 }\"X\"", -1, 11, json_tokener_success, 0},
    {"\"Y\"", -1, -1, json_tokener_success, 1},

    /* Trailing characters should cause a failure in strict mode */
    {"{\"foo\":9}{\"bar\":8}", -1, 9, json_tokener_error_parse_unexpected, 1, JSON_TOKENER_STRICT },

    /* ... unless explicitly allowed. */
    {"{\"foo\":9}{\"bar\":8}", -1, 9, json_tokener_success, 0, JSON_TOKENER_STRICT|JSON_TOKENER_ALLOW_TRAILING_CHARS },
    {"{\"b\":8}ignored garbage", -1, 7, json_tokener_success, 1, JSON_TOKENER_STRICT|JSON_TOKENER_ALLOW_TRAILING_CHARS },

    /* To stop parsing a number we need to reach a non-digit, e.g. a \0 */
    {"1", 1, 1, json_tokener_continue, 0},
    /* This should parse as the number 12, since it continues the "1" */
    {"2", 2, 1, json_tokener_success, 0},
    {"12{", 3, 2, json_tokener_success, 1},
    /* Parse number in strict model */
    {"[02]", -1, 3, json_tokener_error_parse_number, 1, JSON_TOKENER_STRICT },

    /* Similar tests for other kinds of objects: */
    /* These could all return success immediately, since regardless of
	   what follows the false/true/null token we *will* return a json object,
       but it currently doesn't work that way.  hmm... */
    {"false", 5, 5, json_tokener_continue, 1},
    {"false", 6, 5, json_tokener_success, 1},
    {"true", 4, 4, json_tokener_continue, 1},
    {"true", 5, 4, json_tokener_success, 1},
    {"null", 4, 4, json_tokener_continue, 1},
    {"null", 5, 4, json_tokener_success, 1},

    {"Infinity", 9, 8, json_tokener_success, 1},
    {"infinity", 9, 8, json_tokener_success, 1},
    {"-infinity", 10, 9, json_tokener_success, 1},
    {"infinity", 9, 0, json_tokener_error_parse_unexpected, 1, JSON_TOKENER_STRICT },
    {"-infinity", 10, 1, json_tokener_error_parse_unexpected, 1, JSON_TOKENER_STRICT },

    {"inf", 3, 3, json_tokener_continue, 0},
    {"inity", 6, 5, json_tokener_success, 1},
    {"-inf", 4, 4, json_tokener_continue, 0},
    {"inity", 6, 5, json_tokener_success, 1},

    {"i", 1, 1, json_tokener_continue, 0},
    {"n", 1, 1, json_tokener_continue, 0},
    {"f", 1, 1, json_tokener_continue, 0},
    {"i", 1, 1, json_tokener_continue, 0},
    {"n", 1, 1, json_tokener_continue, 0},
    {"i", 1, 1, json_tokener_continue, 0},
    {"t", 1, 1, json_tokener_continue, 0},
    {"y", 1, 1, json_tokener_continue, 0},
    {"", 1, 0, json_tokener_success, 1},

    {"-", 1, 1, json_tokener_continue, 0},
    {"inf", 3, 3, json_tokener_continue, 0},
    {"ini", 3, 3, json_tokener_continue, 0},
    {"ty", 3, 2, json_tokener_success, 1},

    {"-", 1, 1, json_tokener_continue, 0},
    {"i", 1, 1, json_tokener_continue, 0},
    {"nfini", 5, 5, json_tokener_continue, 0},
    {"ty", 3, 2, json_tokener_success, 1},

    {"-i", 2, 2, json_tokener_continue, 0},
    {"nfinity", 8, 7, json_tokener_success, 1},

    {"InfinityX", 10, 8, json_tokener_success, 0},
    {"X", 1, 0, json_tokener_error_parse_unexpected, 1},

    {"Infinity1234", 13, 8, json_tokener_success, 0},
    {"1234", 5, 4, json_tokener_success, 1},

    {"Infinity9999", 8, 8, json_tokener_continue, 0},

    /* returns the Infinity loaded up by the previous call: */
    {"1234", 5, 0, json_tokener_success, 0},
    {"1234", 5, 4, json_tokener_success, 1},

    /* offset=1 because "n" is the start of "null".  hmm... */
    {"noodle", 7, 1, json_tokener_error_parse_null, 1},
    /* offset=2 because "na" is the start of "nan".  hmm... */
    {"naodle", 7, 2, json_tokener_error_parse_null, 1},
    /* offset=2 because "tr" is the start of "true".  hmm... */
    {"track", 6, 2, json_tokener_error_parse_boolean, 1},
    {"fail", 5, 2, json_tokener_error_parse_boolean, 1},

    /* Although they may initially look like they should fail,
	 * the next few tests check that parsing multiple sequential
	 * json objects in the input works as expected
	 */
    {"null123", 9, 4, json_tokener_success, 0},
    {&"null123"[4], 4, 3, json_tokener_success, 1},
    {"nullx", 5, 4, json_tokener_success, 0},
    {&"nullx"[4], 2, 0, json_tokener_error_parse_unexpected, 1},
    {"{\"a\":1}{\"b\":2}", 15, 7, json_tokener_success, 0},
    {&"{\"a\":1}{\"b\":2}"[7], 8, 7, json_tokener_success, 1},

    /* Some bad formatting. Check we get the correct error status */
    {"2015-01-15", 10, 4, json_tokener_error_parse_number, 1},

    /* Strings have a well defined end point, so we can stop at the quote */
    {"\"blue\"", -1, -1, json_tokener_success, 0},

    /* Check each of the escape sequences defined by the spec */
    {"\"\\\"\"", -1, -1, json_tokener_success, 0},
    {"\"\\\\\"", -1, -1, json_tokener_success, 0},
    {"\"\\b\"", -1, -1, json_tokener_success, 0},
    {"\"\\f\"", -1, -1, json_tokener_success, 0},
    {"\"\\n\"", -1, -1, json_tokener_success, 0},
    {"\"\\r\"", -1, -1, json_tokener_success, 0},
    {"\"\\t\"", -1, -1, json_tokener_success, 0},
    {"\"\\/\"", -1, -1, json_tokener_success, 0},
    // Escaping a forward slash is optional
    {"\"/\"", -1, -1, json_tokener_success, 0},
    /* Check wrong escape sequences */
    {"\"\\a\"", -1, 2, json_tokener_error_parse_string, 1},

    /* Check '\'' in strict model */
    {"\'foo\'", -1, 0, json_tokener_error_parse_unexpected, 1, JSON_TOKENER_STRICT },

    /* Parse array/object */
    {"[1,2,3]", -1, -1, json_tokener_success, 0},
    {"[1,2,3}", -1, 6, json_tokener_error_parse_array, 1},
    {"{\"a\"}", -1, 4, json_tokener_error_parse_object_key_sep, 1},
    {"{\"a\":1]", -1, 6, json_tokener_error_parse_object_value_sep, 1},
    {"{\"a\"::1}", -1, 5, json_tokener_error_parse_unexpected, 1},
    {"{\"a\":}", -1, 5, json_tokener_error_parse_unexpected, 1},
    {"{\"a\":1,\"a\":2}", -1, -1, json_tokener_success, 1},
    {"\"a\":1}", -1, 3, json_tokener_success, 1},
    {"{\"a\":1", -1, -1, json_tokener_continue, 1},
    {"[,]", -1, 1, json_tokener_error_parse_unexpected, 1},
    {"[,1]", -1, 1, json_tokener_error_parse_unexpected, 1},

    /* This behaviour doesn't entirely follow the json spec, but until we have
	 * a way to specify how strict to be we follow Postel's Law and be liberal
	 * in what we accept (up to a point).
	 */
    {"[1,2,3,]", -1, -1, json_tokener_success, 0},
    {"[1,2,,3,]", -1, 5, json_tokener_error_parse_unexpected, 0},

    {"[1,2,3,]", -1, 7, json_tokener_error_parse_unexpected, 1, JSON_TOKENER_STRICT },
    {"{\"a\":1,}", -1, 7, json_tokener_error_parse_unexpected, 1, JSON_TOKENER_STRICT },

    // utf-8 test
    // acsll encoding
    {"\x22\x31\x32\x33\x61\x73\x63\x24\x25\x26\x22", -1, -1, json_tokener_success, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\x31\x32\x33\x61\x73\x63\x24\x25\x26\x22", -1, -1, json_tokener_success, 1},
    // utf-8 encoding
    {"\x22\xe4\xb8\x96\xe7\x95\x8c\x22", -1, -1, json_tokener_success, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\xe4\xb8", -1, 3, json_tokener_error_parse_utf8_string, 0, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x96\xe7\x95\x8c\x22", -1, 0, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\xe4\xb8\x96\xe7\x95\x8c\x22", -1, -1, json_tokener_success, 1},
    {"\x22\xcf\x80\xcf\x86\x22", -1, -1, json_tokener_success, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\xf0\xa5\x91\x95\x22", -1, -1, json_tokener_success, 1, JSON_TOKENER_VALIDATE_UTF8 },
    // wrong utf-8 encoding
    {"\x22\xe6\x9d\x4e\x22", -1, 3, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\xe6\x9d\x4e\x22", -1, 5, json_tokener_success, 1},
    // GBK encoding
    {"\x22\xc0\xee\xc5\xf4\x22", -1, 2, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\xc0\xee\xc5\xf4\x22", -1, 6, json_tokener_success, 1},
    // char after space
    {"\x20\x20\x22\xe4\xb8\x96\x22", -1, -1, json_tokener_success, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x20\x20\x81\x22\xe4\xb8\x96\x22", -1, 2, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x5b\x20\x81\x31\x5d", -1, 2, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    // char in state inf
    {"\x49\x6e\x66\x69\x6e\x69\x74\x79", 9, 8, json_tokener_success, 1},
    {"\x49\x6e\x66\x81\x6e\x69\x74\x79", -1, 3, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    // char in escape unicode
    {"\x22\x5c\x75\x64\x38\x35\x35\x5c\x75\x64\x63\x35\x35\x22", 15, 14, json_tokener_success, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\x5c\x75\x64\x38\x35\x35\xc0\x75\x64\x63\x35\x35\x22", -1, 8,
     json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    {"\x22\x5c\x75\x64\x30\x30\x33\x31\xc0\x22", -1, 9, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    // char in number
    {"\x31\x31\x81\x31\x31", -1, 2, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },
    // char in object
    {"\x7b\x22\x31\x81\x22\x3a\x31\x7d", -1, 3, json_tokener_error_parse_utf8_string, 1, JSON_TOKENER_VALIDATE_UTF8 },

    {NULL, -1, -1, json_tokener_success, 0},
};

static void test_incremental_parse()
{
	json_object *new_obj;
	enum json_tokener_error jerr;
	struct json_tokener *tok;
	const char *string_to_parse;
	int ii;
	int num_ok, num_error;

	num_ok = 0;
	num_error = 0;

	printf("Starting incremental tests.\n");
	printf("Note: quotes and backslashes seen in the output here are literal values passed\n");
	printf("     to the parse functions.  e.g. this is 4 characters: \"\\f\"\n");

	string_to_parse = "{ \"foo"; /* } */
	printf("json_tokener_parse(%s) ... ", string_to_parse);
	new_obj = json_tokener_parse(string_to_parse);
	if (new_obj == NULL)
		puts("got error as expected");

	/* test incremental parsing in various forms */
	tok = json_tokener_new();
	for (ii = 0; incremental_steps[ii].string_to_parse != NULL; ii++)
	{
		int this_step_ok = 0;
		struct incremental_step *step = &incremental_steps[ii];
		int length = step->length;
		size_t expected_char_offset;

		json_tokener_set_flags(tok, step->tok_flags);

		if (length == -1)
			length = strlen(step->string_to_parse);
		if (step->char_offset == -1)
			expected_char_offset = length;
		else
			expected_char_offset = step->char_offset;

		printf("json_tokener_parse_ex(tok, %-12s, %3d) ... ", step->string_to_parse,
		       length);
		new_obj = json_tokener_parse_ex(tok, step->string_to_parse, length);

		jerr = json_tokener_get_error(tok);
		if (step->expected_error != json_tokener_success)
		{
			if (new_obj != NULL)
				printf("ERROR: invalid object returned: %s\n",
				       json_object_to_json_string(new_obj));
			else if (jerr != step->expected_error)
				printf("ERROR: got wrong error: %s\n",
				       json_tokener_error_desc(jerr));
			else if (json_tokener_get_parse_end(tok) != expected_char_offset)
				printf("ERROR: wrong char_offset %zu != expected %zu\n",
				       json_tokener_get_parse_end(tok), expected_char_offset);
			else
			{
				printf("OK: got correct error: %s\n",
				       json_tokener_error_desc(jerr));
				this_step_ok = 1;
			}
		}
		else
		{
			if (new_obj == NULL &&
			    !(step->length >= 4 && strncmp(step->string_to_parse, "null", 4) == 0))
				printf("ERROR: expected valid object, instead: %s\n",
				       json_tokener_error_desc(jerr));
			else if (json_tokener_get_parse_end(tok) != expected_char_offset)
				printf("ERROR: wrong char_offset %zu != expected %zu\n",
				       json_tokener_get_parse_end(tok), expected_char_offset);
			else
			{
				printf("OK: got object of type [%s]: %s\n",
				       json_type_to_name(json_object_get_type(new_obj)),
				       json_object_to_json_string(new_obj));
				this_step_ok = 1;
			}
		}

		if (new_obj)
			json_object_put(new_obj);

		if (step->reset_tokener & 1)
			json_tokener_reset(tok);

		if (this_step_ok)
			num_ok++;
		else
			num_error++;
	}

	json_tokener_free(tok);

	printf("End Incremental Tests OK=%d ERROR=%d\n", num_ok, num_error);
}
