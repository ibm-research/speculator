# Artifact Evaluation Instructions

In this document there are the instruction to run the experiments for Speculator
with indications on how interpret the results. For most of this tests we suggest
to disable Hyperthreading since they are single threaded tests. This will
prevent noise of other programs running on the system to interfere.

NOTE: This guide requires to have the proper environment variable set (e.g. SPEC_H, SPEC_B, SPEC_I).
      Also, it is important that the machine is booted without SECURE BOOT because that makes the msr module unusable because not properly signed.
      Last, `speculator_mon` requires root privileges and should be run under `root`.

## Paper Authors
Andrea Mambretti            mbr@ccs.neu.edu (Preferred Contact)
Matthias Neugschwandtner    mneug@iseclab.org
Alessandro Sorniotti        aso@zurich.ibm.com
Engin Kirda                 ek@ccs.neu.edu
William Robertson           wkr@ccs.neu.edu
Anil Kurmus                 kur@zurich.ibm.com

## Requirements
see README.md for installation instructions.

### Cleanup
This step must be run every time we switch between two series of tests.
First we need to clean our local test folder running:
```
rm -rf $SPEC_H/tests/*.asm $SPEC_H/tests/*.c
```
or
```
rm -rf $SPEC_H/tests/myfolder
```
Then we need to clean the install directory
```
rm -rf $SPEC_I/*
```

## Experiments Instructions
### Return Stack Buffer (4.1 in the paper)
In this test we tried to empirically measure the RSB size.
The files for this test are located at `$SPEC_H/examples/rsb`.

First we need to add the incremental tests under `$SPEC_H/tests` with:
```
$SPEC_H/scripts/cr_inc_snip.py --output $SPEC_H/tests/rsb_deep_stack $SPEC_H/examples/rsb/rsb_fill_deep_stack.json $SPEC_H/examples/rsb/rsb_fill_deep_stack.asm
```

Then configure (only necessary when new tests are added to the test folder to generated the new compilation targets):
```
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
```
Finally compile with:
```
ninja -C $SPEC_B install
```

To run the tests all together we rely on the scrip `run_test.py` which scan the install directory for test to run (as root).
```
# run 1000 times each test found under $SPEC_I. -c cleans up the $SPEC_I/results folder before from previous results.
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
```

To aggregate the 1000 runs for each test found run:
```
sudo scripts/post-processing.py -l $SPEC_I/results
```
The full ordered aggregated report is at `$SPEC_I/results/final_results.txt`

In this case we were interested in the marker execution only so simply running:
```
cat $SPEC_I/results/final_results.txt | grep LD_BLOCKS
```
gives us the marker results of each test. The line 1 is the test with 1 nested call, line 2 is 2 nested call and so on.
The results should show a transition from ~=1 to 0 after a certain incremental snippet.
At that location we will have 1 call to victim, 1 call to filler and N nested call.
If we sum all those together we would get the length of the RSB for the specific machine we are running the test on.
On my Kaby Lake (as shown in the paper) the transition happens between 14 and 15 so the RSB is 1 + 1 + 14 = 16 entries.
Based on the machine this is run on, the result might be different and therefore this should be verified with the specification of the machine.
Overall the specification for the machine and the computed number should match.

### Nesting Speculative Execution (4.2 in the paper)
In this test we tried to verify the behavior of speculative execution during nested speculation.
First it is necessary to run the clean-up step described above.
Then we move the test (that can be found in `$SPEC_H/examples/speculation_in_speculation`) under `$SPEC_H/tests`.
In this case since we do not work on incremental snippet we can create a symlink or copy the file.

First, it would be required to edit `speculator.json` inside `$SPEC_H` to make sure `UOPS_ISSUED.SLOW_LEA`

```
ln -s $SPEC_H/examples/speculation_in_speculation/speculation_in_speculation_in_speculation.asm $SPEC_H/tests
```
Then configure and compile:
```
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
```
Run with:
```
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 100 -c
```
Aggregate the results with:
```
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
In this case we were interested in the `UOPS_ISSUED.SLOW_LEA` counter (or `UOPS_ISSUED.MULPS` if Broadwell or older families).
```
cat $SPEC_I/results/final_results.txt | grep SLOW
```
The results should be around 10 instructions unless the outer conditions resolve faster.
If one of the marker in the outer ifs is removed the counting goes down of 2 or more at the time, signalling that that counter was crossed multiple times due to the try and fail the CPU does.


### Speculative Execution Across System Calls (4.3 in the paper)
In this section we explored the behavior of the CPU speculative execution when a syscall is encountered.
First it is necessary to run the clean-up step described above.

(NOTE: if you are not running with HT disabled, make sure to modify `$SPEC_H/speculator.json` to record for `victim` UOPS_EXECUTED.THREAD instead of CORE)

Then we generate the incremental tests using the template and json in `$SPEC_H/examples/syscall_speculation`.

In the first part of this experiment we try to verify that userspace instructions are not further executed speculative after a syscall.
To do so we generate a series of tests where a series of movs are added after a getppid syscall.

If speculative execution would proceed after syscall we would observe an incresing number of uops executed.
Run:
```
$SPEC_H/scripts/cr_inc_snip.py --output $SPEC_H/tests/syscall_speculation $SPEC_H/examples/syscall_speculation/syscall_speculation.json $SPEC_H/examples/syscall_speculation/syscall_speculation.asm
```
to generate the series of tests.

Then the usual:
```
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
```
to configure, compile and run.
Finally run the post-processing pass with:
```
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
In case HT is on and you are monitoring UOPS_EXECUTED.THREAD instead of CORE add -t to the post-processing script.
With:
```
cat $SPEC_I/results/final_results.txt | grep UOPS_EXECUTED
```
we should be able to notice that the amount of uops executed does not change no matter how many instructions we inject after the syscall.
This is the first indicator that the syscall might act as speculation stopper.
Though, it is necessary to verify that this is not simply a side effect of the fact the syscall is too long and speculative execution ends before returning to userspace.
To explore this alternative we need to add to our tests a baseline program that is exactly the same as the template used to generate the incremental tests but it does not perform the syscall.
```
ln -s $SPEC_H/examples/syscall_speculation/syscall_speculation_baseline.asm $SPEC_H/tests
```
Now, we want to explore the amount of instructions executed in kernel space from the CPU in our incremental tests and in the baseline without the syscall.
If this number does not change mean that the transition to ring 0 is never performed during speculative execution.

To allow speculator to record ring 0 only events we need to change the file in `$SPEC_H/include/speculator.h` at line 206.
It is necessary to change the `pfm_get_os_event_encoding` call from PFM_PLM3 to PFM_PLM0.
Then:
```
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results   // add -t in case of UOPS_EXECUTED.THREAD counter used instead of CORE
```
Finally with:
```
cat $SPEC_I/results/final_results.txt | grep UOPS_EXECUTED
```
you will notice that the baseline (should be last in the list, check the output of post-processing) has the same results of the others.
This implies that also in the other tests the syscall is actually never performed speculatively.

NOTE: Please remember now to change back $SPEC_H/include/speculator.h to PFM_PLM3 to monitor ring 3 for the remaining experiments.

### Flushing the Cache (4.4 in the paper)
In this experiment, we wanted to monitor the behavior of the clflush instruction within speculative execution.
The file for this experiments are under `$SPEC_H/examples/clflush_in_speculation/`
In this experiment we have two tests that differ for only one instruction.
In both tests we start flushing a variable of interest.
In one of the tests we then reload this variable into memory and then we go and execute in both tests speculatively a clflush operation on such variable.
Finally we measure the execution time of accessing this variable.
If the speculated clflush would actually work we would see that both access would be similar and > 200 cycles (uncached access).
First we need to run the clean-up phase as above.
Then move the files under the tests folder:
```
ln -s $SPEC_H/examples/clflush_in_speculation/clflush_in_speculation_cached.asm $SPEC_H/tests/
ln -s $SPEC_H/examples/clflush_in_speculation/clflush_in_speculation_uncached.asm $SPEC_H/tests/
```
With:
```
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
configure, compile, run and aggregate the results.
if we observe the CYCLES field for both tests inside the final report at `$SPEC_I/results/final_results.txt`
The cached tests executed faster than the uncached one. This indicate that in the cached test the speculated clflush did not affect the cache.


### Speculation Window Size (4.5 in the paper)

In this series of tests, we measured the speculative execution window size under type of triggers (e.g. Condition Branches, Indirect Branches etc.) in combinations of various situations
(e.g. cached, uncached, register, etc.).

#### Conditional Branches
The files related to this tests are under `$SPEC_I/examples/v1_various_cond_cycles`
As before, first is good to run the cleanup pass described above.
Then we can link the files inside the test folder with:

```
ln -s $SPEC_H/examples/v1_various_cond_cycles/\*.asm $SPEC_H/tests
```

For each one of the conditions we have two tests. The first test, prefixed with `v1_cond`, is the one that will trigger speculative execution.
Meanwhile, the second one, prefixed with `v1_nocond`, is our baseline that has no condition.
Each pair of tests will allow us to remove the cycles that are due to our template from the test that instead is speculative executioning based on a condition.
This delta is practically the speculation window that each type of condition offer.
As for each other case we then need to run:

```
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
Now if we look into the final report and for each cond/nocond pair we take the cycles number and compute `cond_cycles - nocond_cycles`, we should get similar results than the one in the paper.

#### Indirect Branches

The files related to this tests are under `$SPEC_I/examples/v2_various_uncond_cycles`

```
ln -s $SPEC_H/examples/v2_various_uncond_cycles/\*.asm $SPEC_H/tests
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
Here the results are given from the cycles inside the final report at `SPEC_I/results/final_results.txt`


#### Store to Load Forwarding

The files related to this tests are under `$SPEC_I/examples/v4_cycles/`

Here we need to generate a series of tests based on `v4_cycles.asm`. This tests monitors UOPS_EXECUTE.THREAD or CORE and UOPS_RETIRED, please make sure both are in the victim portion of `$SPEC_H/speculator.json`.

To generate the tests run, configure, compile, run and aggregate:
```
$SPEC_H/scripts/cr_inc_snip.py --output $SPEC_H/tests/v4_cycles $SPEC_H/examples/v4_cycles/v4_cycles.json $SPEC_H/examples/v4_cycles/v4_cycles.asm
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
In the report if we observe the delta between UOPS_EXECUTED and UOPS_RETIRED tend to grow and then stabilize. This is the maximum window offered from a Store to Load forward speculation.
Overall the window is rather small as reported in the paper.


### Speculation Stopper (4.6 in the paper)

The files for this tests are under `$SPEC_I/examples/speculation_stopper`
This template contains an lfence at the beginning of the speculative sequence.
The injected instructions (FNOPs) from the json template are located immediately after it.
Normally we would expect an increase of number of UOPS_EXECUTED for each incremental snippet unless lfence works as speculative execution stopper.

After the cleanup described above, run the following commands as in the previous tests:
```
$SPEC_H/scripts/cr_inc_snip.py --output $SPEC_H/tests/speculation_stopper $SPEC_H/examples/speculation_stopper/speculation_stopper.json $SPEC_H/examples/speculation_stopper/speculation_stopper.asm
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
Inside the report at `$SPEC_I/results/final_results.txt` it should be possible to notice that the number of `UOPS_EXECUTED` is stable and therefore we can infer that `lfence` blocks speculation.

### Execution Page Only (4.7 in the paper)
In this test we try to see if speculative execution bypass the nx bit.
The files related to this tests are under `$SPEC_H/examples/nx`.
In this case we generate multiple tests. Each test has more fnops in a region with nx set and we want to verify if those fnops are executed or not

```
$SPEC_H/scripts/cr_inc_snip.py --output $SPEC_H/tests/nx $SPEC_H/examples/nx/spec_length.json $SPEC_H/examples/nx/nx.asm
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
The tests results present at `$SPEC_I/results/final_results.txt` should show that there is no increase of `UOPS_EXECUTED`.
Therefore, we can conclude the execution does not reach the non executable area hence the nx bit is respected.

### Memory Protection Extension (4.8 in the paper)
In this test we try to study MPX and more precisely how much code is speculative executed after a bounds check instruction.
The files for the tests are under `$SPEC_H/examples/mpx`.

After cleanup, run the usual commands to create tests, configure, compile, run and aggregate the results:
```
$SPEC_H/scripts/cr_inc_snip.py --output $SPEC_H/tests/mpx $SPEC_H/examples/mpx/spec_length.json $SPEC_H/examples/mpx/mpx/asm
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```

In the final report it is possible to observe the UOPS_EXECUTED.THREAD/CORE counter, which increase the more fnops we add up to a threashold and then stalls.
As described in the paper, the delta we see it is the number of uops speculated each bounds check.

NOTE: this test can be run only on machine with mpx support (e.g. skylake or more recent)

### Issued vs Execude uops (4.9 in the paper)
This test is used to verify our assumption that UOPS_ISSUED counters can be confidently used to indicate speculative execution.
Ideally the results of this experiment will show that issued and executed uops will grow linearly which implies that the more lea are issued the more they will be executed within speculative execution.

To run this experiment run the following commands:

```
$SPEC_H/scripts/cr_inc_snip.py --output $SPEC_H/tests/corr_slow_lea $SPEC_H/examples/corr_issued_and_exec/corr_issued_and_exec.json $SPEC_H/examples/corr_issued_and_exec/corr_issued_and_exec_slow_lea.asm
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_H/scripts/run_test.py $SPEC_I -r 1000 -c
sudo $SPEC_H/scripts/post-processing.py -l $SPEC_I/results
```
In the final report at `$SPEC_I/results/final_results.txt`  we should be able to observe that UOPS_EXECUTED.CORE/THREAD and UOPS_ISSUED.SLOW_LEA grow linearly up to a certain threshould in which
we stall the execution unit related to slow lea.

