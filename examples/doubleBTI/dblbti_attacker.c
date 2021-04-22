// Copyright 2021 IBM Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <stdio.h>
#include <stdlib.h>

#include <sys/mman.h>

void set_write_code() {
    long end;
    long start;
    char line[10000];
    char name[10000];
    char dummy[10000];
    long x;

    FILE *fp = fopen("/proc/self/maps", "r");

    if (fp == NULL)
        exit(-1);

    while (fgets(line, 1000, fp) != NULL) {
        sscanf(line, "%lx-%lx %*s %*s %*s %*s %s", &start, &end, name);

        if (start == 0x400000 || start == 0x601000) {
            printf ("changing start %lx of size %lx", start, end-start);
            int ret  = mprotect ((void*) start, (size_t) end - start,
                    PROT_WRITE | PROT_READ | PROT_EXEC);
            if (ret  != 0) {
                printf ("ERROR\n");
            }
        }
    }
}

#define SIZE 256
void print_val(int* val) {
    FILE *f = fopen("/tmp/attacker.output", "a");
    int i;
    for (i = 0; i < SIZE; ++i) {
        fprintf (f, "%d) %d\n", i, *val);
        val++;
    }
    fprintf (f, "\n");
    fclose(f);
}
