// Copyright 2019 IBM Corporation
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

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <libgen.h>

#define __USE_GNU
#include <fcntl.h>
#include <sched.h>
#include <errno.h>
#include <string.h>

#include <sys/wait.h>
#include <sys/mman.h>
#include <sys/poll.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <sys/resource.h>

#include <asm/unistd.h>
#include <linux/perf_event.h>

#include "speculator.h"

void
usage_and_quit(char** argv) {
    fprintf(stderr, USAGE_FORMAT, basename(argv[0]));
    exit(EXIT_FAILURE);
}

void
init_result_file(char *output_filename, int is_attacker) {
    FILE *o_fd = NULL;
    struct speculator_monitor_data *data;

    data = &victim_data;

    if (is_attacker) {
        data = &attacker_data;
    }

    o_fd = fopen(output_filename, "w");

#ifdef INTEL
    for (int i = 0; i < 3; ++i)
        fprintf(o_fd, "%s|", intel_fixed_counters[i]);
#endif // INTEL

    for (int i = 0; i < data->free; ++i)
        fprintf (o_fd, "%s.%s|", data->key[i], data->mask[i]);

    fprintf(o_fd,"\n");
    fclose(o_fd);
}

void
start_process(char *filename,
              int core,
              sem_t *sem,
              char** env,
              char **par) {
    int ret = -1;
    cpu_set_t set;
    struct sched_param param;

    CPU_ZERO(&set);
    CPU_SET(core, &set);
    sched_setaffinity(getpid(), sizeof(cpu_set_t), &set);

    ret = setpriority(PRIO_PROCESS, 0, -20);

    if (ret != 0) {
        fprintf (stderr, "Impossible set priority to child\n");
        exit(EXIT_FAILURE);
    }

    param.sched_priority = 99;
    ret = sched_setscheduler(0, SCHED_RR, &param);

    if (ret != 0) {
        fprintf (stderr, "Impossible set scheduler RR proprity\n");
        exit(EXIT_FAILURE);
    }

    sem_wait(sem);
    sem_post(sem);

    /* HERE TRY TO START  OTHER PROCESS */
    execve(filename, par, env);
}

void
set_counters(int msr_fd, int is_attacker) {
    struct speculator_monitor_data *data;

    data = &victim_data;

    if (is_attacker) {
        data = &attacker_data;
    }

#ifdef INTEL
    // Disable all counters
    write_to_IA32_PERF_GLOBAL_CTRL(msr_fd, 0ull);
    // Initialize Fixed Counters
    write_to_IA32_FIXED_CTR_CTRL(msr_fd, (2ull) | (2ull << 4) | (2ull << 8));
    /* Reset fixed counters */
    for (int i = 0; i < 3; ++i)
        write_to_IA32_FIXED_CTRi(msr_fd, i, 0ull);
#endif // INTEL

    // select counters
    for (int i = 0; i < data->free; ++i)
        write_perf_event_select(msr_fd, i, data->config[i]);

    // reset counters
    for (int i = 0; i < data->free; ++i)
        write_perf_event_counter(msr_fd, i, 0ull);
}

void dump_results(char *output_filename, int msr_fd, int is_attacker) {
    FILE *fp = NULL;
    struct speculator_monitor_data *data;

    data = &victim_data;

    if (is_attacker) {
        data = &attacker_data;
    }

    fp = fopen (output_filename, "a+");

        if (fp == NULL) {
            fprintf(stderr, "Impossible to open the outputfile %s\n", output_filename);
            exit(EXIT_FAILURE);
        }

#ifdef INTEL
        for (int i = 0; i < 3; ++i) {
            data->count_fixed[i] = read_IA32_FIXED_CTRi(msr_fd, i);
            fprintf(fp, "%lld|", data->count_fixed[i]);
        }
#endif // INTEL

        for (int i = 0; i < data->free; ++i) {
            data->count[i] = read_perf_event_counter(msr_fd, i);
            if (verbflag) {
                printf ("######## %s:%s ##########\n", data->key[i], data->mask[i]);
                debug_print ("Counter full: %s\n", data->config_str[i]);
                debug_print ("Counter hex: %llx\n", data->config[i]);
                debug_print ("Desc: %s\n", data->desc[i]);
                printf ("Result: %lld\n", data->count[i]);
                debug_print ("-----------------\n");
            }
            fprintf(fp, "%lld|", data->count[i]);
        }

        fprintf(fp, "\n");

        fclose(fp);
}

void
start_monitor_inline(int victim_pid,
                     int attacker_pid,
                     char* output_filename,
                     char* output_filename_attacker,
                     int msr_fd_victim,
                     int msr_fd_attacker) {
    int status = 0;

    set_counters(msr_fd_victim, 0);
    if (aflag && ATTACKER_CORE != VICTIM_CORE)
        set_counters(msr_fd_attacker, 1);

    if (aflag && !iflag) {
        sem_post(sem_attacker);
        if (dflag) {
            usleep (delay);
        }
        if (sflag) {
            waitpid(attacker_pid, &status, 0);
        }
    }

    sem_post(sem_victim);

    if (sflag) {
        waitpid(victim_pid, &status, 0);
    }

    if (aflag && iflag) {
        if(dflag) {
            usleep(delay);
        }
        sem_post(sem_attacker);
        if (sflag) {
            waitpid(attacker_pid, &status, 0);
        }
    }

    // Waiting for victim to return
    // and dump the counters on the cores
    if (!sflag) {
        waitpid(victim_pid, &status, 0);
    }

    dump_results(output_filename, msr_fd_victim, 0);

    if (aflag) {
        if (!sflag) {
            waitpid(attacker_pid, &status, 0);
        }
        dump_results(output_filename_attacker, msr_fd_attacker, 1);
    }
}

int
main(int argc, char **argv) {
    int opt = 0;
    cpu_set_t set;
    int index = 0;
    int option_index = 0;
    pid_t victim_pid = 0;
    int msr_fd_victim = 0;
    pid_t attacker_pid = 0;
    int msr_fd_attacker = 0;
    int repeat = DEFAULT_REPEAT;
    char *config_filename = NULL;
    char *output_filename = NULL;
    char *msr_path_victim = NULL;
    char *victim_filename = NULL;
    char *msr_path_attacker = NULL;
    char *attacker_filename = NULL;
    char *output_filename_attacker = NULL;


#ifdef INTEL
    debug_print("CPU: Intel detected\n");
    write_perf_event_select = write_to_IA32_PERFEVTSELi;
    write_perf_event_counter = write_to_IA32_PMCi;
    read_perf_event_counter = read_IA32_PMCi;
#endif // INTEL

#ifdef AMD
    debug_print("CPU: AMD detected\n");
    write_perf_event_select = write_to_AMD_PERFEVTSELi;
    write_perf_event_counter = write_to_AMD_PMCi;
    read_perf_event_counter = read_AMD_PMCi;
#endif // AMD

    // Set process to run on the first core to don't interfere on child process
    CPU_ZERO(&set);
    CPU_SET(FATHER_CORE, &set);
    sched_setaffinity(getpid(), sizeof(cpu_set_t), &set);

    /* Reading out params */
    while ((opt = getopt_long(argc, argv, "hv:a:c:o:qr:id:s",
                long_options, &option_index)) != -1) {
        switch (opt) {
            case 'h':
                hflag = 1;
                break;
            case 'v':
                vflag = 1;
                victim_filename = optarg;
                break;
            case 'a':
                aflag = 1;
                attacker_filename = optarg;
                break;
            case 'c':
                cflag = 1;
                config_filename = optarg;
                break;
            case 'r':
                rflag = 1;
                repeat = atoi(optarg);
                break;
            case 'o':
                oflag = 1;
                output_filename = optarg;
                break;
            case 'i':
                iflag = 1;
                break;
            case 's':
                sflag = 1;
                break;
            case 'd':
                if (atoi(optarg) > 0) {
                    dflag = 1;
                    delay = atoi(optarg);
                }
                else {
                    fprintf(stderr, "Delay must be positive\n");
                    usage_and_quit(argv);
                }
                break;
            case 0: // venv
                aenvflag = 1;
                victim_preload[0] = optarg;
                index = 1;
                while (optind < argc && argv[optind][0] != '-') {
                    victim_preload[index] = argv[optind];
                    optind++;
                    index++;
                }
                break;
            case 1: // aenv
                venvflag = 1;
                index = 1;
                attacker_preload[0] = optarg;
                while (optind < argc && argv[optind][0] != '-') {
                    attacker_preload[index] = argv[optind];
                    optind++;
                    index++;
                }
                break;
            case 2: //vpar
                vparflag = 1;
                index = 2;
                victim_parameters[1] = optarg;
                while (optind < argc && argv[optind][0] != '-') {
                    victim_parameters[index] = argv[optind];
                    optind++;
                    index++;
                }
                break;
            case 3: //apar
                aparflag = 2;
                index = 2;
                attacker_parameters[1] = optarg;
                while (optind < argc && argv[optind][0] != '-') {
                    attacker_parameters[index] = argv[optind];
                    optind++;
                    index++;
                }
                break;
            case 4: //verbose
                verbflag = 1;
                break;
            case '?':
                fprintf(stderr, "Unknown option %c\n", optopt);
                usage_and_quit(argv);
                break;
            case ':':
                fprintf(stderr, "Missing option %c\n", optopt);
                break;
            default:
                usage_and_quit(argv);
        }
    }

    if (hflag || !vflag) {
        usage_and_quit(argv);
    }

    victim_parameters[0] = victim_filename;

    if (aflag) {
        attacker_parameters[0] = attacker_filename;
    }

    if (!aflag && iflag) {
        fprintf(stderr, "Invert option can be specified only in attack/victim mode\n");
        usage_and_quit(argv);
    }

    if (!aflag && dflag) {
        fprintf(stderr, "Delay can be specified only in attack/victim mode\n");
        usage_and_quit(argv);
    }

    if(geteuid() != 0) {
        fprintf (stderr, "This program must run as root " \
                         "to be able to open msr device\n");
        exit(EXIT_FAILURE);
    }

    if (access(victim_filename, F_OK) == -1) {
        fprintf(stderr, "Error: victim file %s not found!\n", victim_filename);
        usage_and_quit(argv);
    }

    if (access(victim_filename, X_OK) == -1) {
        fprintf(stderr, "Error: victim file %s not executable!\n", victim_filename);
        usage_and_quit(argv);
    }

    if (!cflag) {
        config_filename = DEFAULT_CONF_NAME;
    }

    if (!oflag) {
        output_filename = DEFAULT_OUTPUT_NAME;
    }

    if (aflag) {
        debug_print("Running in attack/victim mode\n");
    }
    else {
        debug_print("Running in snippet mode\n");
    }

    sem_victim = mmap(NULL, sizeof(sem_t), PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS, -1, 0);
    sem_attacker = mmap(NULL, sizeof(sem_t), PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS, -1, 0);
    sem_init(sem_victim, 1, 1);
    sem_init(sem_attacker, 1, 1);

    parse_config(config_filename);

    recursive_mkdir(output_filename);

    init_result_file(output_filename, 0);

    if (aflag) {
        output_filename_attacker = (char *) malloc(sizeof(char) * FILENAME_LENGTH);
        snprintf (output_filename_attacker, FILENAME_LENGTH+1, "%s.attacker", output_filename);
        init_result_file(output_filename_attacker, 1);
    }

    // Opening cpu msr file for the victim cpu
    msr_path_victim = (char *) malloc(sizeof(char) * (strlen(MSR_FORMAT)+1));
    snprintf (msr_path_victim, strlen(MSR_FORMAT)+1, MSR_FORMAT, VICTIM_CORE);

    debug_print("Opening %s device for victim\n", msr_path_victim);

    // Get fd to MSR register
    msr_fd_victim = open(msr_path_victim, O_RDWR | O_CLOEXEC);

    if (msr_fd_victim < 0) {
        fprintf(stderr, "Impossible to open the %s device\n", msr_path_victim);
        free(msr_path_victim);
        exit(EXIT_FAILURE);
    }

    free(msr_path_victim);

    // Opening cpu msr file for the attacker cpu
    // if running in attacker/victim mode
    if (aflag) {
        msr_path_attacker = (char *) malloc(sizeof(char) * (strlen(MSR_FORMAT)+1));
        snprintf (msr_path_attacker, strlen(MSR_FORMAT)+1, MSR_FORMAT, ATTACKER_CORE);
        debug_print("Opening %s device for attacker\n", msr_path_attacker);

        msr_fd_attacker = open(msr_path_attacker, O_RDWR | O_CLOEXEC);

        if(msr_fd_attacker < 0) {
            fprintf(stderr, "Impossible to open the %s device\n", msr_path_attacker);
            free(msr_path_attacker);
            exit(EXIT_FAILURE);
        }

        free(msr_path_attacker);
    }

    // Repeat X times experiment
    for (int i = 0; i < repeat; ++i) {
#ifdef DUMMY
        int status;
        pid_t tmp_pid;

        tmp_pid = fork();

        if(tmp_pid == 0) {
            debug_print("Starting dummy %s on victim core\n", DUMMY_NAME);
            start_process (DUMMY_NAME, VICTIM_CORE, sem_victim, NULL, NULL);
        }
        else {
            waitpid(tmp_pid, &status, 0);
        }

        if (aflag) {
            tmp_pid = fork();

            if(tmp_pid == 0) {
                debug_print("Starting dummy on attacker core\n");
                start_process (DUMMY_NAME, ATTACKER_CORE, sem_attacker, NULL, NULL);
            }
            else {
                waitpid(tmp_pid, &status, 0);
            }
        }
#endif // DUMMY

        sem_wait(sem_victim);

        if (aflag)
            sem_wait(sem_attacker);

        if (aflag) {
            // STARTING ATTACKER
            attacker_pid = fork();

            if (attacker_pid < 0)
                exit(EXIT_FAILURE);

            if (attacker_pid == 0)
                start_process(attacker_filename, ATTACKER_CORE, sem_attacker, attacker_preload, attacker_parameters);
        }

        // STARTING VICTIM
        victim_pid = fork();

        if (victim_pid < 0)
            exit(EXIT_FAILURE);

        if (victim_pid == 0)
            start_process(victim_filename, VICTIM_CORE, sem_victim,  victim_preload, victim_parameters);

        start_monitor_inline(victim_pid, attacker_pid, output_filename,
                    output_filename_attacker, msr_fd_victim,
                    msr_fd_attacker);
    }

    //clean-up
    for (int i = 0; i < victim_data.free; ++i) {
        free(victim_data.desc[i]);
        free(victim_data.key[i]);
        free(victim_data.mask[i]);
        free(victim_data.config_str[i]);
    }

    for (int i = 0; i < attacker_data.free; ++i) {
        free(attacker_data.desc[i]);
        free(attacker_data.key[i]);
        free(attacker_data.mask[i]);
        free(attacker_data.config_str[i]);
    }

#ifdef INTEL
    // RE-ENABLE ALL COUNTERS
    write_to_IA32_PERF_GLOBAL_CTRL(msr_fd_victim, 15ull | (7ull << 32));
    if (aflag)
        write_to_IA32_PERF_GLOBAL_CTRL(msr_fd_attacker, 15ull | (7ull << 32));
#endif //INTEL

    close(msr_fd_victim);

    if (aflag) {
        close(msr_fd_attacker);
        free(output_filename_attacker);
    }

    sem_destroy(sem_victim);
    sem_destroy(sem_attacker);
    munmap(sem_victim, sizeof(sem_t));
    munmap(sem_attacker, sizeof(sem_t));
}
