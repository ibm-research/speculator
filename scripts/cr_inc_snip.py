#!/usr/bin/env python2

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

import os
import json
import errno
import argparse

basename = ""

def get_index(template):
    idx_code = -1
    idx_data = -1
    with open(template, "r") as f:
        for i, line in enumerate(f, 1):
            if "SNIPPET STARTS HERE" in line:
                idx_code = i + 1

            if "DATA STARTS HERE" in line:
                idx_data = i + 1
    return (idx_data, idx_code)

def update_data(template, idx_data, idx_code, snippet_json):
    if "DATA" not in snippet_json:
        print ("The json file loaded has no data object specified")
        return (template, idx_data, idx_code)

    for line in snippet_json["DATA"]:
        template.insert(idx_data, "\t" + line + "\n")
        idx_data = idx_data + 1
        idx_code = idx_code + 1

    return (template, idx_data, idx_code)

def update_code(args, template, idx_data, idx_code, snippet_json):
    global basename
    if "INST" not in snippet_json:
        print("The json file loaded has no INST object specified")
        exit(-1)

    for i, line in enumerate(snippet_json["INST"], 1):
        template.insert(idx_code, "\t" + line + "\n")
        idx_code = idx_code + 1
        unit = "0" if i in range(0, 10) else ""
        dec = "0" if i in range(0, 100) else ""
        cent = "0" if i in range (0, 1000) else ""
        path = os.path.join(args.output, basename+"_"+ cent + dec + unit + str(i)+".asm")
        with open(path, "w") as f:
            for line in template:
                f.write(line)
    return (template, idx_data, idx_code)

def extract_basename(json_file):
    return os.path.basename(json_file).split('.')[0]

def main():
    global basename
    parser = argparse.ArgumentParser(description='This scripts load a json with'
                                    'snippet structure and create multiple'
                                    'incremental snippets')
    parser.add_argument('json', help='json file that contains the snippet to be split')
    parser.add_argument('template', help='template file to be complete with the snippet')
    parser.add_argument('--output', '-o', help='output location', default=".")
    args = parser.parse_args()

    if not args.json.endswith(".json"):
        print ("The file name must have .json extension")
        exit(-1)

    if not os.path.isfile(args.json):
        print ("Json file does not exists\n")
        exit(-1)

    if not os.path.isfile(args.template):
        print ("Template file does not exits\n")
        exit(-1)

    if not os.path.exists(args.output):
        print ("The output folder specified does not exist. It will be created.")
        try:
            os.makedirs(args.output)
        except OSError as e:
            if e.errno != errno.EEXIST:
                exit(-1)

    basename = extract_basename(args.json)

    with open(args.json, "r") as fp:
        snippet_json = json.load(fp)

    (idx_data, idx_code) = get_index(args.template)

    if idx_data == -1 or idx_code == -1:
        print ("Wrong template format. Please provide the right template")
        exit(-1)

    with open(args.template, "r") as f:
        template_base = f.readlines()

    (template_base, idx_data, idx_code) = update_data(template_base, idx_data,
                                                      idx_code, snippet_json)

    # print ("idx_data = {}, idx_code = {}".format(idx_data, idx_code))

    (template_base, idx_data, idx_code) = update_code(args, template_base, idx_data,
                                                      idx_code, snippet_json)

if __name__ == "__main__":
    main()
