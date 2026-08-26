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
SyslogParserInterface *syslog_iface;

constexpr const char *PROG_NAME = "ntopng";
static ndpi_protocol ndpiUnknownProtocol;

bool trace_new_delete = false;

static void cleanup() {
  if (syslog_iface) delete syslog_iface;
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

  /* le (SyslogLuaEngine) is intentionally left NULL: startPacketPolling()
   * (which allocates it) also spins up polling threads we don't want here.
   * parseLog() tolerates a NULL le and simply skips event dispatching,
   * which still exercises all of the header/line parsing logic. */
  syslog_iface = new SyslogParserInterface("custom");

  return 0;
}

/*
 * Fuzzes SyslogParserInterface::parseLog(), i.e. the hand-rolled RFC 3164 /
 * RFC 5424 syslog line parser that runs on lines received from arbitrary
 * network senders (see SyslogCollectorInterface).
 */
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *buf, size_t len) {
  if (len == 0) return 0;

  /* parseLog() mutates the buffer in place (it null-terminates tokens as it
   * splits on them), so it needs a private, writable, NUL-terminated copy. */
  char *log_line = (char *)malloc(len + 1);
  if (log_line == NULL) return 0;
  memcpy(log_line, buf, len);
  log_line[len] = '\0';

  /* In production this is the UDP/TCP source address of the syslog sender,
   * not part of the fuzzed payload itself. */
  char client_ip[] = "127.0.0.1";

  syslog_iface->parseLog(log_line, client_ip);

  free(log_line);

  return 0;
}
