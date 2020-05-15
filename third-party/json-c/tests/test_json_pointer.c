#include "strerror_override.h"
#include "strerror_override_private.h"
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "json.h"

static void test_example_int(struct json_object *jo1, const char *json_pointer, int expected_int)
{
	struct json_object *jo2 = NULL;
	assert(0 == json_pointer_get(jo1, json_pointer, NULL));
	assert(0 == json_pointer_get(jo1, json_pointer, &jo2));
	assert(json_object_is_type(jo2, json_type_int));
	assert(expected_int == json_object_get_int(jo2));
	printf("PASSED - GET -  %s == %d\n", json_pointer, expected_int);
}

static const char *input_json_str = "{ "
                                    "'foo': ['bar', 'baz'], "
                                    "'': 0, "
                                    "'a/b': 1, "
                                    "'c%d': 2, "
                                    "'e^f': 3, "
                                    "'g|h': 4, "
                                    "'i\\\\j': 5, "
                                    "'k\\\"l': 6, "
                                    "' ': 7, "
                                    "'m~n': 8 "
                                    "}";

/* clang-format off */
static const char *rec_input_json_str =
    "{"
	    "'arr' : ["
		    "{"
			    "'obj': ["
				    "{},{},"
					"{"
					    "'obj1': 0,"
					    "'obj2': \"1\""
				    "}"
			    "]"
		    "}"
	    "],"
	    "'obj' : {"
		    "'obj': {"
			    "'obj': ["
				    "{"
					    "'obj1': 0,"
					    "'obj2': \"1\""
				    "}"
			    "]"
		    "}"
	    "}"
    "}";
/* clang-format on */

/* Example from RFC */
static void test_example_get()
{
	int i;
	struct json_object *jo1, *jo2, *jo3;
	struct json_pointer_map_s_i
	{
		const char *s;
		int i;
	};
	/* Create a map to iterate over for the ints */
	/* clang-format off */
	struct json_pointer_map_s_i json_pointers[] = {
		{ "/", 0 },
		{ "/a~1b", 1 },
		{"/c%d", 2 },
		{"/e^f", 3 },
		{ "/g|h", 4 },
		{ "/i\\j", 5 },
		{ "/k\"l", 6 },
		{ "/ ", 7 },
		{ "/m~0n", 8 },
		{ NULL, 0}
	};
	/* clang-format on */

	jo1 = json_tokener_parse(input_json_str);
	assert(NULL != jo1);
	printf("PASSED - GET - LOADED TEST JSON\n");
	printf("%s\n", json_object_get_string(jo1));

	/* Test empty string returns entire object */
	jo2 = NULL;
	/* For each test, we're trying to see that NULL **value works (does no segfault) */
	assert(0 == json_pointer_get(jo1, "", NULL));
	assert(0 == json_pointer_get(jo1, "", &jo2));
	assert(json_object_equal(jo2, jo1));
	printf("PASSED - GET - ENTIRE OBJECT WORKED\n");

	/* Test /foo == ['bar', 'baz']  */
	jo3 = json_object_new_array();
	json_object_array_add(jo3, json_object_new_string("bar"));
	json_object_array_add(jo3, json_object_new_string("baz"));

	jo2 = NULL;
	assert(0 == json_pointer_get(jo1, "/foo", NULL));
	assert(0 == json_pointer_get(jo1, "/foo", &jo2));
	assert(NULL != jo2);
	assert(json_object_equal(jo2, jo3));
	json_object_put(jo3);
	printf("PASSED - GET - /foo == ['bar', 'baz']\n");

	/* Test /foo/0 == 'bar' */
	jo2 = NULL;
	assert(0 == json_pointer_get(jo1, "/foo/0", NULL));
	assert(0 == json_pointer_get(jo1, "/foo/0", &jo2));
	assert(NULL != jo2);
	assert(0 == strcmp("bar", json_object_get_string(jo2)));
	printf("PASSED - GET - /foo/0 == 'bar'\n");

	for (i = 0; json_pointers[i].s; i++)
		test_example_int(jo1, json_pointers[i].s, json_pointers[i].i);

	json_object_put(jo1);
}

/* I'm not too happy with the RFC example to test the recusion of the json_pointer_get() function */
static void test_recursion_get()
{
	struct json_object *jo2, *jo1 = json_tokener_parse(rec_input_json_str);

	jo2 = NULL;
	assert(jo1 != NULL);
	printf("%s\n", json_object_get_string(jo1));
	assert(0 == json_pointer_get(jo1, "/arr/0/obj/2/obj1", &jo2));
	assert(json_object_is_type(jo2, json_type_int));
	assert(0 == json_object_get_int(jo2));

	assert(0 == json_pointer_get(jo1, "/arr/0/obj/2/obj2", &jo2));
	assert(json_object_is_type(jo2, json_type_string));
	assert(0 == strcmp("1", json_object_get_string(jo2)));

	assert(0 == json_pointer_getf(jo1, &jo2, "/%s/%d/%s/%d/%s", "arr", 0, "obj", 2, "obj2"));
	assert(json_object_is_type(jo2, json_type_string));
	assert(0 == strcmp("1", json_object_get_string(jo2)));

	assert(jo1 != NULL);
	assert(0 == json_pointer_get(jo1, "/obj/obj/obj/0/obj1", &jo2));
	assert(json_object_is_type(jo2, json_type_int));
	assert(0 == json_object_get_int(jo2));

	assert(0 == json_pointer_get(jo1, "/obj/obj/obj/0/obj2", &jo2));
	assert(json_object_is_type(jo2, json_type_string));
	assert(0 == strcmp("1", json_object_get_string(jo2)));

	assert(0 == json_pointer_getf(jo1, &jo2, "%s", "\0"));

	printf("PASSED - GET - RECURSION TEST\n");

	json_object_put(jo1);
}

static void test_wrong_inputs_get()
{
	struct json_object *jo2, *jo1 = json_tokener_parse(input_json_str);

	assert(NULL != jo1);
	printf("PASSED - GET - LOADED TEST JSON\n");
	printf("%s\n", json_object_get_string(jo1));

	/* Test leading '/' missing */
	jo2 = NULL;
	errno = 0;
	assert(0 != json_pointer_get(jo1, "foo/bar", NULL));
	assert(0 != json_pointer_get(jo1, "foo/bar", &jo2));
	assert(errno == EINVAL);
	assert(jo2 == NULL);
	printf("PASSED - GET - MISSING /\n");

	/* Test combinations of NULL params for input json & path */
	errno = 0;
	assert(0 != json_pointer_get(NULL, "foo/bar", NULL));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_get(NULL, NULL, NULL));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_getf(NULL, NULL, NULL));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_get(jo1, NULL, NULL));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_getf(jo1, NULL, NULL));
	assert(errno == EINVAL);
	printf("PASSED - GET - NULL INPUTS\n");

	/* Test invalid indexes for array */
	errno = 0;
	assert(0 != json_pointer_get(jo1, "/foo/a", NULL));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_get(jo1, "/foo/01", NULL));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_getf(jo1, NULL, "/%s/a", "foo"));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_get(jo1, "/foo/-", NULL));
	assert(errno == EINVAL);
	errno = 0;
	/* Test optimized array path */
	assert(0 != json_pointer_get(jo1, "/foo/4", NULL));
	assert(errno == ENOENT);
	errno = 0;
	/* Test non-optimized array path */
	assert(0 != json_pointer_getf(jo1, NULL, "%s", "/foo/22"));
	assert(errno == ENOENT);
	errno = 0;
	assert(0 != json_pointer_getf(jo1, NULL, "/%s/%d", "foo", 22));
	assert(errno == ENOENT);
	errno = 0;
	assert(0 != json_pointer_get(jo1, "/foo/-1", NULL));
	assert(errno == EINVAL);
	errno = 0;
	assert(0 != json_pointer_get(jo1, "/foo/10", NULL));
	assert(errno == ENOENT);
	printf("PASSED - GET - INVALID INDEXES\n");

	json_object_put(jo1);
}

static void test_example_set()
{
	struct json_object *jo2, *jo1 = json_tokener_parse(input_json_str);

	assert(jo1 != NULL);
	printf("PASSED - SET - LOADED TEST JSON\n");
	printf("%s\n", json_object_get_string(jo1));

	assert(0 == json_pointer_set(&jo1, "/foo/1", json_object_new_string("cod")));
	assert(0 == strcmp("cod", json_object_get_string(json_object_array_get_idx(
	                              json_object_object_get(jo1, "foo"), 1))));
	printf("PASSED - SET - 'cod' in /foo/1\n");
	assert(0 != json_pointer_set(&jo1, "/fud/gaw", (jo2 = json_tokener_parse("[1,2,3]"))));
	assert(errno == ENOENT);
	printf("PASSED - SET - non-existing /fud/gaw\n");
	assert(0 == json_pointer_set(&jo1, "/fud", json_object_new_object()));
	printf("PASSED - SET - /fud == {}\n");
	assert(0 == json_pointer_set(&jo1, "/fud/gaw", jo2)); /* re-using jo2 from above */
	printf("PASSED - SET - /fug/gaw == [1,2,3]\n");
	assert(0 == json_pointer_set(&jo1, "/fud/gaw/0", json_object_new_int(0)));
	assert(0 == json_pointer_setf(&jo1, json_object_new_int(0), "%s%s/%d", "/fud", "/gaw", 0));
	printf("PASSED - SET - /fug/gaw == [0,2,3]\n");
	assert(0 == json_pointer_set(&jo1, "/fud/gaw/-", json_object_new_int(4)));
	printf("PASSED - SET - /fug/gaw == [0,2,3,4]\n");
	assert(0 == json_pointer_set(&jo1, "/", json_object_new_int(9)));
	printf("PASSED - SET - / == 9\n");

	jo2 = json_tokener_parse(
	    "{ 'foo': [ 'bar', 'cod' ], '': 9, 'a/b': 1, 'c%d': 2, 'e^f': 3, 'g|h': 4, 'i\\\\j': "
	    "5, 'k\\\"l': 6, ' ': 7, 'm~n': 8, 'fud': { 'gaw': [ 0, 2, 3, 4 ] } }");
	assert(json_object_equal(jo2, jo1));
	printf("PASSED - SET - Final JSON is: %s\n", json_object_get_string(jo1));
	json_object_put(jo2);

	assert(0 == json_pointer_set(&jo1, "", json_object_new_int(10)));
	assert(10 == json_object_get_int(jo1));
	printf("%s\n", json_object_get_string(jo1));

	json_object_put(jo1);
}

static void test_wrong_inputs_set()
{
	struct json_object *jo2, *jo1 = json_tokener_parse(input_json_str);

	assert(jo1 != NULL);
	printf("PASSED - SET - LOADED TEST JSON\n");
	printf("%s\n", json_object_get_string(jo1));

	assert(0 != json_pointer_set(NULL, NULL, NULL));
	assert(0 != json_pointer_setf(NULL, NULL, NULL));
	assert(0 != json_pointer_set(&jo1, NULL, NULL));
	assert(0 != json_pointer_setf(&jo1, NULL, NULL));
	printf("PASSED - SET - failed with NULL params for input json & path\n");

	assert(0 != json_pointer_set(&jo1, "foo/bar", (jo2 = json_object_new_string("cod"))));
	printf("PASSED - SET - failed 'cod' with path 'foo/bar'\n");
	json_object_put(jo2);

	assert(0 !=
	       json_pointer_setf(&jo1, (jo2 = json_object_new_string("cod")), "%s", "foo/bar"));
	printf("PASSED - SET - failed 'cod' with path 'foo/bar'\n");
	json_object_put(jo2);

	assert(0 != json_pointer_set(&jo1, "0", (jo2 = json_object_new_string("cod"))));
	printf("PASSED - SET - failed with invalid array index'\n");
	json_object_put(jo2);

	jo2 = json_object_new_string("whatever");
	assert(0 != json_pointer_set(&jo1, "/fud/gaw", jo2));
	assert(0 == json_pointer_set(&jo1, "/fud", json_object_new_object()));
	assert(0 == json_pointer_set(&jo1, "/fud/gaw", jo2)); /* re-using jo2 from above */
	// ownership of jo2 transferred into jo1

	jo2 = json_object_new_int(0);
	assert(0 != json_pointer_set(&jo1, "/fud/gaw/0", jo2));
	json_object_put(jo2);
	jo2 = json_object_new_int(0);
	assert(0 != json_pointer_set(&jo1, "/fud/gaw/", jo2));
	json_object_put(jo2);
	printf("PASSED - SET - failed to set index to non-array\n");

	assert(0 == json_pointer_setf(&jo1, json_object_new_string("cod"), "%s", "\0"));

	json_object_put(jo1);
}

int main(int argc, char **argv)
{
	_json_c_strerror_enable = 1;

	test_example_get();
	test_recursion_get();
	test_wrong_inputs_get();
	test_example_set();
	test_wrong_inputs_set();
	return 0;
}
