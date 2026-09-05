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

constexpr const char *PROG_NAME = "ntopng";
static ndpi_protocol ndpiUnknownProtocol;

bool trace_new_delete = false;

static void cleanup() {
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

  /* _dissectMDNS() reports what it decodes through ntop->getTrace(), so ntop
   * must exist before the first input is handed over. */

  return 0;
}

/* Same declaration NetworkInterface.cpp uses to reach the decoder
 * (src/NetworkDiscovery.cpp). */
extern void _dissectMDNS(u_char *buf, u_int buf_len, char *out, u_int out_len);

/*
 * Fuzzes _dissectMDNS(), the hand-rolled mDNS record walker that runs on
 * multicast DNS payloads received from any host on the local segment.
 */
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  char out[1024];

  if (size == 0 || size > 65535) return 0;

  /* _dissectMDNS() takes a non-const buffer, and a heap copy sized exactly to
   * the input gives the sanitizer a tight bound on the record walk. */
  u_char *buf = (u_char *)malloc(size);
  if (buf == NULL) return 0;
  memcpy(buf, data, size);

  _dissectMDNS(buf, (u_int)size, out, sizeof(out));

  free(buf);

  return 0;
}
