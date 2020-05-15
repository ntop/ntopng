#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "json.h"
#include "parse_flags.h"

static int sort_fn(const void *j1, const void *j2)
{
	json_object *const *jso1, *const *jso2;
	int i1, i2;

	jso1 = (json_object *const *)j1;
	jso2 = (json_object *const *)j2;
	if (!*jso1 && !*jso2)
		return 0;
	if (!*jso1)
		return -1;
	if (!*jso2)
		return 1;

	i1 = json_object_get_int(*jso1);
	i2 = json_object_get_int(*jso2);

	return i1 - i2;
}

#ifdef TEST_FORMATTED
static const char *to_json_string(json_object *obj, int flags)
{
	size_t length;
	char *copy;
	const char *result;

	result = json_object_to_json_string_length(obj, flags, &length);
	copy = strdup(result);
	if (copy == NULL)
		printf("to_json_string: Allocation failed!\n");
	else
	{
		result = json_object_to_json_string_ext(obj, flags);
		if (length != strlen(result))
			printf("to_json_string: Length mismatch!\n");
		if (strcmp(copy, result) != 0)
			printf("to_json_string: Comparison Failed!\n");
		free(copy);
	}
	return result;
}
#define json_object_to_json_string(obj) to_json_string(obj, sflags)
#else
/* no special define */
#endif

json_object *make_array(void);
json_object *make_array()
{
	json_object *my_array;

	my_array = json_object_new_array();
	json_object_array_add(my_array, json_object_new_int(1));
	json_object_array_add(my_array, json_object_new_int(2));
	json_object_array_add(my_array, json_object_new_int(3));
	json_object_array_put_idx(my_array, 4, json_object_new_int(5));
	json_object_array_put_idx(my_array, 3, json_object_new_int(4));
	json_object_array_put_idx(my_array, 6, json_object_new_int(7));

	return my_array;
}

void test_array_del_idx(void);
void test_array_del_idx()
{
	int rc;
	size_t ii;
	size_t orig_array_len;
	json_object *my_array;
#ifdef TEST_FORMATTED
	int sflags = 0;
#endif

	my_array = make_array();
	orig_array_len = json_object_array_length(my_array);

	printf("my_array=\n");
	for (ii = 0; ii < json_object_array_length(my_array); ii++)
	{
		json_object *obj = json_object_array_get_idx(my_array, ii);
		printf("\t[%d]=%s\n", (int)ii, json_object_to_json_string(obj));
	}
	printf("my_array.to_string()=%s\n", json_object_to_json_string(my_array));

	for (ii = 0; ii < orig_array_len; ii++)
	{
		rc = json_object_array_del_idx(my_array, 0, 1);
		printf("after del_idx(0,1)=%d, my_array.to_string()=%s\n", rc,
		       json_object_to_json_string(my_array));
	}

	/* One more time, with the empty array: */
	rc = json_object_array_del_idx(my_array, 0, 1);
	printf("after del_idx(0,1)=%d, my_array.to_string()=%s\n", rc,
	       json_object_to_json_string(my_array));

	json_object_put(my_array);

	/* Delete all array indexes at once */
	my_array = make_array();
	rc = json_object_array_del_idx(my_array, 0, orig_array_len);
	printf("after del_idx(0,%d)=%d, my_array.to_string()=%s\n", (int)orig_array_len, rc,
	       json_object_to_json_string(my_array));

	json_object_put(my_array);

	/* Delete *more* than all array indexes at once */
	my_array = make_array();
	rc = json_object_array_del_idx(my_array, 0, orig_array_len + 1);
	printf("after del_idx(0,%d)=%d, my_array.to_string()=%s\n", (int)(orig_array_len + 1), rc,
	       json_object_to_json_string(my_array));

	json_object_put(my_array);

	/* Delete some array indexes, then add more */
	my_array = make_array();
	rc = json_object_array_del_idx(my_array, 0, orig_array_len - 1);
	printf("after del_idx(0,%d)=%d, my_array.to_string()=%s\n", (int)(orig_array_len - 1), rc,
	       json_object_to_json_string(my_array));
	json_object_array_add(my_array, json_object_new_string("s1"));
	json_object_array_add(my_array, json_object_new_string("s2"));
	json_object_array_add(my_array, json_object_new_string("s3"));

	printf("after adding more entries, my_array.to_string()=%s\n",
	       json_object_to_json_string(my_array));
	json_object_put(my_array);
}

void test_array_list_expand_internal(void);
void test_array_list_expand_internal()
{
	int rc;
	size_t ii;
	size_t idx;
	json_object *my_array;
#ifdef TEST_FORMATTED
	int sflags = 0;
#endif

	my_array = make_array();
	printf("my_array=\n");
	for (ii = 0; ii < json_object_array_length(my_array); ii++)
	{
		json_object *obj = json_object_array_get_idx(my_array, ii);
		printf("\t[%d]=%s\n", (int)ii, json_object_to_json_string(obj));
	}
	printf("my_array.to_string()=%s\n", json_object_to_json_string(my_array));

	/* Put iNdex < array->size, no expand. */
	rc = json_object_array_put_idx(my_array, 5, json_object_new_int(6));
	printf("put_idx(5,6)=%d\n", rc);

	/* array->size < Put Index < array->size * 2 <= SIZE_T_MAX, the size = array->size * 2. */
	idx = ARRAY_LIST_DEFAULT_SIZE * 2 - 1;
	rc = json_object_array_put_idx(my_array, idx, json_object_new_int(0));
	printf("put_idx(%d,0)=%d\n", (int)(idx), rc);

	/* array->size * 2 < Put Index, the size = Put Index. */
	idx = ARRAY_LIST_DEFAULT_SIZE * 2 * 2 + 1;
	rc = json_object_array_put_idx(my_array, idx, json_object_new_int(0));
	printf("put_idx(%d,0)=%d\n", (int)(idx), rc);

	/* SIZE_T_MAX <= Put Index, it will fail and the size will no change. */
	idx = SIZE_MAX; // SIZE_MAX = SIZE_T_MAX
	json_object *tmp = json_object_new_int(10);
	rc = json_object_array_put_idx(my_array, idx, tmp);
	printf("put_idx(SIZE_T_MAX,0)=%d\n", rc);
	if (rc == -1)
	{
		json_object_put(tmp);
	}

	json_object_put(my_array);
}

int main(int argc, char **argv)
{
	json_object *my_string, *my_int, *my_null, *my_object, *my_array;
	size_t i;
#ifdef TEST_FORMATTED
	int sflags = 0;
#endif

	MC_SET_DEBUG(1);

#ifdef TEST_FORMATTED
	sflags = parse_flags(argc, argv);
#endif

	my_string = json_object_new_string("\t");
	printf("my_string=%s\n", json_object_get_string(my_string));
	printf("my_string.to_string()=%s\n", json_object_to_json_string(my_string));
	json_object_put(my_string);

	my_string = json_object_new_string("\\");
	printf("my_string=%s\n", json_object_get_string(my_string));
	printf("my_string.to_string()=%s\n", json_object_to_json_string(my_string));
	json_object_put(my_string);

	my_string = json_object_new_string("/");
	printf("my_string=%s\n", json_object_get_string(my_string));
	printf("my_string.to_string()=%s\n", json_object_to_json_string(my_string));
	printf("my_string.to_string(NOSLASHESCAPE)=%s\n",
	       json_object_to_json_string_ext(my_string, JSON_C_TO_STRING_NOSLASHESCAPE));
	json_object_put(my_string);

	my_string = json_object_new_string("/foo/bar/baz");
	printf("my_string=%s\n", json_object_get_string(my_string));
	printf("my_string.to_string()=%s\n", json_object_to_json_string(my_string));
	printf("my_string.to_string(NOSLASHESCAPE)=%s\n",
	       json_object_to_json_string_ext(my_string, JSON_C_TO_STRING_NOSLASHESCAPE));
	json_object_put(my_string);

	my_string = json_object_new_string("foo");
	printf("my_string=%s\n", json_object_get_string(my_string));
	printf("my_string.to_string()=%s\n", json_object_to_json_string(my_string));

	my_int = json_object_new_int(9);
	printf("my_int=%d\n", json_object_get_int(my_int));
	printf("my_int.to_string()=%s\n", json_object_to_json_string(my_int));

	my_null = json_object_new_null();
	printf("my_null.to_string()=%s\n", json_object_to_json_string(my_null));

	my_array = json_object_new_array();
	json_object_array_add(my_array, json_object_new_int(1));
	json_object_array_add(my_array, json_object_new_int(2));
	json_object_array_add(my_array, json_object_new_int(3));
	json_object_array_put_idx(my_array, 4, json_object_new_int(5));
	printf("my_array=\n");
	for (i = 0; i < json_object_array_length(my_array); i++)
	{
		json_object *obj = json_object_array_get_idx(my_array, i);
		printf("\t[%d]=%s\n", (int)i, json_object_to_json_string(obj));
	}
	printf("my_array.to_string()=%s\n", json_object_to_json_string(my_array));

	json_object_put(my_array);

	test_array_del_idx();
	test_array_list_expand_internal();

	my_array = json_object_new_array();
	json_object_array_add(my_array, json_object_new_int(3));
	json_object_array_add(my_array, json_object_new_int(1));
	json_object_array_add(my_array, json_object_new_int(2));
	json_object_array_put_idx(my_array, 4, json_object_new_int(0));
	printf("my_array=\n");
	for (i = 0; i < json_object_array_length(my_array); i++)
	{
		json_object *obj = json_object_array_get_idx(my_array, i);
		printf("\t[%d]=%s\n", (int)i, json_object_to_json_string(obj));
	}
	printf("my_array.to_string()=%s\n", json_object_to_json_string(my_array));
	json_object_array_sort(my_array, sort_fn);
	printf("my_array=\n");
	for (i = 0; i < json_object_array_length(my_array); i++)
	{
		json_object *obj = json_object_array_get_idx(my_array, i);
		printf("\t[%d]=%s\n", (int)i, json_object_to_json_string(obj));
	}
	printf("my_array.to_string()=%s\n", json_object_to_json_string(my_array));

	json_object *one = json_object_new_int(1);
	json_object *result = json_object_array_bsearch(one, my_array, sort_fn);
	printf("find json_object(1) in my_array successfully: %s\n",
	       json_object_to_json_string(result));
	json_object_put(one);

	my_object = json_object_new_object();
	int rc = json_object_object_add(my_object, "abc", my_object);
	if (rc != -1)
	{
		printf("ERROR: able to successfully add object to itself!\n");
		fflush(stdout);
	}
	json_object_object_add(my_object, "abc", json_object_new_int(12));
	json_object_object_add(my_object, "foo", json_object_new_string("bar"));
	json_object_object_add(my_object, "bool0", json_object_new_boolean(0));
	json_object_object_add(my_object, "bool1", json_object_new_boolean(1));
	json_object_object_add(my_object, "baz", json_object_new_string("bang"));

	json_object *baz_obj = json_object_new_string("fark");
	json_object_get(baz_obj);
	json_object_object_add(my_object, "baz", baz_obj);
	json_object_object_del(my_object, "baz");

	/* baz_obj should still be valid */
	printf("baz_obj.to_string()=%s\n", json_object_to_json_string(baz_obj));
	json_object_put(baz_obj);

	/*json_object_object_add(my_object, "arr", my_array);*/
	printf("my_object=\n");
	json_object_object_foreach(my_object, key, val)
	{
		printf("\t%s: %s\n", key, json_object_to_json_string(val));
	}
	printf("my_object.to_string()=%s\n", json_object_to_json_string(my_object));

	json_object_put(my_string);
	json_object_put(my_int);
	json_object_put(my_null);
	json_object_put(my_object);
	json_object_put(my_array);

	return EXIT_SUCCESS;
}
