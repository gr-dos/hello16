/*
 * hello - print a greeting
 *
 * Hello world for 16-bit MS-DOS (Open Watcom C with libc16), and a
 * template for other DOS utilities.
 */

#include <stdio.h>
#include <string.h>

#ifndef VERSION
#define VERSION   "unknown"
#endif

static const char *progname = "hello";

/* Writes "hello: WHAT 'ARG'" and the --help hint to standard error. */
static void bad_arg(const char *what, const char *arg)
{
    fputs(progname, stderr);
    fputs(": ", stderr);
    fputs(what, stderr);
    fputs(" '", stderr);
    fputs(arg, stderr);
    fputs("'\n", stderr);
    fputs("Try 'hello --help' for more information.\n", stderr);
}

static void usage(FILE *fp)
{
    fputs(
        "Usage: hello [OPTION]...\n"
        "Print a greeting.\n"
        "\n"
        "  -h, --help     display this help and exit\n"
        "      --version  output version information and exit\n", fp);
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
            fputs("hello (dos-hello16) " VERSION "\n", stdout);
            return 0;
        } else if (a[0] == '-') {
            bad_arg("unrecognized option", a);
            return 1;
        } else {
            bad_arg("extra operand", a);
            return 1;
        }
    }

    fputs("Hello, world!\n", stdout);
    return 0;
}
