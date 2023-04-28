#ifdef FUZZ_WITH_PROTOBUF
#include <bits/types/struct_timeval.h>
#include <src/libfuzzer/libfuzzer_macro.h>
#include <sys/time.h>

#include "proto/pcap.pb.h"
#endif

#include "ntop_includes.h"

#ifdef INCLUDE_ONEFILE
#include "onefile.cpp"
#endif

AfterShutdownAction afterShutdownAction = after_shutdown_nop;
NetworkInterface *iface;

constexpr const char *PROG_NAME = "ntopng\0";

extern "C" int LLVMFuzzerInitialize(int argc, char **argv) {
    Prefs *prefs = NULL;

    if ((ntop = new (std::nothrow) Ntop(PROG_NAME)) == NULL) _exit(1);
    if ((prefs = new (std::nothrow) Prefs(ntop)) == NULL) _exit(1);

    ntop->getTrace()->set_trace_level(1);

    int c = 9;
    char *new_argv[c];
    // Args are in reversed order
    new_argv[--c] = new char[]{"./install\0"};
    new_argv[--c] = new char[]{"-t\0"};
    new_argv[--c] = new char[]{"data-dir\0"};
    new_argv[--c] = new char[]{"-d\0"};
    new_argv[--c] = new char[]{"scripts\0"};
    new_argv[--c] = new char[]{"-2\0"};
    new_argv[--c] = new char[]{"docs\0"};
    new_argv[--c] = new char[]{"-1\0"};
    new_argv[--c] = (char *)PROG_NAME;
    assert(c == 0);

    prefs->loadFromCLI(10, new_argv);  // = true;
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

        iface->dissectPacket(DUMMY_BRIDGE_INTERFACE_ID, true, NULL, hdr, pkt,
                             &p, &srcHost, &dstHost, &flow);
        // ntop->getTrace()->traceEvent(TRACE_ERROR, "dissecting packet");
    }
    ntop->getTrace()->traceEvent(TRACE_INFO, "Ending");
}

#else

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *buf, size_t len) {
    if (len == 0) return -1;

    FILE *fd = fmemopen((void *)buf, len, "r");
    if (fd == NULL) {
        std::cerr << "Cannot create the file descriptor with fmemopen" << std::endl;
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
    if (pcap_handle == NULL) goto end;
    pcap_setnonblock(pcap_handle, 1, pcap_error_buffer);

    while (pcap_next_ex(pcap_handle, &hdr, &pkt) > 0) {
        iface->dissectPacket(DUMMY_BRIDGE_INTERFACE_ID, true, NULL, hdr, pkt,
                             &p, &srcHost, &dstHost, &flow);
    }

end:
    fclose(fd);
    iface->cleanup();

    return 0;
}

#endif
