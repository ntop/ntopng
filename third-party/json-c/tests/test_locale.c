#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "json.h"
#include "json_tokener.h"
#include "snprintf_compat.h"

#ifdef HAVE_LOCALE_H
#include <locale.h>
#endif /* HAVE_LOCALE_H */
#ifdef HAVE_XLOCALE_H
#include <xlocale.h>
#endif

int main(int argc, char **argv)
{
	json_object *new_obj;
#ifdef HAVE_SETLOCALE
	setlocale(LC_NUMERIC, "de_DE");
#else
	printf("No locale\n");
#endif

	char buf1[10], buf2[10];
	// Should result in "0,1", if the locale is installed.
	// Regardless of what it generates, we check that it's
	// consistent below.
	(void)snprintf(buf1, sizeof(buf1), "%f", 0.1);

	MC_SET_DEBUG(1);

	new_obj = json_tokener_parse("[1.2,3.4,123456.78,5.0,2.3e10]");

	(void)snprintf(buf2, sizeof(buf2), "%f", 0.1);
	if (strcmp(buf1, buf2) != 0)
		printf("ERROR: Original locale not restored \"%s\" != \"%s\"", buf1, buf2);

#ifdef HAVE_SETLOCALE
	setlocale(LC_NUMERIC, "C");
#endif

	// Explicitly print each value, to avoid having the "special"
	// serialization done for parsed doubles simply re-emit the original
	// string that was parsed.  (see json_object_new_double_s())
	printf("new_obj.to_string()=[");
	unsigned int ii;
	for (ii = 0; ii < json_object_array_length(new_obj); ii++)
	{
		json_object *val = json_object_array_get_idx(new_obj, ii);
		printf("%s%.2lf", (ii > 0) ? "," : "", json_object_get_double(val));
	}
	printf("]\n");

	printf("new_obj.to_string()=%s\n",
	       json_object_to_json_string_ext(new_obj, JSON_C_TO_STRING_NOZERO));
	json_object_put(new_obj);

	return 0;
}
