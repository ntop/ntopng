#include <assert.h>
#include <stdio.h>

#include "json.h"

int main(int argc, char **argv)
{
	json_object *tmp = json_object_new_int(123);
	json_object_int_inc(tmp, 123);
	assert(json_object_get_int(tmp) == 246);
	json_object_put(tmp);
	printf("INT ADD PASSED\n");
	tmp = json_object_new_int(INT32_MAX);
	json_object_int_inc(tmp, 100);
	assert(json_object_get_int(tmp) == INT32_MAX);
	assert(json_object_get_int64(tmp) == (int64_t)INT32_MAX + 100L);
	json_object_put(tmp);
	printf("INT ADD OVERFLOW PASSED\n");
	tmp = json_object_new_int(INT32_MIN);
	json_object_int_inc(tmp, -100);
	assert(json_object_get_int(tmp) == INT32_MIN);
	assert(json_object_get_int64(tmp) == (int64_t)INT32_MIN - 100L);
	json_object_put(tmp);
	printf("INT ADD UNDERFLOW PASSED\n");
	tmp = json_object_new_int64(321321321);
	json_object_int_inc(tmp, 321321321);
	assert(json_object_get_int(tmp) == 642642642);
	json_object_put(tmp);
	printf("INT64 ADD PASSED\n");
	tmp = json_object_new_int64(INT64_MAX);
	json_object_int_inc(tmp, 100);
	assert(json_object_get_int64(tmp) == INT64_MAX);
	assert(json_object_get_uint64(tmp) == (uint64_t)INT64_MAX + 100U);
	json_object_int_inc(tmp, -100);
	assert(json_object_get_int64(tmp) == INT64_MAX);
	assert(json_object_get_uint64(tmp) == (uint64_t)INT64_MAX);
	json_object_put(tmp);
	printf("INT64 ADD OVERFLOW PASSED\n");
	tmp = json_object_new_int64(INT64_MIN);
	json_object_int_inc(tmp, -100);
	assert(json_object_get_int64(tmp) == INT64_MIN);
	json_object_int_inc(tmp, 100);
	assert(json_object_get_int64(tmp) != INT64_MIN);
	json_object_put(tmp);
	printf("INT64 ADD UNDERFLOW PASSED\n");
	// uint64 + negative int64--> negative int64
	tmp = json_object_new_uint64(400);
	json_object_int_inc(tmp, -200);
	assert(json_object_get_int64(tmp) == 200);
	assert(json_object_get_uint64(tmp) == 200);
	json_object_int_inc(tmp, 200);
	assert(json_object_get_int64(tmp) == 400);
	assert(json_object_get_uint64(tmp) == 400);
	json_object_put(tmp);
	printf("UINT64 ADD PASSED\n");
	tmp = json_object_new_uint64(UINT64_MAX-50);
	json_object_int_inc(tmp, 100);
	assert(json_object_get_int64(tmp) == INT64_MAX);
	assert(json_object_get_uint64(tmp) == UINT64_MAX);
	json_object_put(tmp);
	printf("UINT64 ADD OVERFLOW PASSED\n");
	tmp = json_object_new_uint64(100);
	json_object_int_inc(tmp, -200);
	assert(json_object_get_int64(tmp) == -100);
	assert(json_object_get_uint64(tmp) == 0);
	json_object_put(tmp);
	printf("UINT64 ADD UNDERFLOW PASSED\n");

	printf("PASSED\n");
	return 0;
}
