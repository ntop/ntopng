## Compiling ntopng with Fuzzer

- Install the latest clang (sudo apt-get install clang-10)
- Run autogen.sh
  - CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION" ./configure --enable-fuzztargets-local; make -j12 fuzz_all


## Testing ntopng with ClusterFuzz Artifacts
- Download the artifact (example clusterfuzz-testcase-minimized-fuzz_dissect_packet-5417493917990912)
- Run nDPI against the artifact
  - Example: ./fuzz/fuzz_process_packet clusterfuzz-testcase-minimized-fuzz_dissect_packet-5417493917990912
