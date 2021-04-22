#!/bin/zsh
# Copyright 2021 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if (( ${+SPEC_I} )) then
    echo -e "\e[33mSPEC_I is set to ${SPEC_I}\e[39m"
else
    echo -e "\e[31mERROR: SPEC_I must be properly set\e[39m"
    exit
fi

echo -e "\e[33mCreating doublebti_res \e[39m"
mkdir -p /tmp/doublebti_res

echo -e  "\e[33mCleaning doublebti_res \e[39m"
setopt +o nomatch
rm -rf /tmp/doublebti_res/*

echo -e "\e[33mRemoving previous generated attacker.out from tmp \e[39m"
rm -f /tmp/attacker.output

for j ({0..19}) do
    $SPEC_I/speculator_mon  -v $SPEC_I/tests/dblbti_victim/dblbti_victim        \
                            -a $SPEC_I/tests/dblbti_attacker/dblbti_attacker    \
                            -o $SPEC_I/results/speculator.output                \
                            --vpar $j                                           \
                            -r 100                                              \
                            -c $SPEC_I/speculator.json                          \
                            -m

    for x ({0..256}); do
        cat /tmp/attacker.output | grep "^$x)" | cut -d " " -f 2 | awk '{if($1==$1+0 && $1<80)print $1}' | wc -l
    done | nl -nln --starting-line-number=0 > /tmp/tmp.res

    cat /tmp/tmp.res | awk '{if ($2>0) printf "\033[32m%c\033[0m ", $1}'

    cat /tmp/tmp.res | awk '{sum+=$2;} END{if (sum==0) printf("\033[31mX\033[0m ")}'

    mv /tmp/attacker.output /tmp/doublebti_res/attacker_$j.output
done
