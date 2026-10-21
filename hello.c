/*
 * hello - print a greeting
 *
 * Hello world for 16-bit MS-DOS (Open Watcom C), and a template for
 * other DOS utilities.
 */

#include <stdio.h>
#include <string.h>

#ifndef VERSION
#define VERSION   "unknown"
#endif

static const char *progname = "hello";

static void usage(FILE *fp)
{
    fprintf(fp,
        "Usage: hello [OPTION]...\n"
        "Print a greeting.\n"
        "\n"
        "  -h, --help     display this help and exit\n"
        "      --version  output version information and exit\n");
}

int main(int argc, char **argv)
{
    int i;

    for (i = 1; i < argc; i++) {
        const char *a = argv[i];

        if (strcmp(a, "--help") == 0 || strcmp(a, "-h") == 0 ||
            strcmp(a, "-?") == 0) {
            usage(stdout);
            return 0;
        } else if (strcmp(a, "--version") == 0) {
            printf("hello (dos-hello16) %s\n", VERSION);
            return 0;
        } else if (a[0] == '-') {
            fprintf(stderr, "%s: unrecognized option '%s'\n", progname, a);
            fprintf(stderr, "Try 'hello --help' for more information.\n");
            return 1;
        } else {
            fprintf(stderr, "%s: extra operand '%s'\n", progname, a);
            fprintf(stderr, "Try 'hello --help' for more information.\n");
            return 1;
        }
    }

    printf("Hello, world!\n");
    return 0;
}
