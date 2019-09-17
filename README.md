# Speculator

Tool to Analyze Speculative Execution Attacks and Mitigations

## QuickStart
Hereafter you can find information on how to build and use
speculator. For more infomation please refer to the [wiki](https://github.com/ibm-research/speculator/wiki).

### Dependencies
Speculator depends on the json-c and the pfmlib libraries (ninja is optional).
To post-process speculator output is necessary to have sqlalchemy installed as well.
Please make sure to have them installed on your system.


```bash
sudo apt-get install libjson-c-dev
sudo apt-get install libpfm4-dev
sudo apt-get install ninja-build
sudo apt-get install python-sqlalchemy
sudo apt-get install cmake
sudo apt-get install nasm
```

Other two hard requirements for speculator to work properly are:

1) The system should be booted without **Secure Boot**

2) The `msr` kernel module should be loaded:

`sudo modprobe msr`


### Build
First of all, create speculator-build and speculator-install folders.
Then update the environment variable in speculator.env and source the file.
```bash
mkdir speculator-build
mkdir speculator-install

# Update the file accordingly
vim speculator.env

source speculator.env
```
Now run cmake to configure in the following way.
```bash
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
```

### Run
```bash
# Run speculator on mytest

ln -s $SPEC_H/templates/x86/template.asm $SPEC_H/tests/mytest.asm
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install

sudo $SPEC_I/speculator_mon -v $SPEC_I/tests/mytest/mytest -c $SPEC_I/speculator.json -o $SPEC_I/results/myoutput

# Repeat experiment 100 times in quite mode with output written to my_output_file
sudo $SPEC_I/speculator_mon -v $SPEC_I/tests/mytest/mytest -o $SPEC_I/results/myoutput -r 100 -q

# Run all the snippet under tests for 1000 each, the results will be saved in $SPEC_I/results/
sudo $SPEC_I/scripts/run_test.py -r 1000 -c $SPEC_I/

# Aggregate results together
$SPEC_I/scripts/post-processing.py -l $SPEC_I/results
```

### New test
```bash
# Manually creating a snippet
cp $SPEC_H/templates/x86/template.asm $SPEC_H/tests/mytest.asm

# Automatically creating a snippet based ona template and a sequence of instructions
$SPEC_H/scripts/cr_inc_snip.py -o $SPEC_H/tests/myfolder $SPEC_H/tests/inst_list.json $SPEC_H/tests/templates/template.asm

# Re-run cmake as above if not automatically detected by ninja
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
```

speculator.json example
```json
{
    "victim": {
        "0": {
            "name" : "LD_BLOCKS",
            "description" : "NONE",
            "mask" : "STORE_FORWARD"
        },

        "1": {
            "name" : "UOPS_EXECUTED",
            "description" : "NONE",
            "mask" : "CORE"
        },

        "2": {
            "name" : "BR_MISP_RETIRED",
            "description" : "NONE",
            "mask" : "ALL_BRANCHES"
        },

        "3": {
            "name" : "UOPS_ISSUED",
            "description" : "NONE",
            "mask" : "SINGLE_MUL"
        }
    },

    "attacker": {
        "0": {
            "name" : "LD_BLOCKS",
            "description" : "NONE",
            "mask" : "STORE_FORWARD"
        },

        "1": {
            "name" : "BR_MISP_RETIRED",
            "description" : "NONE",
            "mask" : "NEAR_TAKEN"
        },

        "2": {
            "name" : "BR_MISP_RETIRED",
            "description" : "NONE",
            "mask" : "ALL_BRANCHES"
        },

        "3": {
            "name" : "BR_MISP_RETIRED",
            "description" : "NONE",
            "mask" : "CONDITIONAL"
        }
    }
}

```

### Project structure

__src/speculator_monitor.c__: Contains the monitor program that receives as parameter the
name of the program to run. In parallel it sets the programmable and fixed counters to monitor the new
process and waits for the snippet to finish.

__include/speculator.h__: Contains definition of important data structures for speculator.
It also contains the DEBUG macro to enable debug prints for development mode.

__speculator.json__: Contains the configuration for speculator. Eeach
record within the json file represents a counter that will be decoded and used
during the execution of the snippet of code.

__confs__: Contains the template config file for each architecture. During the first time cmake runs one
of this is selected and copied into speculator main folder.

doc: Contains the documentation

__scripts/*__: Contains all the scripts useful for running in batch all the tests and
summirize the tests from the results folder.

__tests/*__ : Contains the snippets of code that get executed and should be
monitored. Each test must include a .asm file with the assembly entry point.
It may also include a .c file with the same name in case the assembly code calls into
c-land. New files can be dropped in this folder and they automatically gets included into
the compilation. During installation a folder is created for each one of them.
In case a file is deleted or renamed please re-run cmake.

__examples/__: Contains all the tests written using speculator that can be found in the paper (and eventually more).

### Git flow
This repository follows the [git-flow][git-flow] branching model. Make sure to read and
follow that model. [AVH git extension][git-flow-avh] makes things much easier to handle,
therefore everyone is invited to check them out.

### References
[rdpmc blog entry](https://software.intel.com/en-us/forums/software-tuning-performance-optimization-platform-monitoring/topic/595214)

[Compiler Performance Bible](http://www.agner.org/optimize/)

[Intel Performance Counters List based on models](https://download.01.org/perfmon/index/)

[Performance Counters List for all arch (e.g. PowerPC, ARM, Intel)](http://oprofile.sourceforge.net/docs/)

[Perf Event Guide](http://www.brendangregg.com/perf.html)

[BlackHat talk on PMC](https://www.blackhat.com/docs/us-15/materials/us-15-Herath-These-Are-Not-Your-Grand-Daddys-CPU-Performance-Counters-CPU-Hardware-Performance-Counters-For-Security.pdf)

[Interesting Formulations (check the last slides of the presentation)](https://www.slideshare.net/chris1adkin/sql-sever-engine-batch-mode-and-cpu-architectures)

[Another linux perf tool guide](http://oliveryang.net/2016/07/linux-perf-tools-tips/)

[Interesting talk on BPF and perf](https://kernel-recipes.org/en/2017/talks/performance-analysis-with-bpf/)

[Intel MSR Performance Monitoring Basics](http://www.mindfruit.co.uk/2012/11/intel-msr-performance-monitoring-basics.html)

[msr-tools](https://github.com/01org/msr-tools)

[Kernel msr impl](https://elixir.bootlin.com/linux/v3.16.2/source/arch/x86/kernel/msr.c)

[Blog post on msr problem intel website](https://software.intel.com/pt-br/forums/software-tuning-performance-optimization-platform-monitoring/topic/520430)

[Assembly def rdmsr wrmsr linux kernel](https://elixir.bootlin.com/linux/latest/source/arch/x86/lib/msr-reg.S)

[git-flow]: http://nvie.com/posts/a-successful-git-branching-model/
[git-flow-avh]: https://github.com/petervanderdoes/gitflow/
