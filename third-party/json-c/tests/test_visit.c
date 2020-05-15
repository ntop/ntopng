#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "json.h"
#include "json_tokener.h"
#include "json_visit.h"

static json_c_visit_userfunc emit_object;
static json_c_visit_userfunc skip_arrays;
static json_c_visit_userfunc pop_and_stop;
static json_c_visit_userfunc err_on_subobj2;
static json_c_visit_userfunc pop_array;
static json_c_visit_userfunc stop_array;
static json_c_visit_userfunc err_return;

int main(void)
{
	MC_SET_DEBUG(1);

	const char *input = "{\
		\"obj1\": 123,\
		\"obj2\": {\
			\"subobj1\": \"aaa\",\
			\"subobj2\": \"bbb\",\
			\"subobj3\": [ \"elem1\", \"elem2\", true ],\
		},\
		\"obj3\": 1.234,\
		\"obj4\": [ true, false, null ]\
	}";

	json_object *jso = json_tokener_parse(input);
	printf("jso.to_string()=%s\n", json_object_to_json_string(jso));

	int rv;
	rv = json_c_visit(jso, 0, emit_object, NULL);
	printf("json_c_visit(emit_object)=%d\n", rv);
	printf("================================\n\n");

	rv = json_c_visit(jso, 0, skip_arrays, NULL);
	printf("json_c_visit(skip_arrays)=%d\n", rv);
	printf("================================\n\n");

	rv = json_c_visit(jso, 0, pop_and_stop, NULL);
	printf("json_c_visit(pop_and_stop)=%d\n", rv);
	printf("================================\n\n");

	rv = json_c_visit(jso, 0, err_on_subobj2, NULL);
	printf("json_c_visit(err_on_subobj2)=%d\n", rv);
	printf("================================\n\n");

	rv = json_c_visit(jso, 0, pop_array, NULL);
	printf("json_c_visit(pop_array)=%d\n", rv);
	printf("================================\n\n");

	rv = json_c_visit(jso, 0, stop_array, NULL);
	printf("json_c_visit(stop_array)=%d\n", rv);
	printf("================================\n\n");

	rv = json_c_visit(jso, 0, err_return, NULL);
	printf("json_c_visit(err_return)=%d\n", rv);
	printf("================================\n\n");

	json_object_put(jso);

	return 0;
}

static int emit_object(json_object *jso, int flags, json_object *parent_jso, const char *jso_key,
                       size_t *jso_index, void *userarg)
{
	printf("flags: 0x%x, key: %s, index: %ld, value: %s\n", flags,
	       (jso_key ? jso_key : "(null)"), (jso_index ? (long)*jso_index : -1L),
	       json_object_to_json_string(jso));
	return JSON_C_VISIT_RETURN_CONTINUE;
}

static int skip_arrays(json_object *jso, int flags, json_object *parent_jso, const char *jso_key,
                       size_t *jso_index, void *userarg)
{
	(void)emit_object(jso, flags, parent_jso, jso_key, jso_index, userarg);
	if (json_object_get_type(jso) == json_type_array)
		return JSON_C_VISIT_RETURN_SKIP;
	return JSON_C_VISIT_RETURN_CONTINUE;
}

static int pop_and_stop(json_object *jso, int flags, json_object *parent_jso, const char *jso_key,
                        size_t *jso_index, void *userarg)
{
	(void)emit_object(jso, flags, parent_jso, jso_key, jso_index, userarg);
	if (jso_key != NULL && strcmp(jso_key, "subobj1") == 0)
	{
		printf("POP after handling subobj1\n");
		return JSON_C_VISIT_RETURN_POP;
	}
	if (jso_key != NULL && strcmp(jso_key, "obj3") == 0)
	{
		printf("STOP after handling obj3\n");
		return JSON_C_VISIT_RETURN_STOP;
	}
	return JSON_C_VISIT_RETURN_CONTINUE;
}

static int err_on_subobj2(json_object *jso, int flags, json_object *parent_jso, const char *jso_key,
                          size_t *jso_index, void *userarg)
{
	(void)emit_object(jso, flags, parent_jso, jso_key, jso_index, userarg);
	if (jso_key != NULL && strcmp(jso_key, "subobj2") == 0)
	{
		printf("ERROR after handling subobj1\n");
		return JSON_C_VISIT_RETURN_ERROR;
	}
	return JSON_C_VISIT_RETURN_CONTINUE;
}

static int pop_array(json_object *jso, int flags, json_object *parent_jso, const char *jso_key,
                     size_t *jso_index, void *userarg)
{
	(void)emit_object(jso, flags, parent_jso, jso_key, jso_index, userarg);
	if (jso_index != NULL && (*jso_index == 0))
	{
		printf("POP after handling array[0]\n");
		return JSON_C_VISIT_RETURN_POP;
	}
	return JSON_C_VISIT_RETURN_CONTINUE;
}

static int stop_array(json_object *jso, int flags, json_object *parent_jso, const char *jso_key,
                      size_t *jso_index, void *userarg)
{
	(void)emit_object(jso, flags, parent_jso, jso_key, jso_index, userarg);
	if (jso_index != NULL && (*jso_index == 0))
	{
		printf("STOP after handling array[1]\n");
		return JSON_C_VISIT_RETURN_STOP;
	}
	return JSON_C_VISIT_RETURN_CONTINUE;
}

static int err_return(json_object *jso, int flags, json_object *parent_jso, const char *jso_key,
                      size_t *jso_index, void *userarg)
{
	printf("flags: 0x%x, key: %s, index: %ld, value: %s\n", flags,
	       (jso_key ? jso_key : "(null)"), (jso_index ? (long)*jso_index : -1L),
	       json_object_to_json_string(jso));
	return 100;
}
