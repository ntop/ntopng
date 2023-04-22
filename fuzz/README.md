# Fuzzing targets

The targets are meant to be run by google oss-fuzz however you can test it locally by
configuring all the required flags.

## Flags

These are all the flags that can be passed to the C/C++ compiler:
 - [REQUIRED] **FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION**
 - **IS_AFL**: Used only for local testing when using AFL++. It adds the `main` function that calls
`LLVMFuzzerTestOneInput`. Note that it is not needed when fuzzing on ClusterFuzz.

These are all the env variables that can be passed to the configuration script:
 - **LIB_FUZZING_ENGINE**: the flag used by the fuzzing engine (afl, libfuzzer, ...)

Additionally there are some options that can be passed to `./configure`
 - **--enable-fuzztargets**: Enable all the fuzzing targets. It is used in the ClusterFuzz environment
 - **--enable-fuzztargets-local**: Enable all the fuzzing targets, used for local testing
 - **--with-fuzz-protobuf**: Use libprotobuf-mutator.

Additional sanitizers can be enabled by passing the specific flags in `CFLAGS` and `CXXFLAGS`

## Examples

**Remember** to run all the commands from the project root directory

### Libfuzzer

```shell
./autogen.sh

CC=clang CXX=clang++ CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION" \
	CFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=fuzzer-no-link" \
	CXXFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=fuzzer-no-link" \
	LIB_FUZZING_ENGINE="-fsanitize=fuzzer" \
	NDPI_HOME=/path/to/nDPI \
	./configure --enable-fuzztargets --with-fuzz-protobuf

make -j$(nproc) fuzz_all
```


### Libfuzzer + address sanitizer

```shell
./autogen.sh

CC=clang CXX=clang++ CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION" \
	CFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize=fuzzer-no-link" \
	CXXFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize=fuzzer-no-link" \
	LIB_FUZZING_ENGINE="-fsanitize=fuzzer" \
	NDPI_HOME=/path/to/nDPI \
	./configure --enable-fuzztargets --with-fuzz-protobuf

make -j$(nproc) fuzz_all
```

### AFL++
```shell
./auogen.sh

CC=afl-clang-fast CXX=afl-clang-fast++ CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DIS_AFL" \
	CFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only" \
	CXXFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -stdlib=libc++" \
	NDPI_HOME=/path/to/nDPI \
	./configure --enable-fuzztargets-local

make -j$(nproc) fuzz_all
```