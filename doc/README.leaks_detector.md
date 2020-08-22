ntopng can be built with the support for the LLVM leaks sanitizer (https://clang.llvm.org/docs/LeakSanitizer.html).
On Ubuntu you can install it with 

```
sudo apt-get install -y clang-10  clang-tools-10
```

Then you need to compile ntopng as follows

```
  cd ~/ntopng
  ./configure --with-sanitizer
  make
```

If you want to use nDPI with leak detection support you need to do

```
  cd ~/nDPI
  ./configure --with-sanitizer
  make
```

Note that the detector also identifies invalid memory accesses. The performance impact of running the address sanitizer is about
a 2x slowdown (https://clang.llvm.org/docs/AddressSanitizer.html).

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
