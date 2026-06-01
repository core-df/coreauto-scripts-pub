/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../../../tests/c/testutil.h"
#include "../include/fileclient.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

TEST(test_local_read_write_move)
{
    char src[] = "/tmp/coreauto_fc_XXXXXX";
    char dest_dir[] = "/tmp/coreauto_fc_d_XXXXXX";
    char dest[512];
    int fd = mkstemp(src);
    char *json;

    ASSERT("mkstemp", fd >= 0);
    close(fd);

    json = file_local_write(src, "hello");
    ASSERT("write 200", json_status(json) == 200);
    free(json);

    json = file_local_read(src);
    ASSERT("read 200", json_status(json) == 200);
    free(json);

    ASSERT("dest dir", mkdtemp(dest_dir) != NULL);
    snprintf(dest, sizeof(dest), "%s/moved.txt", dest_dir);
    json = file_local_move(src, dest);
    ASSERT("move 200", json_status(json) == 200);
    free(json);

    unlink(dest);
    rmdir(dest_dir);
}

TEST(test_read_missing)
{
    char *json = file_local_read("/tmp/coreauto_fc_nonexistent_99999.txt");
    ASSERT("missing 500", json_status(json) == 500);
    free(json);
}

int main(void)
{
    RUN(test_local_read_write_move);
    RUN(test_read_missing);
    printf("files tests passed\n");
    return 0;
}
