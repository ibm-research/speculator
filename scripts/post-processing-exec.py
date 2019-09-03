#!/usr/bin/env python2

# Copyright 2019 IBM Corporation
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

import os
import argparse


from numpy import std
from numpy import mean
from numpy import average
from collections import defaultdict

results_misspr = []
results_pr = []
result = []

def main():
    global results
    parser = argparse.ArgumentParser()
    parser.add_argument("--location", "-l",
                        required=True,
                        help="Specify the result directory to be process")

    arg = parser.parse_args()

    try:
        with open(os.path.join(arg.location, "final_results.txt"), "w") as final:
            for dirname, dirnames, filenames in os.walk(arg.location):
                for f in filenames:
                    if f == "final_results.txt":
                        continue
                    print ("Considering {}".format(f))
                    with open(os.path.join(dirname, f), "r") as res_file:
                        lines = res_file.readlines()
                        results_misspr = defaultdict(list)
                        results_pr = defaultdict(list)
                        result = defaultdict(list)
                        for l in lines:
                            splitted_line = l.split("|")
                            splitted_line = splitted_line[:-1]
                            result = defaultdict(list)
                            for item in splitted_line:
                                category, res = item.split(":")

                                result[category].append(int(res))

                                if (category == "BR_MISP_RETIRED.ALL_BRANCHES"):
                                    if int(res) == 1:
                                        for k, v in result.items():
                                            results_misspr[k].append(v)
                                    else:
                                        for k, v in result.items():
                                            results_pr[k].append(v)

                        # final.write ("######### {} ###########\n".format(f))
                        print ("Computing predicted for {}".format(f))
                        # final.write ("PREDICTED CORRECTLY\n")
                        for category, res in results_pr.items():
                            len_ = f.rpartition('_')[2]
                            if category == "UOPS_EXECUTED.CORE" or \
                            category == "UOPS_EXECUTED.THREAD":
                                if "only" in f :
                                    pre = "NOBR:PRE"
                                else:
                                    pre = "BR:PRE"
                                res_mean = mean(res, axis=0)
                                res_std = std(res, axis=0)
                                res_final = [x for x in res
                                             if (x >= res_mean - 2 * res_std)]
                                res_final = [x for x in res_final
                                             if (x <= res_mean + 2 * res_std)]
                                final.write("{}:{}:{}\n"
                                        .format(len_,
                                                pre,
                                                average(res_final)#,
                                                # std(res_final)
                                                )
                                        )

                        print ("Computing miss-predicted for {}".format(f))
                        # final.write ("\nMISS-PREDICTED\n")
                        for category, res in results_misspr.items():
                            len_ = f.rpartition('_')[2]
                            if category == "UOPS_EXECUTED.CORE" or \
                            category == "UOPS_EXECUTED.THREAD":
                                if "only" in f :
                                    pre = "NOBR:MISS"
                                else:
                                    pre = "BR:MISS"
                                res_mean = mean(res, axis=0)
                                res_std = std(res, axis=0)
                                res_final = [x for x in res
                                             if (x >= res_mean - 2 * res_std)]
                                res_final = [x for x in res_final
                                             if (x <= res_mean + 2 * res_std)]
                                final.write("{}:{}:{}\n"
                                        .format(len_,
                                                pre,
                                                average(res_final)
                                                # std(res_final)
                                                )
                                        )
                        # final.write ("---------------------------------------------------------\n")
    except IOError:
        print ("Error while opening {}".format(arg.input))
        exit(-1)


if __name__ == "__main__":
    main()
