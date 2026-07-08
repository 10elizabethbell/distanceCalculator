/* Compiled C launcher: the .app bundle's executable. Spawns the Swift
 * binary sitting next to it inside Contents/MacOS and exits.
 *
 * This must spawn a child rather than exec(): when LaunchServices starts
 * the bundle and the registered process then exec()s a different image,
 * the NSStatusItem never gets an on-screen window — macOS parks the menu
 * bar icon off-screen. A freshly spawned child registers itself with
 * LaunchServices normally and the icon appears. */
#include <libgen.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <spawn.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

extern char **environ;

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
    pid_t pid;
    int rc = posix_spawn(&pid, target, NULL, NULL, argv, environ);
    if (rc != 0) {
        fprintf(stderr, "launcher: posix_spawn failed (%d)\n", rc);
        return 1;
    }
    return 0;
}
