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
import subprocess
import multiprocessing

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('projectpath', help='Test base path where tests are looked \
                       for')
    parser.add_argument('--repeat', '-r', help='Number of repeatition',
                        default=10000, type=int)
    parser.add_argument('--cleanup', '-c', help='Cleanup result folder',
                        action='store_true')

    args = parser.parse_args()

    os.system("taskset -pc {} {}".format(multiprocessing.cpu_count() -1, os.getpid()))

    if args.cleanup:
        print ("Cleaning up results folder as requested\n")
        for dirname,_,filenames in os.walk(os.path.join(args.projectpath,"results")):
            for f in filenames:
                print("Deleting {}".format(os.path.join(dirname, f)))
                os.remove(os.path.join(dirname, f))
    i = 0
    for dirname,_, filenames in os.walk(os.path.join(args.projectpath,"tests")):
        for binname in filenames:
            temp_path = os.path.join(args.projectpath, "results")
            results_path = os.path.join(temp_path, binname)
            spec_mon = os.path.join(args.projectpath, "speculator_mon")
            j = 0

            while (os.path.isfile(results_path)):
                results_path = os.path.join(temp_path, binname+"_"+str(j))
                j = j + 1

            exec_path = os.path.join(dirname, binname)
            if not os.access(exec_path, os.X_OK):
                continue
            try:
                proc = subprocess.Popen([spec_mon, '-r',
                                         str(args.repeat),
                                         '-o', results_path,
                                         '-v', exec_path],
                                    stdout=subprocess.PIPE)
            except OSError:
                print("Error during the call of speculator_mon, double check the " \
                      "file location")
                exit(-1)
            i = i + 1
            proc.communicate()
            print ("{}) Execution of {} terminated.\n" \
                   "Results written at {}\n".format(i,binname, results_path))

    print ("Finished.\n")

if __name__ == '__main__':
    main()
