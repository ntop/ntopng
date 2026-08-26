/*
 *
 * (C) 2013-23 - ntop.org
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

#ifdef FUZZ_WITH_PROTOBUF
#include <bits/types/struct_timeval.h>
#include <src/libfuzzer/libfuzzer_macro.h>
#include <sys/time.h>

#include "proto/pcap.pb.h"
#endif

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
  std::vector<char *> new_argv(params);
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

  prefs->loadFromCLI(params, new_argv.data());  // = true;

  // Free arguments
  for (int k = 0; k < params; ++k) free(new_argv[k]);

  va_end(args);
}

const ndpi_protocol getConstNdpiUnknownProtocol() {
  return((const ndpi_protocol)ndpiUnknownProtocol);
}

/*
 * Mirrors the post-pcap-read sequence PcapInterface.cpp runs once a pcap file
 * has been fully dissected (see idle_flow_account/flow_end_housekeeping_walker
 * and their use around PcapInterface.cpp:505-530): two full purgeIdle() scans
 * drive every flow through Flow::housekeep(), which is what actually fires the
 * protocol_detected checks, and the final walk runs flow_end_housekeeping()
 * (protocol_detected, if still pending, + flow_end checks) on every flow left
 * in the hash without purging it. Without this, dissectPacket() alone only
 * ever exercises the flow_begin checks.
 */
static bool fuzz_flow_end_housekeeping_walker(GenericHashEntry *h,
                                               void *user_data,
                                               bool *matched) {
  Flow *f = (Flow *)h;
  f->flow_end_housekeeping();
  return false;
}

static void execPendingFlowChecks() {
  u_int32_t begin_slot = 0;

  for (int i = 0; i < 2; i++) iface->purgeIdle(time(NULL), false, true /* full scan */);

  begin_slot = 0;
  iface->get_flows_hash()->walk(&begin_slot, true /* walk_all */,
                                fuzz_flow_end_housekeeping_walker,
                                NULL /* user_data */);
}

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
  // Final cleanup
  atexit(cleanup);

  Prefs *prefs = NULL;

  if ((ntop = new (std::nothrow) Ntop(PROG_NAME)) == NULL) _exit(1);
  if ((prefs = new (std::nothrow) Prefs(ntop)) == NULL) _exit(1);

  ntop->getTrace()->set_trace_level(1);
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

#ifdef FUZZ_WITH_PROTOBUF

template <class Proto>
using PostProcessor =
  protobuf_mutator::libfuzzer::PostProcessorRegistration<Proto>;

DEFINE_PROTO_FUZZER(const ntopng_fuzz::Pcap &message) {
  ntop->getTrace()->traceEvent(TRACE_INFO, "Starting");

  for (const ntopng_fuzz::Record &packet : message.packets()) {
    char pcap_error_buffer[PCAP_ERRBUF_SIZE];
    u_int16_t p;
    Host *srcHost = NULL, *dstHost = NULL;
    Flow *flow = NULL;

    const u_char *pkt =
      reinterpret_cast<const u_char *>(packet.data().data());
    struct pcap_pkthdr *hdr = new pcap_pkthdr();

    hdr->caplen = message.packets().size();
    hdr->len = packet.header().len();
    hdr->ts = {packet.header().timestamp(),
	       packet.header().micronano_timestamp()};

    // printf("caplen %d len %d ts %d sus %d\n", hdr->caplen, hdr->len,
    //        hdr->ts.tv_sec, hdr->ts.tv_usec);

    iface->dissectPacket(UNKNOWN_PKT_IFACE_IDX,
			 DUMMY_BRIDGE_INTERFACE_ID, true, DLT_NULL, NULL, hdr, pkt,
			 &p, &srcHost, &dstHost, &flow);
    // ntop->getTrace()->traceEvent(TRACE_ERROR, "dissecting packet");
  }

  execPendingFlowChecks();

  ntop->getTrace()->traceEvent(TRACE_INFO, "Ending");
}

#else

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *buf, size_t len) {
  if (len == 0) return -1;

  FILE *fd = fmemopen((void *)buf, len, "r");
  if (fd == NULL) {
    std::cerr << "Cannot create the file descriptor with fmemopen"
	      << std::endl;
    return -1;
  }

  char pcap_error_buffer[PCAP_ERRBUF_SIZE];
  pcap_t *pcap_handle;
  const u_char *pkt;
  struct pcap_pkthdr *hdr;
  u_int16_t p;
  Host *srcHost = NULL, *dstHost = NULL;
  Flow *flow = NULL;

  pcap_handle = pcap_fopen_offline(fd, pcap_error_buffer);
  if (pcap_handle == NULL) {
    fclose(fd);
    goto end;
  }
  iface->set_datalink(pcap_datalink(pcap_handle));
  pcap_setnonblock(pcap_handle, 1, pcap_error_buffer);

  while (pcap_next_ex(pcap_handle, &hdr, &pkt) > 0) {
    iface->dissectPacket(UNKNOWN_PKT_IFACE_IDX,
			 DUMMY_BRIDGE_INTERFACE_ID, DLT_NULL, true, NULL, hdr, pkt,
			 &p, &srcHost, &dstHost, &flow);
  }
  execPendingFlowChecks();

  pcap_close(pcap_handle);

 end:
  iface->cleanup();

  return 0;
}

#endif
