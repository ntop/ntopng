#include "strerror_override.h"
#include "strerror_override_private.h"
#ifdef WIN32
#define WIN32_LEAN_AND_MEAN
#include <io.h>
#include <windows.h>
#endif /* defined(WIN32) */
#include <fcntl.h>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if HAVE_UNISTD_H
#include <unistd.h>
#endif /* HAVE_UNISTD_H */
#include <assert.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "json.h"
#include "json_util.h"
#include "snprintf_compat.h"

static void test_read_valid_with_fd(const char *testdir);
static void test_read_valid_nested_with_fd(const char *testdir);
static void test_read_nonexistant();
static void test_read_closed(void);

static void test_write_to_file();
static void stat_and_cat(const char *file);
static void test_read_fd_equal(const char *testdir);

#ifndef PATH_MAX
#define PATH_MAX 256
#endif

static void test_write_to_file()
{
	json_object *jso;

	jso = json_tokener_parse("{"
	                         "\"foo\":1234,"
	                         "\"foo1\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo2\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo3\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo4\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo5\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo6\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo7\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo8\":\"abcdefghijklmnopqrstuvwxyz\","
	                         "\"foo9\":\"abcdefghijklmnopqrstuvwxyz\""
	                         "}");
	const char *outfile = "json.out";
	int rv = json_object_to_file(outfile, jso);
	printf("%s: json_object_to_file(%s, jso)=%d\n", (rv == 0) ? "OK" : "FAIL", outfile, rv);
	if (rv == 0)
		stat_and_cat(outfile);

	putchar('\n');

	const char *outfile2 = "json2.out";
	rv = json_object_to_file_ext(outfile2, jso, JSON_C_TO_STRING_PRETTY);
	printf("%s: json_object_to_file_ext(%s, jso, JSON_C_TO_STRING_PRETTY)=%d\n",
	       (rv == 0) ? "OK" : "FAIL", outfile2, rv);
	if (rv == 0)
		stat_and_cat(outfile2);

	const char *outfile3 = "json3.out";
	int d = open(outfile3, O_WRONLY | O_CREAT, 0600);
	if (d < 0)
	{
		printf("FAIL: unable to open %s %s\n", outfile3, strerror(errno));
		return;
	}
	rv = json_object_to_fd(d, jso, JSON_C_TO_STRING_PRETTY);
	printf("%s: json_object_to_fd(%s, jso, JSON_C_TO_STRING_PRETTY)=%d\n",
	       (rv == 0) ? "OK" : "FAIL", outfile3, rv);
	// Write the same object twice
	rv = json_object_to_fd(d, jso, JSON_C_TO_STRING_PLAIN);
	printf("%s: json_object_to_fd(%s, jso, JSON_C_TO_STRING_PLAIN)=%d\n",
	       (rv == 0) ? "OK" : "FAIL", outfile3, rv);
	close(d);
	if (rv == 0)
		stat_and_cat(outfile3);

	json_object_put(jso);
}

static void stat_and_cat(const char *file)
{
	struct stat sb;
	int d = open(file, O_RDONLY, 0600);
	if (d < 0)
	{
		printf("FAIL: unable to open %s: %s\n", file, strerror(errno));
		return;
	}
	if (fstat(d, &sb) < 0)
	{
		printf("FAIL: unable to stat %s: %s\n", file, strerror(errno));
		close(d);
		return;
	}
	char *buf = malloc(sb.st_size + 1);
	if (!buf)
	{
		printf("FAIL: unable to allocate memory\n");
		close(d);
		return;
	}
	if (read(d, buf, sb.st_size) < sb.st_size)
	{
		printf("FAIL: unable to read all of %s: %s\n", file, strerror(errno));
		free(buf);
		close(d);
		return;
	}
	buf[sb.st_size] = '\0';
	printf("file[%s], size=%d, contents=%s\n", file, (int)sb.st_size, buf);
	free(buf);
	close(d);
}

int main(int argc, char **argv)
{
	//	json_object_to_file(file, obj);
	//	json_object_to_file_ext(file, obj, flags);

	_json_c_strerror_enable = 1;

	const char *testdir;
	if (argc < 2)
	{
		fprintf(stderr,
		        "Usage: %s <testdir>\n"
		        "  <testdir> is the location of input files\n",
		        argv[0]);
		return EXIT_FAILURE;
	}
	testdir = argv[1];

	//	Test json_c_version.c
	if (strncmp(json_c_version(), JSON_C_VERSION, sizeof(JSON_C_VERSION)))
	{
		printf("FAIL: Output from json_c_version(): %s "
		       "does not match %s",
		       json_c_version(), JSON_C_VERSION);
		return EXIT_FAILURE;
	}
	if (json_c_version_num() != JSON_C_VERSION_NUM)
	{
		printf("FAIL: Output from json_c_version_num(): %d "
		       "does not match %d",
		       json_c_version_num(), JSON_C_VERSION_NUM);
		return EXIT_FAILURE;
	}

	test_read_valid_with_fd(testdir);
	test_read_valid_nested_with_fd(testdir);
	test_read_nonexistant();
	test_read_closed();
	test_write_to_file();
	test_read_fd_equal(testdir);
	return EXIT_SUCCESS;
}

static void test_read_valid_with_fd(const char *testdir)
{
	char filename[PATH_MAX];
	(void)snprintf(filename, sizeof(filename), "%s/valid.json", testdir);

	int d = open(filename, O_RDONLY, 0);
	if (d < 0)
	{
		fprintf(stderr, "FAIL: unable to open %s: %s\n", filename, strerror(errno));
		exit(EXIT_FAILURE);
	}
	json_object *jso = json_object_from_fd(d);
	if (jso != NULL)
	{
		printf("OK: json_object_from_fd(valid.json)=%s\n", json_object_to_json_string(jso));
		json_object_put(jso);
	}
	else
	{
		fprintf(stderr, "FAIL: unable to parse contents of %s: %s\n", filename,
		        json_util_get_last_err());
	}
	close(d);
}

static void test_read_valid_nested_with_fd(const char *testdir)
{
	char filename[PATH_MAX];
	(void)snprintf(filename, sizeof(filename), "%s/valid_nested.json", testdir);

	int d = open(filename, O_RDONLY, 0);
	if (d < 0)
	{
		fprintf(stderr, "FAIL: unable to open %s: %s\n", filename, strerror(errno));
		exit(EXIT_FAILURE);
	}
	assert(NULL == json_object_from_fd_ex(d, -2));
	json_object *jso = json_object_from_fd_ex(d, 20);
	if (jso != NULL)
	{
		printf("OK: json_object_from_fd_ex(valid_nested.json, 20)=%s\n",
		       json_object_to_json_string(jso));
		json_object_put(jso);
	}
	else
	{
		fprintf(stderr, "FAIL: unable to parse contents of %s: %s\n", filename,
		        json_util_get_last_err());
	}

	(void)lseek(d, SEEK_SET, 0);

	jso = json_object_from_fd_ex(d, 3);
	if (jso != NULL)
	{
		printf("FAIL: json_object_from_fd_ex(%s, 3)=%s\n", filename,
		       json_object_to_json_string(jso));
		json_object_put(jso);
	}
	else
	{
		printf("OK: correctly unable to parse contents of valid_nested.json with low max "
		       "depth: %s\n",
		       json_util_get_last_err());
	}
	close(d);
}

static void test_read_nonexistant()
{
	const char *filename = "./not_present.json";

	json_object *jso = json_object_from_file(filename);
	if (jso != NULL)
	{
		printf("FAIL: json_object_from_file(%s) returned %p when NULL expected\n", filename,
		       (void *)jso);
		json_object_put(jso);
	}
	else
	{
		printf("OK: json_object_from_file(%s) correctly returned NULL: %s\n", filename,
		       json_util_get_last_err());
	}
}

static void test_read_closed()
{
	// Test reading from a closed fd
	int d = open("/dev/null", O_RDONLY, 0);
	if (d < 0)
	{
		puts("FAIL: unable to open");
	}
	// Copy over to a fixed fd number so test output is consistent.
	int fixed_d = 10;
	if (dup2(d, fixed_d) < 0)
	{
		printf("FAIL: unable to dup to fd %d", fixed_d);
	}
	close(d);
	close(fixed_d);

	json_object *jso = json_object_from_fd(fixed_d);
	if (jso != NULL)
	{
		printf("FAIL: read from closed fd returning non-NULL: %p\n", (void *)jso);
		fflush(stdout);
		printf("  jso=%s\n", json_object_to_json_string(jso));
		json_object_put(jso);
		return;
	}
	printf("OK: json_object_from_fd(closed_fd), "
	       "expecting NULL, EBADF, got:NULL, %s\n",
	       json_util_get_last_err());
}

static void test_read_fd_equal(const char *testdir)
{
	char filename[PATH_MAX];
	(void)snprintf(filename, sizeof(filename), "%s/valid_nested.json", testdir);

	json_object *jso = json_object_from_file(filename);

	int d = open(filename, O_RDONLY, 0);
	if (d < 0)
	{
		fprintf(stderr, "FAIL: unable to open %s: %s\n", filename, strerror(errno));
		exit(EXIT_FAILURE);
	}
	json_object *new_jso = json_object_from_fd(d);
	close(d);

	printf("OK: json_object_from_file(valid.json)=%s\n", json_object_to_json_string(jso));
	printf("OK: json_object_from_fd(valid.json)=%s\n", json_object_to_json_string(new_jso));
	json_object_put(jso);
	json_object_put(new_jso);
}
