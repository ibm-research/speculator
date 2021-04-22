# DoubleBTI attack using ReverseBTI gadget

## Run attack
First we need to add the attacker and the victim to the tests under speculator.

```
ln -s $SPEC_H/examples/doubleBTI/dbl* $SPEC_H/tests/

cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja"

ninja -C $SPEC_B install
```

The we can run the script that launch the attack. Here, the script uses
Speculator as orchestrator only without PMC. The data used to leak the string
are output by the attacker in /tmp/attacker.output and they contain the time
information for each of the array cells.

```
zsh doubleBTI_POC.zsh
```

## Brief attack description
This test is the proof of concept implementation of a doubleBTI attack in which
a reverseBTI gadget is used to leak data from a victim to an attacker using the
Branch Predictor.

In this POC the attacker can lure the victim to process a specific character `C` of a string.
Using a first BTI attack, we can have the victim to execute a second indirect call
based on a `fun(C)` value. The outcome of `fun(C)` is 256 possible values that
should be mappable virtual addresses.

At this point, the attacker can perform this second indirect call
trained by victim using the `fun(C)` value and observe where speculative execution land
towards. `fun(C)` is known to the attacker which will map each one of the possible
256 values in its address space and instrument with array accesses that will
give us the knowledge of which C was computed by victim at the time of the call.

The array for the final data access is all handled by the attacker which can
accurately evict each cell from memory. This guarantee a very clear signal
whenever the attack complete successfully (e.g. all the indirect calls are
speculative executed by victim).

## ReverseBTI gadget
This gadget is represented by this second indirect call that the victim executes
which train the BP for the attacker. In our doubleBTI POC, the gadget follows the
speculative control flow hijacked performed by a BTI attack.

Though, the ReverseBTI gadget it is not limited to BTI speculative control flow
hijacks but can be used in combination of any speculative control flow hijacks
technique. For instance, speculative return hijack can be used in combination
with ReverseBTI too.

More details available about this in our WOOT 2019 paper referenced in README.md

