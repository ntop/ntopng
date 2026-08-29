/*
 *
 * (C) 2013-26 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include <unistd.h>

#include "ntop_includes.h"

#ifdef INCLUDE_ONEFILE
#include "onefile.cpp"
#endif

AfterShutdownAction afterShutdownAction = after_shutdown_nop;
NetworkInterface *iface;

constexpr const char *PROG_NAME = "ntopng";
static ndpi_protocol ndpiUnknownProtocol;

bool trace_new_delete = false;

static void cleanup() {
  if (iface) delete iface;
  if (ntop) delete ntop;
}

/**
 * Set the CLI args for prefs.
 *
 * The function must be called like this:
 * setCLIArgs(Prefs *prefs, int params, const char * ...)
 */
static void setCLIArgs(Prefs *prefs, int params...) {
  if (params == 0) return;

  va_list args;
  va_start(args, params);

  // Get path of the binary itself. This is needed to get the absolute path of
  // the required directories
  char exePath[MAX_PATH + 1];
  ssize_t pathLen = readlink("/proc/self/exe", exePath, MAX_PATH);
  if (pathLen != -1) {
    exePath[pathLen] = '\0';
    ssize_t len = pathLen;
    while (len > 0 && exePath[len] != '/') len--;
    if (len == 0) {
      std::cerr << "Error while crafting the command line. Relative path "
	"have been used."
		<< std::endl;
      exit(1);
    }
    exePath[len] = '\0';
    pathLen = len;
  } else {
    std::cerr << "Error while crafting the command line. Failed to "
      "retrieve the absolute path of the executable."
	      << std::endl;
    exit(1);
  }

  // Create the new argv
  char *new_argv[params];
  for (int i = 0; i < params; ++i) {
    const char *opt = va_arg(args, const char *);

    if (!strstr(opt, "_PATH_")) {
      new_argv[i] = strdup(opt);
    } else {
      // size = pathLen + / + opt - _PATH_ + \0
      size_t size = pathLen + 1 + strlen(opt) - 6 + 1;
      new_argv[i] = (char *)malloc(size);
      int len = snprintf(new_argv[i], size, "%s/%s", exePath, opt + 6);
      if (len <= 0) {
	std::cerr << "Error while crafting the command line. Wrong "
	  "buffer size."
		  << std::endl;
	exit(1);
      }
    }
  }

  prefs->loadFromCLI(params, new_argv);

  // Free arguments
  for (int k = 0; k < params; ++k) free(new_argv[k]);

  va_end(args);
}

const ndpi_protocol getConstNdpiUnknownProtocol() {
  return((const ndpi_protocol)ndpiUnknownProtocol);
}

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
  // Final cleanup
  atexit(cleanup);

  Prefs *prefs = NULL;

  if ((ntop = new (std::nothrow) Ntop(PROG_NAME)) == NULL) _exit(1);
  if ((prefs = new (std::nothrow) Prefs(ntop)) == NULL) _exit(1);

  ntop->getTrace()->set_trace_level(0);
  memset((void*)&ndpiUnknownProtocol, 0, sizeof(ndpiUnknownProtocol));

  setCLIArgs(prefs, 11, PROG_NAME, "-1", "_PATH_docs", "-2", "_PATH_scripts",
	     "-3", "_PATH_scripts/callbacks", "-d", "_PATH_data-dir", "-t",
	     "_PATH_install");

  ntop->registerPrefs(prefs, false);

  ntop->loadGeolocation();

  iface = new NetworkInterface("custom");
  iface->allocateStructures();

  return 0;
}

// parseJSONCounter and parseSNMPIntefaces iterate the parsed object without a
// type check, so only hand them a JSON object to avoid a NULL deref.
static bool payload_is_json_object(const char *json) {
  json_object *o = json_tokener_parse(json);
  if (o == NULL) return false;
  bool is_object = (json_object_get_type(o) == json_type_object);
  json_object_put(o);
  return is_object;
}

// Feed each top-level key/value into matchField(), like parseSingleJSONFlow
static void fuzz_match_fields(ZMQParserInterface *zmq_iface, const char *json) {
  json_object *o = json_tokener_parse(json);
  if (o == NULL) return;

  if (json_object_get_type(o) == json_type_object) {
    struct json_object_iterator it = json_object_iter_begin(o);
    struct json_object_iterator itEnd = json_object_iter_end(o);

    while (!json_object_iter_equal(&it, &itEnd)) {
      const char *key = json_object_iter_peek_name(&it);
      json_object *jvalue = json_object_iter_peek_value(&it);

      if (key != NULL && jvalue != NULL) {
	ParsedFlow flow;
	ParsedValue value = {0};

	switch (json_object_get_type(jvalue)) {
	  case json_type_int:
	    value.int_num = json_object_get_int64(jvalue);
	    value.double_num = (double)value.int_num;
	    break;
	  case json_type_double:
	    value.double_num = json_object_get_double(jvalue);
	    break;
	  case json_type_boolean:
	    value.boolean = json_object_get_boolean(jvalue);
	    break;
	  case json_type_string:
	    value.string = json_object_get_string(jvalue);
	    break;
	  default:
	    break;
	}

	zmq_iface->matchField(&flow, key, &value);
      }

      json_object_iter_next(&it);
    }
  }

  json_object_put(o);
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *buf, size_t len) {
  ZMQParserInterface *zmq_iface;

  if (len < 2) return 0;

  // First byte selects the parser entry; the rest is the JSON payload
  uint8_t selector = buf[0];
  size_t payload_len = len - 1;

  char *json = (char *)malloc(payload_len + 1);
  if (json == NULL) return 0;
  memcpy(json, buf + 1, payload_len);
  json[payload_len] = '\0';

  zmq_iface = new ZMQParserInterface("custom");

  switch (selector % 8) {
    case 0:
      zmq_iface->parseEvent(json, (int)payload_len, false, NULL);
      break;
    case 1:
      if (payload_is_json_object(json))
	zmq_iface->parseJSONCounter(json, (int)payload_len);
      break;
    case 2:
      zmq_iface->parseTemplate(json, (int)payload_len, NULL);
      break;
    case 3:
      zmq_iface->parseOption(json, (int)payload_len, NULL);
      break;
    case 4:
      zmq_iface->parseListeningPorts(json, (int)payload_len, NULL);
      break;
    case 5:
      if (payload_is_json_object(json))
	zmq_iface->parseSNMPIntefaces(json, (int)payload_len, NULL);
      break;
    case 6:
      zmq_iface->parseJSONCustomIE(json, (int)payload_len);
      break;
    case 7:
    default:
      fuzz_match_fields(zmq_iface, json);
      break;
  }

  free(json);
  if (zmq_iface) delete zmq_iface;

  return 0;
}

