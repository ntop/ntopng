#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "json_object.h"
#include "json_object_iterator.h"
#include "json_tokener.h"

int main(int atgc, char **argv)
{
	const char *input = "{\n\
		\"string_of_digits\": \"123\",\n\
		\"regular_number\": 222,\n\
		\"decimal_number\": 99.55,\n\
		\"boolean_true\": true,\n\
		\"boolean_false\": false,\n\
		\"big_number\": 2147483649,\n\
		\"a_null\": null,\n\
		}";

	struct json_object *new_obj;
	struct json_object_iterator it;
	struct json_object_iterator itEnd;

	it = json_object_iter_init_default();
	new_obj = json_tokener_parse(input);
	it = json_object_iter_begin(new_obj);
	itEnd = json_object_iter_end(new_obj);

	while (!json_object_iter_equal(&it, &itEnd))
	{
		printf("%s\n", json_object_iter_peek_name(&it));
		printf("%s\n", json_object_to_json_string(json_object_iter_peek_value(&it)));
		json_object_iter_next(&it);
	}

	json_object_put(new_obj);

	return 0;
}
