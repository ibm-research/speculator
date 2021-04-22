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

if (( ${+SPEC_H} )) then
    echo -e "\e[33mSPEC_H is set to ${SPEC_H}\e[39m"
else
    echo -e "\e[31mERROR: SPEC_H must be properly set\e[39m"
    exit
fi

if (( ${+SPEC_B} )) then
    echo -e "\e[33mSPEC_B is set to ${SPEC_B}\e[39m"
else
    echo -e "\e[31mERROR: SPEC_B must be properly set\e[39m"
    exit
fi

cmake $SPEC_H -B$SPEC_B -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$SPEC_I -G "Ninja" -DCANARY=ON

ninja -C $SPEC_B install

sudo $SPEC_I/speculator_mon -r1000 -v $SPEC_I/tests/arch_fwd/arch_fwd -o $SPEC_I/results/arch_fwd -c $SPEC_I/speculator.json
sudo $SPEC_I/speculator_mon -r1000 -v $SPEC_I/tests/arch_bwd/arch_bwd -o $SPEC_I/results/arch_bwd -c $SPEC_I/speculator.json
sudo $SPEC_I/speculator_mon -r1000 -v $SPEC_I/tests/spec_fwd/spec_fwd -o $SPEC_I/results/spec_fwd -c $SPEC_I/speculator.json
sudo $SPEC_I/speculator_mon -r1000 -v $SPEC_I/tests/spec_bwd/spec_bwd -o $SPEC_I/results/spec_bwd -c $SPEC_I/speculator.json

echo -e "\e[33mArchitecture Forward Edge Overwrite \e[39m"
cat $SPEC_I/results/arch_fwd | cut -d "|" -f 4 | grep -v LD | sort | uniq -c | awk '{if ($2==3) printf "%d-%d\n", $1, $2}'
echo -e "\e[33mArchitecture Backward Edge Overwrite \e[39m"
cat $SPEC_I/results/arch_bwd | cut -d "|" -f 4 | grep -v LD | sort | uniq -c | awk '{if ($2==3) printf "%d-%d\n", $1, $2}'
echo -e "\e[33mSpeculative Forward Edge Overwrite \e[39m"
cat $SPEC_I/results/spec_fwd | cut -d "|" -f 4 | grep -v LD | sort | uniq -c | awk '{if ($2==3) printf "%d-%d\n", $1, $2}'
echo -e "\e[33mSpeculative Backward Edge Overwrite \e[39m"
cat $SPEC_I/results/spec_bwd | cut -d "|" -f 4 | grep -v LD | sort | uniq -c | awk '{if ($2==3) printf "%d-%d\n", $1, $2}'

