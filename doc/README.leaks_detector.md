ntopng can be built with the support for the LLVM leaks sanitizer (https://clang.llvm.org/docs/LeakSanitizer.html).

It is advisable to also build nDPI with the leaks sanitizer support.

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
  sudo ASAN_OPTIONS=detect_leaks=1 ./ntopng /etc/ntopng/ntopng.conf
```
