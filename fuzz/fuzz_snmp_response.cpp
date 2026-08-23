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

#ifdef HAVE_LIBSNMP
#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#endif

#ifdef INCLUDE_ONEFILE
#include "onefile.cpp"
#endif

#ifdef HAVE_LIBSNMP

AfterShutdownAction afterShutdownAction = after_shutdown_nop;
NetworkInterface *iface;
SNMP *snmp_obj;

constexpr const char *PROG_NAME = "ntopng";
static ndpi_protocol ndpiUnknownProtocol;

bool trace_new_delete = false;

static void cleanup() {
  if (snmp_obj) delete snmp_obj;
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

  /* SNMP::handle_async_response() is a pure varbind-formatting method: it
   * doesn't touch NetworkInterface/Redis, so no iface is created here. */
  snmp_obj = new SNMP();

  return 0;
}

/*
 * Fuzzes SNMP::handle_async_response() (src/SNMP.cpp), i.e. ntopng's own
 * varbind-to-Lua-table conversion that runs on every SNMP GetResponse
 * received from a polled agent - agents are untrusted/spoofable network
 * peers, and this code does manual buffer math (strncpy/snprintf loops)
 * indexed by attacker-controlled vp->name_length/vp->val_len.
 *
 * Wire bytes are decoded into a real netsnmp_pdu via net-snmp's own
 * snmp_parse() - the same entry point net-snmp's snmp_read()/
 * snmp_sess_read2() call internally after recvfrom() - so only
 * wire-valid, version-matching PDUs ever reach handle_async_response(),
 * matching what a real (if malicious) SNMP agent could actually send.
 */
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 2) return 0;

  /* First byte selects the SNMP version snmp_parse() is told to expect;
   * it rejects messages whose encoded version doesn't match, so this
   * needs to vary for the mutator to explore both community-based
   * (v1/v2c) and USM (v3) framing. */
  long version;
  switch (data[0] % 3) {
    case 0: version = SNMP_VERSION_1; break;
    case 1: version = SNMP_VERSION_2c; break;
    default: version = SNMP_VERSION_3; break;
  }

  netsnmp_session session;
  snmp_sess_init(&session);
  session.version = version;

  netsnmp_pdu *pdu = snmp_pdu_create(0);
  if (pdu == NULL) return 0;

  int rc = snmp_parse(NULL /* sessp */, &session, pdu,
                      (u_char *)(data + 1), size - 1);

  if (rc == 0) snmp_obj->handle_async_response(pdu, "203.0.113.1" /* TEST-NET-3 */);

  snmp_free_pdu(pdu);

  return 0;
}

#else /* !HAVE_LIBSNMP */

/*
 * This target only has something to fuzz when ntopng is built against
 * net-snmp (the standard build: HAVE_LIBSNMP is auto-detected whenever
 * libsnmp-dev/net-snmp is present, no opt-in flag required - see
 * configure.ac). Without it, SNMP::handle_async_response() doesn't even
 * exist, so there's nothing to call; keep the binary a harmless no-op
 * rather than failing the build.
 */
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  return 0;
}

#endif /* HAVE_LIBSNMP */
