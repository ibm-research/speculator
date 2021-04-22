# BTI
This test provides an example of how Branch Target Injection (BTI) can be performed
using Speculator.

`Victim` performs an indirect call to a "correct" location that simply return and exit. It contains
three other functions (verify, verify2, verify3) that contain speculative execution markers.

`verify` contains **1** LD_BLOCK.STORE_FORWARD  
`verify2` contains **3** LD_BLOCK.STORE_FORWARD  
`verify3` contains **6** LD_BLOCK.STORE_FORWARD  

These functions are never called in the victim context . In fact, if executed
as a stand-alone program victim does not trigger any marker of type
LD_BLOCK.STORE_FORWARD.  
The attacker instead, performs the same exact sequence of
calls that are performed in the victim but with a specific target multiple
times. This will force in the branch history buffer the target we want the
victim to be hijacked to.  
If the attacker is run just before the victim on a co-located thread, the
speculative execution triggered by the indirect call should be re-direct to one
of the verify targets based on what was used in the attacker. Hence, the victim
performance counters should show that one of the verify location has been
speculative executed.

To compile and run the victim by itself:
```
ln -s $SPEC_H/examples/BTI/*.asm $SPEC_H/tests/
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"
ninja -C $SPEC_B install
sudo $SPEC_I/speculator_mon -q -r 1000 -o $SPEC_I/results/speculator_output -v $SPEC_I/tests/bti_victim/bti_victim
```
The results always show no hits for the marker (assuming LD_BLOCK.STORE_FORWARD is the 1st programmable counter specified, otherwise adjust -f X accordingly):
```
cat $SPEC_I/results/speculator_output | cut -d "|" -f 4| grep -v LD | sort | uniq -c
```
because no hijacked is performed.

If we re-run the test introducing the attacker process:
```
sudo $SPEC_I/speculator_mon -q -r 1000 -o $SPEC_I/results/speculator_output -v $SPEC_I/tests/bti_victim/bti_victim -a $SPEC_I/tests/bti_attacker/bti_attacker -s
cat $SPEC_I/results/speculator_output | cut -d "|" -f 4| grep -v LD | sort | uniq -c
```
Based on the target selected at line 49 in `examples/BTI/bti_attacker.asm` (e.g.
verify, verify2 and verify3) we should see 1, 3 or 6 markers be hit.
The success rate really depends on the current settings of the machine (e.g.
kernel version, security patches installed and enabled mitigations).

On KabyLake i7-8650U we have results around ~950 successful hijack over 1000
tries.

## Known problems
BTI is very sensible to various parameters which might drastically change the
success rate of the injection. Hereafter, a non-complete list of them

### History length
To be able to poison a specific indirect call or jump, we need to make sure that
the previous jump/call history sequence is the same between attacker and victim.
The longer is the matching sequence before the interested call/jump between
victim and attacker the higher are the chances of success.

If the attacker does not work please consider to uncomment the `jmpnext` macros
in both attacker and victim. Those macros add a sequence of instruction that
maximize the POC chances of success.

### Alignment
To be able to perform BTI successfully, it is necessary that attacker and victim
are perfectly aligned to be able to fool the CPU. To quick check the correct
alignment run:

```
objdump -D $SPEC_I/tests/bti_attacker/bti_attacker | egrep -e "(verify.*|call)>:"
objdump -D $SPEC_I/tests/bti_victim/bti_victim | egrep -e "(verify.*|call)>:"
```
Between the two output, the same label should have the same address in each
output.

### Are BTI mitigations enabled?
This test would not provide successful results on machines that have mitigations
enforced. To verify the status of the machine mitigations check:

```
cat /sys/devices/system/cpu/vulnerabilities/spectre_v2
```

if STIBP is forced then the attack would not work.
It will be necessary to add `nospectre_v2` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`
and then run:

```
sudo update-grub && reboot
```
to effectively disable such mitigation.

In case the mitigation is marked as conditional, it should not affect the tests
since they neither use prctl to enable the mitigation nor use SECCOMP which
would trigger STIBP when activated.

### Kernel version
For some reason the same CPU with different kernel versions (which has the same
mitigations settings) has different success rate. We attribute this different behavior on
the scheduler decisions. To tune the attack you can play with the following
Speculator options:

`-s` which force serialization between attacker and victim (victim is started when
attacker has finished its execution)

`-d` adds delay between the start of victim and the attacker in nanosecond (To be
noticed is that a big delay is known to degradate the signal so do not push it
too far :) )

### Is the attacker running in the right co-located thread?
One possible reason for this attack not to be working is that the machine has
not SMT enabled and/or the attacker process is not running on a co-located
thread compared to the victim. Speculator default value for the co-located
thread is 5 since most of our cpus have 4 cores/8 threads but each CPU/OS pair enumerates differently.

Check the output of:
```
cat /proc/cpuinfo | egrep -e "(processor|core id)"
```
to indentify the right co-located thread.
Once you indentified the processor number, you can simply re-run cmake with
`-DATTACKER=X` to propagate this piece of information.

For instance:

```
cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja" -DATTACKER=5
```
