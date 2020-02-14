ntopng can be built with the support for the LLVM leaks sanitizer (https://clang.llvm.org/docs/LeakSanitizer.html).
The detector also identifies invalid memory accesses. The performance impact of running the address sanitizer is about
a 2x slowdown (https://clang.llvm.org/docs/AddressSanitizer.html).

It is advisable to also build nDPI with the leaks sanitizer support to get clean stack traces.

```
  cd ~/nDPI
  ./configure --with-llvm-sanitizer
  make

  cd ~/ntopng
  ./configure --with-llvm-sanitizer
  make
```

In order to enable the leaks sanitizer, it is necessary to set the `ASAN_OPTIONS=detect_leaks=1`
environment variable, for example with:

```
  sudo ASAN_OPTIONS=detect_leaks=1 ./ntopng /etc/ntopng/ntopng.conf 2>sanitizer.log
```

Note: on some old clang implementations it's necessary to manually resolve the symbols with:

```
  # https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/asan/scripts/asan_symbolize.py
  asan_symbolize.py / < sanitizer.log | c++filt
```
