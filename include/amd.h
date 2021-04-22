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

#ifndef AMD_H
#define AMD_H

// AMD MSRs for performance monitoring
#define PerfEvtSel0            0xc0010000      // Event select registers (4 in total - 0xc0010003)
#define PerfCtr0               0xc0010004      // Performance counters (4 in total - 0xc0010007)

// AMD PerfEvtSel register fields
#define PERF_EVENT_SELECT      0x000000ff      // Unit and Event Selection
#define PERF_UNIT_MASK         0x0000ff00      // Event Qualification
#define PERF_USR               0x00010000      // User mode
#define PERF_OS                0x00020000      // Operating-System Mode
#define PERF_E                 0x00040000      // Edge Detect
#define PERF_PC                0x00080000      // Pin Control
#define PERF_INT               0x00100000      // Enable APIC Interrupt
#define PERF_EN                0x00400000      // Enable Counter
#define PERF_INV               0x00800000      // Invert Counter Mask
#define PERF_CNT_MASK          0xff000000      // Counter Mask

void write_to_AMD_PMCi(int fd, uint8_t i, uint64_t val) {
    int rv = 0;

    rv = pwrite(fd, &val, sizeof(val), PerfCtr0+i);

    if (rv != sizeof(val)) {
        fprintf (stderr, "Impossible to write AMD ctr register\n");
        exit(EXIT_FAILURE);
    }
}

void write_to_AMD_PERFEVTSELi(int fd, uint8_t i, uint64_t val) {
    int rv = 0;

    rv = pwrite(fd, &val, sizeof(val), PerfEvtSel0+i);

    if (rv != sizeof(val)) {
        fprintf (stderr, "Impossible to write AMD sel register\n");
        exit(EXIT_FAILURE);
    }
}

uint64_t read_AMD_PMCi(int fd, uint8_t i) {
    int rv = 0;
    uint64_t ret = -1;

    rv = pread(fd, &ret, sizeof(ret), PerfCtr0 + i);

    if (rv != sizeof(ret)) {
        fprintf (stderr, "Impossible to read AMD perf counter\n");
        exit(EXIT_FAILURE);
    }

    return ret;
}

#endif // AMD_H
