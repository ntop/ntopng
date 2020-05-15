`json-c`
========

1. [Overview and Build Status](#overview)
2. [Building on Unix](#buildunix)
    * [Prerequisites](#installprereq)
    * [Build commands](#buildcmds)
3. [CMake options](#CMake)
4. [Testing](#testing)
5. [Building with `vcpkg`](#buildvcpkg)
6. [Linking to libjson-c](#linking)
7. [Using json-c](#using)

JSON-C - A JSON implementation in C <a name="overview"></a>
-----------------------------------

Build Status
* [AppVeyor Build](https://ci.appveyor.com/project/hawicz/json-c) ![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/json-c/json-c?branch=master&svg=true)
* [Travis Build](https://travis-ci.org/json-c/json-c) ![Travis Build Status](https://travis-ci.org/json-c/json-c.svg?branch=master)

Test Status
* [Coveralls](https://coveralls.io/github/json-c/json-c?branch=master) [![Coverage Status](https://coveralls.io/repos/github/json-c/json-c/badge.svg?branch=master)](https://coveralls.io/github/json-c/json-c?branch=master)

JSON-C implements a reference counting object model that allows you to easily
construct JSON objects in C, output them as JSON formatted strings and parse
JSON formatted strings back into the C representation of JSON objects.
It aims to conform to [RFC 7159](https://tools.ietf.org/html/rfc7159).

Building on Unix with `git`, `gcc` and `cmake` <a name="buildunix"></a>
--------------------------------------------------

Home page for json-c: https://github.com/json-c/json-c/wiki

### Prerequisites: <a name="installprereq"></a>

 - `gcc`, `clang`, or another C compiler

 - cmake>=2.8, >=3.16 recommended

To generate docs you'll also need:
 - `doxygen>=1.8.13`

If you are on a relatively modern system, you'll likely be able to install
the prerequisites using your OS's packaging system.

### Install using apt (e.g. Ubuntu 16.04.2 LTS)
```sh
sudo apt install git
sudo apt install cmake
sudo apt install doxygen  # optional
sudo apt install valgrind # optional
```

### Build instructions:  <a name="buildcmds"></a>

`json-c` GitHub repo: https://github.com/json-c/json-c

```sh
$ git clone https://github.com/json-c/json-c.git
$ mkdir json-c-build
$ cd json-c-build
$ cmake ../json-c   # See CMake section below for custom arguments
```

Note: it's also possible to put your build directory inside the json-c
source directory, or even not use a separate build directory at all, but
certain things might not work quite right (notably, `make distcheck`)

Then:

```sh
$ make
$ make test
$ make USE_VALGRIND=0 test   # optionally skip using valgrind
$ make install
```


### Generating documentation with Doxygen:

The libray documentation can be generated directly from the source codes using Doxygen tool:

```sh
# in build directory
make doc
google-chrome doc/html/index.html
```


CMake Options <a name="CMake"></a>
--------------------

The json-c library is built with [CMake](https://cmake.org/cmake-tutorial/),
which can take a few options.

Variable             | Type   | Description
---------------------|--------|--------------
CMAKE_INSTALL_PREFIX | String | The install location.
CMAKE_BUILD_TYPE     | String | Defaults to "debug"
BUILD_SHARED_LIBS    | Bool   | The default build generates a dynamic (dll/so) library.  Set this to OFF to create a static library only.
BUILD_STATIC_LIBS    | Bool   | The default build generates a static (lib/a) library.  Set this to OFF to create a shared library only.
ENABLE_RDRAND        | Bool   | Enable RDRAND Hardware RNG Hash Seed
ENABLE_THREADING     | Bool   | Enable partial threading support
DISABLE_WERROR       | Bool   | Disable use of -Werror
DISABLE_BSYMBOLIC    | Bool   | Disable use of -Bsymbolic-functions

Pass these options as `-D` on CMake's command-line.

```sh
# build a static library only
cmake -DBUILD_SHARED_LIBS=OFF ..
```

### Building with partial threading support

Although json-c does not support fully multi-threaded access to
object trees, it has some code to help make its use in threaded programs
a bit safer.  Currently, this is limited to using atomic operations for
json_object_get() and json_object_put().

Since this may have a performance impact, of at least 3x slower
according to https://stackoverflow.com/a/11609063, it is disabled by
default.  You may turn it on by adjusting your cmake command with:
   -DENABLE_THREADING=ON

Separately, the default hash function used for object field keys,
lh_char_hash, uses a compare-and-swap operation to ensure the random
seed is only generated once.  Because this is a one-time operation, it
is always compiled in when the compare-and-swap operation is available.


### cmake-configure wrapper script

For those familiar with the old autoconf/autogen.sh/configure method,
there is a `cmake-configure` wrapper script to ease the transition to cmake.

```sh
mkdir build
cd build
../cmake-configure --prefix=/some/install/path
make
```

cmake-configure can take a few options.

| options | Description|
| ---- | ---- |
| prefix=PREFIX |  install architecture-independent files in PREFIX |
| enable-threading |  Enable code to support partly multi-threaded use |
| enable-rdrand | Enable RDRAND Hardware RNG Hash Seed generation on supported x86/x64 platforms. |
| enable-shared  |  build shared libraries [default=yes] |
| enable-static  |  build static libraries [default=yes] |
| disable-Bsymbolic |  Avoid linking with -Bsymbolic-function |
| disable-werror |  Avoid treating compiler warnings as fatal errors |


Testing:  <a name="testing"></a>
----------

By default, if valgrind is available running tests uses it.
That can slow the tests down considerably, so to disable it use:
```sh
export USE_VALGRIND=0
```

To run tests a separate build directory is recommended:
```sh
mkdir build-test
cd build-test
# VALGRIND=1 causes -DVALGRIND=1 to be passed when compiling code
# which uses slightly slower, but valgrind-safe code.
VALGRIND=1 cmake ..
make

make test
# By default, if valgrind is available running tests uses it.
make USE_VALGRIND=0 test   # optionally skip using valgrind
```

If a test fails, check `Testing/Temporary/LastTest.log`,
`tests/testSubDir/${testname}/${testname}.vg.out`, and other similar files.
If there is insufficient output try:
```sh
VERBOSE=1 make test
```
or
```sh
JSONC_TEST_TRACE=1 make test
```
and check the log files again.


Building on Unix and Windows with `vcpkg` <a name="buildvcpkg"></a>
--------------------------------------------------

You can download and install JSON-C using the [vcpkg](https://github.com/Microsoft/vcpkg/) dependency manager:

    git clone https://github.com/Microsoft/vcpkg.git
    cd vcpkg
    ./bootstrap-vcpkg.sh
    ./vcpkg integrate install
    vcpkg install json-c

The JSON-C port in vcpkg is kept up to date by Microsoft team members and community contributors. If the version is out of date, please [create an issue or pull request](https://github.com/Microsoft/vcpkg) on the vcpkg repository.


Linking to `libjson-c` <a name="linking">
----------------------

If your system has `pkgconfig`,
then you can just add this to your `makefile`:

```make
CFLAGS += $(shell pkg-config --cflags json-c)
LDFLAGS += $(shell pkg-config --libs json-c)
```

Without `pkgconfig`, you would do something like this:

```make
JSON_C_DIR=/path/to/json_c/install
CFLAGS += -I$(JSON_C_DIR)/include/json-c
LDFLAGS+= -L$(JSON_C_DIR)/lib -ljson-c
```


Using json-c <a name="using">
------------

To use json-c you can either include json.h, or preferrably, one of the
following more specific header files:

* json_object.h  - Core types and methods.
* json_tokener.h - Methods for parsing and serializing json-c object trees.
* json_pointer.h - JSON Pointer (RFC 6901) implementation for retrieving
                   objects from a json-c object tree.
* json_object_iterator.h - Methods for iterating over single json_object instances.
* json_visit.h   - Methods for walking a tree of json-c objects.
* json_util.h    - Miscelleanous utility functions.

For a full list of headers see [files.html](http://json-c.github.io/json-c/json-c-0.13.1/doc/html/files.html)
