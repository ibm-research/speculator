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

#ifndef SPECULATOR_H
#define SPECULATOR_H

#include <libgen.h>
#include <unistd.h>

#include <config.h>

#include <pwd.h>
#include <grp.h>
#include <getopt.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <semaphore.h>
#include <json-c/json.h>
#include <perfmon/pfmlib.h>
#include <perfmon/pfmlib_perf_event.h>

#ifdef INTEL
    #include "intel.h"
#endif //INTEL

#ifdef AMD
    #include "amd.h"
#endif //AMD

/**** SPECULATOR CONSTANTS ****/
#define N_COUNTERS 8
#define DEFAULT_REPEAT 1
#define FILENAME_LENGTH 1000
#define DEFAULT_CONF_NAME "speculator.json"
#define DEFAULT_OUTPUT_NAME "results/speculator_output"
#define TO_STR(x) #x
#define STR(x) TO_STR(x)
#define USAGE_FORMAT "Speculator v"SPECULATOR_VER"\n" \
                     "Usage: %s --victim/-v victim [--attacker/-a attacker] [--config/-c config]\n\t\t" \
                     "[--output/-o output_file] [--repeat/-r repeat] [--venv ENV1=val ENV2=val]\n\t\t"\
                     "[--aenv ENV1=val ENV2=val] [--invert/-i] [--delay/-d delay] [--vpar ARG1 ARG2]\n\t\t" \
                     "[--apar ARG1 ARG2] [--monitor-only] [--serial/-s] [--verbose] [--help/-h]\n" \
                     "Option Details:\n" \
                     "  --victim/-v \t\tspecifies the victim binary\n" \
                     "  --attacker/-a \tspecifies the attacker binary (if any)\n" \
                     "  --config/-c \t\tspecifies the json config file [default: "STR(DEFAULT_CONF_NAME)"]\n" \
                     "  --output/-o \t\tspecifies the output file location [default: "STR(DEFAULT_OUTPUT_NAME)"]\n" \
                     "  --repeat/-r \t\tspecifies the # of tries for the current test [default: "STR(DEFAULT_REPEAT)"]\n" \
                     "  --delay/-d \t\tspecifies the delay in (usec) elapsed between the two threads start in attack/victim mode [default: off]\n" \
                     "  --invert/-i \t\tinverts the order of the threads start [default:attacker thread starts first]\n" \
                     "  --venv \t\tspecifies the environment variable to pass to the victim (if any)\n" \
                     "  --aenv \t\tspecifies the environment variable to pass to the attacker (if any)\n" \
                     "  --vpar \t\tspecifies the parameters to pass to the victim (if any)\n" \
                     "  --apar \t\tspecifies the parameters to pass to the attacker (if any)\n"\
                     "  --serial/-s \t\tserialize the execution of attacker and victim\n" \
                     "  --monitor-only/-m \tenables monitor only mode, speculator does not set/save PMC and does not require root under this mode\n" \
                     "  --verbose \t\tenables verbose mode\n" \
                     "  --help/-h \t\tprints this message\n" \

#define MSR_FORMAT "/dev/cpu/%ld/msr"
#define FATHER_CORE sysconf(_SC_NPROCESSORS_ONLN) - 1

#if DEBUG
#define debug_print(...) do { fprintf(stderr,  __VA_ARGS__); } while(0)
#else
#define debug_print(...) do {} while (0)
#endif

// function pointers for different platforms
void (*write_perf_event_select)(int fd, uint8_t i, uint64_t val);
void (*write_perf_event_counter)(int fd, uint8_t i, uint64_t val);
uint64_t (*read_perf_event_counter)(int fd, uint8_t i);

typedef struct cpuinfo {
    uint32_t eax;
    uint32_t ebx;
    uint32_t edx;
    uint32_t ecx;
} cpuinfo;

void cpuid(uint32_t idx, cpuinfo *info) {
    asm volatile("cpuid"
            : "=a" (info->eax), "=b" (info->ebx),
              "=c" (info->ecx), "=d" (info->edx)
            : "a" (idx));
}

/**** SPECULATOR DATA STRUCTURES ****/
// Main speculator data structure
struct speculator_monitor_data {
    char* desc[N_COUNTERS];
    char* key[N_COUNTERS];
    char* mask[N_COUNTERS];
    char* config_str[N_COUNTERS];
    long long config[N_COUNTERS];
    long long count[N_COUNTERS];
#ifdef INTEL
    long long count_fixed[FIXED_COUNTERS];
#endif // INTEL
    int free;
    long long prev_head;
};

static int hflag = 0;     // FLAG help option
static int vflag = 0;     // FLAG victim path
static int aflag = 0;     // FLAG used to detect victim/attacker mode
static int cflag = 0;     // FLAG config file option
static int oflag = 0;     // FLAG output file option
static int rflag = 0;     // FLAG repeat option
static int iflag = 0;     // FLAG invert start of attack/victim
static int dflag = 0;     // FLAG delay flag
static int sflag = 0;     // FLAG serial execution of attack/victim
static int mflag = 0;     // FLAG monitor-only mode
static int verbflag = 0;  // FLAG verbose mode
static int venvflag = 0;  // FLAG victim env var option
static int aenvflag = 0;  // FLAG attacker env var option
static int vparflag = 0;  // FLAG victim parameters
static int aparflag = 0;  // FLAG attacker parameters

static int delay = 0;
static char *victim_preload[100] = {NULL};
static char *attacker_preload[100] = {NULL};

static char *victim_parameters[100] = {NULL};
static char *attacker_parameters[100] = {NULL};

// Speculator commandline options
static struct option long_options[] = {
    {"help",            no_argument,        NULL, 'h'},
    {"victim",          required_argument,  NULL, 'v'},
    {"attacker",        required_argument,  NULL, 'a'},
    {"config",          required_argument,  NULL, 'c'},
    {"output",          required_argument,  NULL, 'o'},
    {"repeat",          required_argument,  NULL, 'r'},
    {"invert",          no_argument,        NULL, 'i'},
    {"delay",           required_argument,  NULL, 'd'},
    {"serial",          no_argument,        NULL, 's'},
    {"monitor-only",    no_argument,        NULL, 'm'},
    {"venv",            required_argument,  NULL, 0},
    {"aenv",            required_argument,  NULL, 1},
    {"vpar",            required_argument,  NULL, 2},
    {"apar",            required_argument,  NULL, 3},
    {"verbose",         no_argument,        NULL, 4},
    {0, 0, 0, 0}
};


static sem_t *sem_victim = NULL;
static sem_t *sem_attacker = NULL;

static struct speculator_monitor_data
victim_data = {{NULL}, {NULL}, {NULL}, {NULL},
        {0}, {0}, {0}, 0, 0};

static struct speculator_monitor_data
attacker_data = {{NULL}, {NULL}, {NULL}, {NULL},
        {0}, {0}, {0}, 0, 0};

void
update_file_owner(char *filename) {
    uid_t uid;
    gid_t gid;
    char *user_name;
    struct group *grp;
    struct passwd *pwd;

    // Change files iinformation
    user_name = getenv("SUDO_USER");
    if (user_name == NULL) {
        debug_print("Speculator is not running under sudo\n");
        return;
    }
    else {
        pwd = getpwnam(user_name);

        if (pwd == NULL) {
            debug_print("Impossible to get passwd entry\n");
            return;
        }
        uid = pwd->pw_uid;

        grp = getgrnam(user_name);

        if (grp == NULL) {
            debug_print("Impossible to get group entry\n");
            return;
        }

        gid = pwd->pw_gid;

        if (chown(filename, uid, gid) == -1) {
            debug_print("Impossible to change owner of the file\n");
        }
        return;
    }
}

void
recursive_mkdir(char *path) {
    char *tmp_path = NULL;
    char *tmp_dir = NULL;

    tmp_path = strdup(path);
    tmp_dir = dirname(tmp_path);

    if (access(tmp_dir, F_OK) != -1) return;

    recursive_mkdir(tmp_dir);

    if (mkdir (tmp_dir, 0755) == -1) {
        fprintf(stderr, "Error: Impossible to create the new folder at this time.");
        exit(EXIT_FAILURE);
    }

    update_file_owner(tmp_dir);

    return;
}

char *
get_complete_path(char *path, char *filename) {
    char *buffer;
    if (filename[0] == '/' || filename[0] == '.') { // is filename already absolute?
        debug_print("Absolute path detected\n");
        buffer = (char *) malloc (strlen(filename) + 2);
        strcpy(buffer, filename);
        return buffer;
    }
    else {
        if (path == NULL) { //in case a path has to stay relative
            buffer = (char *) malloc(strlen(filename) + 2);
            strcpy(buffer, filename);
            return buffer;
        }
        debug_print("Relative path detected\n");
        buffer = (char *) malloc(strlen(path) + strlen(filename) + 2);
        strcpy(buffer, path);
        strcat(buffer, "/");
        return strcat(buffer, filename);
    }
}

void
decode_events() {
    int ret = 0;
    int event_str_size = 0;
    char *event = NULL;
    pfm_pmu_encode_arg_t arg;
    struct speculator_monitor_data *data;
    // Initialization of pfmlib library
    if (pfm_initialize() != PFM_SUCCESS) {
        fprintf (stderr, "Error during pfm initialization\n");
        exit(EXIT_FAILURE);
    }

    for (int j = 0; j < 2; ++j) {

        if (j == 0) {
            data = &victim_data;
        }
        else if (j == 1) {
            data = &attacker_data;
        }

        for (int i = 0; i < data->free; ++i) {
            memset(&arg, 0, sizeof(arg));
            arg.fstr = &data->config_str[i];
            arg.size = sizeof(pfm_pmu_encode_arg_t);

            event_str_size = strlen(data->key[i]) + 2 + (data->mask[i] == NULL ? 0 : strlen(data->mask[i]));
            event = (char *) malloc(sizeof(char) * event_str_size);
            memset(event, 0, event_str_size);
            event = strcat(event, data->key[i]);

            if (data->mask[i] != NULL && strlen(data->mask[i]) != 0) {
                event = strcat(event, ":");
                event = strcat(event, data->mask[i]);
            }

            ret = pfm_get_os_event_encoding(event, PFM_PLM3, PFM_OS_NONE, &arg);

            if (ret != PFM_SUCCESS) {
                fprintf(stderr, "Cannot get encoding for \"%s\", %s\n", event, pfm_strerror(ret));
                fprintf(stderr, "please verify entry #%d in the json config file\n", i);
                exit(EXIT_FAILURE);
            }

            if (arg.count > 0)
                data->config[i] = arg.codes[0];
            else {
                fprintf(stderr, "No code found for \"%s\", %s\n", event, pfm_strerror(ret));
                exit(EXIT_FAILURE);
            }

            free(event);
        }
    }
}

// Function to parse config file
void
parse_config (char *config_filename) {
    int fd = -1;
    struct stat st;
    size_t name_size = 0;
    size_t desc_size = 0;
    size_t mask_size = 0;
    char *json_str = NULL;
    const char *name_str = NULL;
    const char *desc_str = NULL;
    const char *mask_str = NULL;
    struct json_object *cat_obj = NULL;
    struct json_object *outer_obj = NULL;
    struct json_object *inner_obj = NULL;
    struct speculator_monitor_data *data;

    fd = open(config_filename, O_RDONLY);

    if (fd == -1) {
        fprintf (stderr, "Impossible to  open the configuration file\n");
        exit (EXIT_FAILURE);
    }

    fstat(fd, &st);

    json_str = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);

    cat_obj = json_tokener_parse(json_str);

    if (cat_obj == NULL) {
        fprintf(stderr, "Error parsing json file, verify json format");
        exit(EXIT_FAILURE);
    }

    json_object_object_foreach(cat_obj, key, val) {

        if (strcmp(key, "attacker") == 0) {
            data = &attacker_data;
        }
        else if (strcmp(key, "victim") == 0 ) {
            data = &victim_data;
        }
        else {
            fprintf (stderr, "Unknown key %s, verify json format", key);
            exit(EXIT_FAILURE);
        }

        outer_obj = json_tokener_parse(json_object_get_string(val));

        if (outer_obj == NULL) {
            fprintf (stderr, "Error parsing json file, verify json format");
            exit(EXIT_FAILURE);
        }

        json_object_object_foreach(outer_obj, key, val) {

            inner_obj = json_tokener_parse(json_object_get_string(val));

            if (inner_obj  == NULL) {
                fprintf (stderr, "Error parsing json object related to key %s", key);
                exit(EXIT_FAILURE);
            }

            json_object_object_foreach(inner_obj, key, val) {
                if (strcmp(key, "name") == 0) {
                    name_str = json_object_get_string(val);
                    name_size = strlen(name_str) + 1;
                    data->key[data->free] = (char *) malloc(sizeof(char) * name_size);
                    strncpy(data->key[data->free], name_str, name_size);
                    debug_print("Found event name %s\n", data->key[data->free]);
                }
                else if (strcmp(key, "description") == 0) {
                    desc_str = json_object_get_string(val);
                    desc_size = strlen(desc_str) + 1;
                    data->desc[data->free] = (char *) malloc(sizeof(char) * desc_size);
                    strncpy(data->desc[data->free], desc_str, desc_size);
                    debug_print("Found description \"%s\"\n", data->desc[data->free]);
                }
                else if (strcmp(key, "mask") == 0) {
                    mask_str = json_object_get_string(val);
                    mask_size = strlen(mask_str) + 1;
                    data->mask[data->free] = (char *) malloc(sizeof(char) * mask_size);
                    strncpy(data->mask[data->free], mask_str, mask_size);
                    debug_print("Found mask %s\n", data->mask[data->free]);
                }
            }

            data->free++;
        }
    }
    munmap(json_str, st.st_size);
    close(fd);

    decode_events();

    return;
}

#endif // SPECULATOR_H
