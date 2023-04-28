#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *buf, size_t len);
__attribute__((weak)) extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv);

#ifdef IS_AFL

__AFL_FUZZ_INIT();

int main(int argc, char *argv[]) {
#ifdef __AFL_HAVE_MANUAL_CONTROL
    __AFL_INIT();
#endif

    uint8_t *buf = __AFL_FUZZ_TESTCASE_BUF;

    LLVMFuzzerInitialize(argc, argv);

    while (__AFL_LOOP(10000)) {
        int len = __AFL_FUZZ_TESTCASE_LEN;
        LLVMFuzzerTestOneInput(buf, len);
    }

    return 0;
}

#else

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Error! Must specificy a input file\n");
        return 1;
    }

    FILE *f = fopen(argv[1], "r");
    if (!f) return 1;

    fseek(f, 0, SEEK_END);
    size_t fsize = ftell(f);
    fseek(f, 0, SEEK_SET); /* same as rewind(f); */

    uint8_t *string = (uint8_t *)malloc(fsize + 1);
    fread(string, fsize, 1, f);

    fclose(f);

    LLVMFuzzerInitialize(argc, argv);

    LLVMFuzzerTestOneInput(string, fsize);

    free(string);

    return 0;
}

#endif