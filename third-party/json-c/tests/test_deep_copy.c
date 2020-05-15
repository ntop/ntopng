#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <errno.h>
#include <time.h>

#include "json.h"
#include "printbuf.h"

static void do_benchmark(json_object *src1);

static const char *json_str1 =
    "{"
    "    \"glossary\": {"
    "        \"title\": \"example glossary\","
    "        \"GlossDiv\": {"
    "            \"number\": 16446744073709551615,"
    "            \"title\": \"S\","
    "            \"null_obj\": null, "
    "            \"exixt\": false,"
    "            \"quantity\":20,"
    "            \"univalent\":19.8,"
    "            \"GlossList\": {"
    "                \"GlossEntry\": {"
    "                    \"ID\": \"SGML\","
    "                    \"SortAs\": \"SGML\","
    "                    \"GlossTerm\": \"Standard Generalized Markup Language\","
    "                    \"Acronym\": \"SGML\","
    "                    \"Abbrev\": \"ISO 8879:1986\","
    "                    \"GlossDef\": {"
    "                        \"para\": \"A meta-markup language, used to create markup languages "
    "such as DocBook.\","
    "                        \"GlossSeeAlso\": [\"GML\", \"XML\"]"
    "                    },"
    "                    \"GlossSee\": \"markup\""
    "                }"
    "            }"
    "        }"
    "    }"
    "}";

static const char *json_str2 =
    "{\"menu\": {"
    "    \"header\": \"SVG Viewer\","
    "    \"items\": ["
    "        {\"id\": \"Open\"},"
    "        {\"id\": \"OpenNew\", \"label\": \"Open New\"},"
    "        null,"
    "        {\"id\": \"ZoomIn\", \"label\": \"Zoom In\"},"
    "        {\"id\": \"ZoomOut\", \"label\": \"Zoom Out\"},"
    "        {\"id\": \"OriginalView\", \"label\": \"Original View\"},"
    "        null,"
    "        {\"id\": \"Quality\", \"another_null\": null},"
    "        {\"id\": \"Pause\"},"
    "        {\"id\": \"Mute\"},"
    "        null,"
    "        {\"id\": \"Find\", \"label\": \"Find...\"},"
    "        {\"id\": \"FindAgain\", \"label\": \"Find Again\"},"
    "        {\"id\": \"Copy\"},"
    "        {\"id\": \"CopyAgain\", \"label\": \"Copy Again\"},"
    "        {\"id\": \"CopySVG\", \"label\": \"Copy SVG\"},"
    "        {\"id\": \"ViewSVG\", \"label\": \"View SVG\"},"
    "        {\"id\": \"ViewSource\", \"label\": \"View Source\"},"
    "        {\"id\": \"SaveAs\", \"label\": \"Save As\"},"
    "        null,"
    "        {\"id\": \"Help\"},"
    "        {\"id\": \"About\", \"label\": \"About Adobe CVG Viewer...\"}"
    "    ]"
    "}}";

static const char *json_str3 = "{\"menu\": {"
                               "  \"id\": \"file\","
                               "  \"value\": \"File\","
                               "  \"popup\": {"
                               "    \"menuitem\": ["
                               "      {\"value\": \"New\", \"onclick\": \"CreateNewDoc()\"},"
                               "      {\"value\": \"Open\", \"onclick\": \"OpenDoc()\"},"
                               "      {\"value\": \"Close\", \"onclick\": \"CloseDoc()\"}"
                               "    ]"
                               "  }"
                               "}}";

json_object_to_json_string_fn my_custom_serializer;
int my_custom_serializer(struct json_object *jso, struct printbuf *pb, int level, int flags)
{
	sprintbuf(pb, "OTHER");
	return 0;
}

json_c_shallow_copy_fn my_shallow_copy;
int my_shallow_copy(json_object *src, json_object *parent, const char *key, size_t index,
                    json_object **dst)
{
	int rc;
	rc = json_c_shallow_copy_default(src, parent, key, index, dst);
	if (rc < 0)
		return rc;
	if (key != NULL && strcmp(key, "with_serializer") == 0)
	{
		printf("CALLED: my_shallow_copy on with_serializer object\n");
		void *userdata = json_object_get_userdata(src);
		json_object_set_serializer(*dst, my_custom_serializer, userdata, NULL);
		return 2;
	}
	return rc;
}

int main(int argc, char **argv)
{
	struct json_object *src1, *src2, *src3;
	struct json_object *dst1 = NULL, *dst2 = NULL, *dst3 = NULL;
	int benchmark = 0;

	if (argc > 1 && strcmp(argv[1], "--benchmark") == 0)
	{
		benchmark = 1;
	}

	src1 = json_tokener_parse(json_str1);
	src2 = json_tokener_parse(json_str2);
	src3 = json_tokener_parse(json_str3);

	assert(src1 != NULL);
	assert(src1 != NULL);
	assert(src3 != NULL);

	printf("PASSED - loaded input data\n");

	/* do this 3 times to make sure overwriting it works */
	assert(0 == json_object_deep_copy(src1, &dst1, NULL));
	assert(0 == json_object_deep_copy(src2, &dst2, NULL));
	assert(0 == json_object_deep_copy(src3, &dst3, NULL));

	printf("PASSED - all json_object_deep_copy() returned succesful\n");

	assert(-1 == json_object_deep_copy(src1, &dst1, NULL));
	assert(errno == EINVAL);
	assert(-1 == json_object_deep_copy(src2, &dst2, NULL));
	assert(errno == EINVAL);
	assert(-1 == json_object_deep_copy(src3, &dst3, NULL));
	assert(errno == EINVAL);

	printf("PASSED - all json_object_deep_copy() returned EINVAL for non-null pointer\n");

	assert(1 == json_object_equal(src1, dst1));
	assert(1 == json_object_equal(src2, dst2));
	assert(1 == json_object_equal(src3, dst3));

	printf("PASSED - all json_object_equal() tests returned succesful\n");

	assert(0 == strcmp(json_object_to_json_string_ext(src1, JSON_C_TO_STRING_PRETTY),
	                   json_object_to_json_string_ext(dst1, JSON_C_TO_STRING_PRETTY)));
	assert(0 == strcmp(json_object_to_json_string_ext(src2, JSON_C_TO_STRING_PRETTY),
	                   json_object_to_json_string_ext(dst2, JSON_C_TO_STRING_PRETTY)));
	assert(0 == strcmp(json_object_to_json_string_ext(src3, JSON_C_TO_STRING_PRETTY),
	                   json_object_to_json_string_ext(dst3, JSON_C_TO_STRING_PRETTY)));

	printf("PASSED - comparison of string output\n");

	json_object_get(dst1);
	assert(-1 == json_object_deep_copy(src1, &dst1, NULL));
	assert(errno == EINVAL);
	json_object_put(dst1);

	printf("PASSED - trying to overrwrite an object that has refcount > 1");

	printf("\nPrinting JSON objects for visual inspection\n");
	printf("------------------------------------------------\n");
	printf(" JSON1\n");
	printf("%s\n", json_object_to_json_string_ext(dst1, JSON_C_TO_STRING_PRETTY));
	printf("------------------------------------------------\n");

	printf("------------------------------------------------\n");
	printf(" JSON2\n");
	printf("%s\n", json_object_to_json_string_ext(dst2, JSON_C_TO_STRING_PRETTY));
	printf("------------------------------------------------\n");

	printf("------------------------------------------------\n");
	printf(" JSON3\n");
	printf("------------------------------------------------\n");
	printf("%s\n", json_object_to_json_string_ext(dst3, JSON_C_TO_STRING_PRETTY));
	printf("------------------------------------------------\n");

	json_object_put(dst1);
	json_object_put(dst2);
	json_object_put(dst3);

	printf("\nTesting deep_copy with a custom serializer set\n");
	json_object *with_serializer = json_object_new_string("notemitted");

	char udata[] = "dummy userdata";
	json_object_set_serializer(with_serializer, my_custom_serializer, udata, NULL);
	json_object_object_add(src1, "with_serializer", with_serializer);
	dst1 = NULL;
	/* With a custom serializer in use, a custom shallow_copy function must also be used */
	assert(-1 == json_object_deep_copy(src1, &dst1, NULL));
	assert(0 == json_object_deep_copy(src1, &dst1, my_shallow_copy));

	json_object *dest_with_serializer = json_object_object_get(dst1, "with_serializer");
	assert(dest_with_serializer != NULL);
	char *dst_userdata = json_object_get_userdata(dest_with_serializer);
	assert(strcmp(dst_userdata, "dummy userdata") == 0);

	const char *special_output = json_object_to_json_string(dest_with_serializer);
	assert(strcmp(special_output, "OTHER") == 0);
	printf("\ndeep_copy with custom serializer worked OK.\n");
	json_object_put(dst1);

	if (benchmark)
	{
		do_benchmark(src2);
	}

	json_object_put(src1);
	json_object_put(src2);
	json_object_put(src3);

	return 0;
}

static void do_benchmark(json_object *src2)
{
	json_object *dst2 = NULL;

	int ii;
	/**
	 * The numbers that I got are:
	 * BENCHMARK - 1000000 iterations of 'dst2 = json_tokener_parse(json_object_get_string(src2))' took 71 seconds
	 * BENCHMARK - 1000000 iterations of 'json_object_deep_copy(src2, &dst2, NULL)' took 29 seconds
	 */

	int iterations = 1000000;
	time_t start = time(NULL);

	start = time(NULL);
	for (ii = 0; ii < iterations; ii++)
	{
		dst2 = json_tokener_parse(json_object_get_string(src2));
		json_object_put(dst2);
	}
	printf("BENCHMARK - %d iterations of 'dst2 = "
	       "json_tokener_parse(json_object_get_string(src2))' took %d seconds\n",
	       iterations, (int)(time(NULL) - start));

	start = time(NULL);
	dst2 = NULL;
	for (ii = 0; ii < iterations; ii++)
	{
		json_object_deep_copy(src2, &dst2, NULL);
		json_object_put(dst2);
		dst2 = NULL;
	}
	printf("BENCHMARK - %d iterations of 'json_object_deep_copy(src2, &dst2, NULL)' took %d "
	       "seconds\n",
	       iterations, (int)(time(NULL) - start));
}
