## Introduction and Prerequisites

ntopng can be built with the support for the LLVM leaks sanitizer (https://clang.llvm.org/docs/LeakSanitizer.html).
On Ubuntu you can install it with 

```
sudo apt-get install -y clang-10  clang-tools-10
```

## Compilation

Then you need to compile ntopng as follows

```
  cd ~/ntopng
  ./autogen.sh && ./configure --with-sanitizer
  make
```

If you want to use nDPI with leak detection support you need to do

```
  cd ~/nDPI
  ./configure --with-sanitizer
  make
```

## Running

In order to enable the leaks sanitizer, it is necessary to set the `ASAN_OPTIONS=detect_leaks=1`
environment variable, for example with:

```
  sudo ASAN_OPTIONS=detect_leaks=1 LSAN_OPTIONS=verbosity=1 ./ntopng -i enp6s0f1 --dont-change-user
```

it is important to use --dont-change-user as otherwise the leak detection will fail with the following error

```
==32547==LeakSanitizer has encountered a fatal error.
==32547==HINT: For debugging, try setting environment variable LSAN_OPTIONS=verbosity=1:log_threads=1
==32547==HINT: LeakSanitizer does not work under ptrace (strace, gdb, etc)
```

## Leak Analysis

In case there are some leaks detected, when killing (nicely) ntopng, a memore leak log (note tht no leaks no log is generated) is produced. The log contains lines as the one below specifying where the memory leak has been encountered:

```
Direct leak of 8 byte(s) in 1 object(s) allocated from:
    #0 0x4a175d in malloc (/home/ntop/ntopng/ntopng+0x4a175d)
    #1 0x7f0b3ef0438b in pcap_create_interface /home/ntop/PF_RING/userland/libpcap/./pcap-linux.c:493
    #2 0x6220000041e3  (<unknown module>)
```


## Notes

The leak detector also identifies invalid memory accesses. The performance impact of running the address sanitizer is about
a 2x slowdown (https://clang.llvm.org/docs/AddressSanitizer.html).

