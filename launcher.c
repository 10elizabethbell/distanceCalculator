/* Compiled C launcher: the .app bundle's executable. Finds the Swift
 * binary sitting next to it inside Contents/MacOS and exec()s it. */
#include <libgen.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    char path[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0) {
        fprintf(stderr, "launcher: executable path too long\n");
        return 1;
    }

    char resolved[PATH_MAX];
    if (realpath(path, resolved) == NULL) {
        perror("launcher: realpath");
        return 1;
    }

    char target[PATH_MAX];
    snprintf(target, sizeof(target), "%s/distancecalc", dirname(resolved));

    argv[0] = target;
    execv(target, argv);
    perror("launcher: execv");
    return 1;
}
