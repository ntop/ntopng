
#include <stdio.h>
#include <string.h>

#include "config.h"

#include "json_inttypes.h"
#include "json_util.h"

void checkit(const char *buf)
{
	int64_t cint64 = -666;

	int retval = json_parse_int64(buf, &cint64);
	printf("buf=%s parseit=%d, value=%" PRId64 " \n", buf, retval, cint64);
}

/**
 * This test calls json_parse_int64 with a variety of different strings.
 * It's purpose is to ensure that the results are consistent across all
 * different environments that it might be executed in.
 *
 * This always exits with a 0 exit value.  The output should be compared
 * against previously saved expected output.
 */
int main()
{
	char buf[100];

	checkit("x");

	checkit("0");
	checkit("-0");

	checkit("00000000");
	checkit("-00000000");

	checkit("1");

	strcpy(buf, "2147483647"); // aka INT32_MAX
	checkit(buf);

	strcpy(buf, "-1");
	checkit(buf);

	strcpy(buf, "   -1");
	checkit(buf);

	strcpy(buf, "00001234");
	checkit(buf);

	strcpy(buf, "0001234x");
	checkit(buf);

	strcpy(buf, "-00001234");
	checkit(buf);

	strcpy(buf, "-00001234x");
	checkit(buf);

	strcpy(buf, "4294967295"); // aka UINT32_MAX

	sprintf(buf, "4294967296");  // aka UINT32_MAX + 1

	strcpy(buf, "21474836470"); // INT32_MAX * 10
	checkit(buf);

	strcpy(buf, "31474836470"); // INT32_MAX * 10 + a bunch
	checkit(buf);

	strcpy(buf, "-2147483647"); // INT32_MIN + 1
	checkit(buf);

	strcpy(buf, "-2147483648"); // INT32_MIN
	checkit(buf);

	strcpy(buf, "-2147483649"); // INT32_MIN - 1
	checkit(buf);

	strcpy(buf, "-21474836480"); // INT32_MIN * 10
	checkit(buf);

	strcpy(buf, "9223372036854775806"); // INT64_MAX - 1
	checkit(buf);

	strcpy(buf, "9223372036854775807"); // INT64_MAX
	checkit(buf);

	strcpy(buf, "9223372036854775808"); // INT64_MAX + 1
	checkit(buf);

	strcpy(buf, "-9223372036854775808"); // INT64_MIN
	checkit(buf);

	strcpy(buf, "-9223372036854775809"); // INT64_MIN - 1
	checkit(buf);

	strcpy(buf, "18446744073709551614"); // UINT64_MAX - 1
	checkit(buf);

	strcpy(buf, "18446744073709551615"); // UINT64_MAX
	checkit(buf);

	strcpy(buf, "18446744073709551616"); // UINT64_MAX + 1
	checkit(buf);

	strcpy(buf, "-18446744073709551616"); // -UINT64_MAX
	checkit(buf);

	// Ensure we can still parse valid numbers after parsing out of range ones.
	strcpy(buf, "123");
	checkit(buf);

	return 0;
}
