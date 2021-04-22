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
    char line[1000];
    char name[40];
    long start;
    long end;

    FILE *fp = fopen("/proc/self/maps", "r");

    if (fp == NULL)
        exit(-1);

    while (fgets(line, 1000, fp) != NULL) {
        sscanf(line, "%lx-%lx %*s %*s %*s %*d %s", &start,
                &end, name);
        /*printf ("considering start %lx\n", start);*/
        if (start == 0x400000 || start == 0x601000) {
            /*printf ("changing start %lx of size %lx", start, end-start);*/
            int ret  = mprotect ((void*) start, (size_t) end - start,
                    PROT_WRITE | PROT_READ | PROT_EXEC);
            if (ret  != 0) {
                printf ("ERROR\n");
            }
        }
    }
}

void print_val(int val, int acc_time) {
    FILE *f = fopen("/tmp/victim.output", "w");
    fprintf (f,"sectret based address %x\n", val);
    fclose(f);

}

void no_arg_err() {
    printf ("Error, no parameters or wrong parameters given to program\n");
    exit(-1);
}

void out_of_bound() {
    printf ("The value provided is out of bound\n");
    exit(-1);
}
