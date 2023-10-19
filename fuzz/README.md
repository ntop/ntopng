# Fuzzing targets

The targets are meant to be run by google oss-fuzz however you can test it locally by
configuring all the required flags.

## How to build

In order to build all the targets you need to do the following:
 - Enable the fuzzing targets either with `--enable-fuzztargets` or `--enable--fuzztargets-local`
 - Pass to the C++ preprocessor the flag `FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION`
 - Use the makefile target `fuzz_all`

### Steps

1. Run autoconf with

```shell
./autogen.sh
```

2. Run the configure scripts enabling the fuzzing targets (look at [Flags](#flags) for more details)

```shell
CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION" ./configure --enable-fuzztargets-local
```

3. Build the `fuzz_all` target

```shell
make -j$(nproc) fuzz_all
```

### Flags

These are all the flags that can be passed to the C/C++ compiler:
 - [REQUIRED] **FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION**
 - **IS_AFL**: Used only for local testing when using AFL++. It adds the `main` function that calls
`LLVMFuzzerTestOneInput`. Note that it is not needed when fuzzing on ClusterFuzz.

These are all the env variables that can be passed to the configuration script:
 - **LIB_FUZZING_ENGINE**: the flag used by the fuzzing engine (afl, libfuzzer, ...)

Additionally there are some options that can be passed to `./configure`
 - **--enable-fuzztargets**: Enable all the fuzzing targets. It is used in the ClusterFuzz environment
 - **--enable-fuzztargets-local**: Enable all the fuzzing targets, used for local testing.
	This will define a function `main(int, char **)` making it incompatible with libfuzzer.
	This is useful in conjuction with `-DIS_AFL` for fuzzing with AFL++ or to build in
	debug mode with no fuzzzing engine.
 - **--with-fuzz-protobuf**: Use libprotobuf-mutator. Right now it is compatible only with libfuzzer

Additional sanitizers can be enabled by passing the specific flags in `CFLAGS` and `CXXFLAGS`

## Runtime configuration

Some of the fuzzing targets require a particular directory structure to run correctly.
In order to satisfy all the targets it is strongly suggested to create the following
directories in the same path where the targets are launched:

 - `install`
 - `data-dir`
 - `docs`
 - `scripts`
 - `scripts/callbacks`

# Examples

## Building examples

You can build the fuzzing targets with different combinations of fuzzing engines (libfuzzer,
AFL++, honggfuzz, ...) and sanitizers (address, undefined, memory).
Here you can find some examples on how to build and run some of them.

**Remember** to run all the commands from the project root directory

**IMPORTANT:** If the project has been compiled before, it might be useful to first execute `make clean`

### Building with Libfuzzer

```shell
./autogen.sh

CC=clang CXX=clang++ CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION" \
	CFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=fuzzer-no-link" \
	CXXFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=fuzzer-no-link" \
	LIB_FUZZING_ENGINE="-fsanitize=fuzzer" \
	NDPI_HOME=/path/to/nDPI \
	./configure --enable-fuzztargets

make -j$(nproc) fuzz_all
```

### Building with Libfuzzer + address sanitizer

```shell
./autogen.sh

CC=clang CXX=clang++ CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION" \
	CFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize=fuzzer-no-link" \
	CXXFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize=fuzzer-no-link" \
	LIB_FUZZING_ENGINE="-fsanitize=fuzzer" \
	NDPI_HOME=/path/to/nDPI \
	./configure --enable-fuzztargets

make -j$(nproc) fuzz_all
```

### Building with Libfuzzer + libprotobuf-mutator + address sanitizer

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

### Building with AFL++
```shell
./autogen.sh

CC=afl-clang-fast CXX=afl-clang-fast++ CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DIS_AFL" \
	CFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only" \
	CXXFLAGS="-O1 -fno-omit-frame-pointer -gline-tables-only -stdlib=libc++" \
	NDPI_HOME=/path/to/nDPI \
	./configure --enable-fuzztargets-local

make -j$(nproc) fuzz_all
```

### Debug build with no fuzzer

This is useful to debug a single test case.
**Note** that the code is not instrumented for fuzzing.

```shell
./autogen.sh

CC=clang CXX=clang++ CPPFLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION" \
	CFLAGS="-O0 -fno-omit-frame-pointer -g" \
	CXXFLAGS="-O0 -fno-omit-frame-pointer -g -stdlib=libc++" \
	NDPI_HOME=/path/to/nDPI \
	./configure --enable-fuzztargets-local

make -j$(nproc) fuzz_all
```


## Setting up a fuzzing instance

Once you have built the fuzzing targets you have to properly set up an environment.
Some specific commands might vary depending on the fuzzing engine used in the building process.

First we create a directory in which we place the fuzzing targets, the dictionaries and
the corpus. Then we set up the required directory structure

```shell
mkdir fuzzcampaign

# Copy fuzzers
find fuzz/ -regex 'fuzz/fuzz_[a-z_]*' -exec cp {} fuzzcampaign/ \;

# Copy dictionaries
cp fuzz/*.dict fuzzcampaign/

# Copy corpus
cp fuzz/*.zip fuzzcampaign/

# Create the directory structure needed for fuzzing
mkdir -p fuzzcampaign/install fuzzcampaign/data-dir fuzzcampaign/docs fuzzcampaign/scripts/callbacks
```

Then we can start to fuzz

### For libfuzzer

```shell
cd fuzzcampaign

# Extract the corpus specific for the fuzzing target
mkdir input
unzip fuzz_dissect_packet_seed_corpus.zip -d input/

# Run the fuzzer
./fuzz_dissect_packet -timeout=25 input/ -dict=fuzz_dissect_packet.dict
```

### For AFL++

```shell
cd fuzzcampaign

# Extract the corpus specific for the fuzzing target
mkdir input
unzip fuzz_dissect_packet_seed_corpus.zip -d input/

# Run the fuzzer
afl-fuzz -t 2000 -i input -o afl-out -- ./fuzz_dissect_packet
```