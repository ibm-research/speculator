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
# import csv
import argparse

from numpy import std
from numpy import mean
from numpy import average

from sqlalchemy import or_
from sqlalchemy import Table
from sqlalchemy import select
from sqlalchemy import Column
from sqlalchemy import Integer
from sqlalchemy import MetaData
from sqlalchemy import create_engine

results = []
single_line = dict()
tab = []

UOPS_EXECUTED = ""

def main():
    global results
    global UOPS_EXECUTED
    parser = argparse.ArgumentParser()
    parser.add_argument("--location", "-l",
                        required=True,
                        help="Specify the result directory to be process")
    parser.add_argument("--thread", "-t",
                        action='store_true',
                        help="Specify that UOPS_EXECUTED.TREAD should be used \
                        instead")

    arg = parser.parse_args()


    if arg.thread:
        UOPS_EXECUTED = "UOPS_EXECUTED.THREAD"
    else:
        UOPS_EXECUTED = "UOPS_EXECUTED.CORE"
    # Connecting to the in-memory db
    engine = create_engine('sqlite:///:memory:', echo=False)
    conn = engine.connect()
    metadata = MetaData(bind=engine)

    try:
        with open(os.path.join(arg.location, "final_results.txt"), "w") as final:
            for dirname, dirnames, filenames in os.walk(arg.location):
                for f in sorted(filenames):
                    if f == "final_results.txt":
                        continue
                    print ("Considering {}".format(f))
                    with open(os.path.join(dirname, f), "r") as res_file:
                        lines = res_file.readlines()

                        first = True
                        tab = []
                        for l in lines:
                            if first:
                                categories = l.split("|")
                                categories = categories[:-1]
                                first = False
                                table = Table(f, metadata,
                                      Column('id', Integer, autoincrement=True, primary_key=True),
                                      *(Column(counter_name, Integer()) for
                                        counter_name in categories)
                                      )
                                table.create()
                                metadata.create_all(engine)
                            else:
                                i = 0
                                single_line = dict()

                                splitted_line = l.split("|")
                                splitted_line = splitted_line[:-1]

                                for item in splitted_line:
                                    single_line[categories[i]] = item
                                    i = i + 1

                                tab.append(single_line)
                        conn.execute(table.insert(), tab)

                        # Pull CYCLES column to compute mean and std
                        sql = select([table.c.CYCLES,
                                      table.c[UOPS_EXECUTED]])
                        cycles_res = conn.execute(sql)

                        res_cycles = []
                        res_uops = []

                        for row in cycles_res:
                            res_cycles.append(row[0])
                            res_uops.append(row[1])

                        cycle_mean = mean(res_cycles, axis=0)
                        cycle_std = std(res_cycles, axis=0)

                        uops_mean = mean(res_uops, axis=0)
                        uops_std = std(res_uops, axis=0)

                        # Delete outliers and where there was no mispredicted
                        # branch
                        a_clause = or_(table.c.CYCLES <= (cycle_mean - 2 * cycle_std),
                                          table.c.CYCLES >= (cycle_mean + 2 *
                                                             cycle_std)).self_group()
                        b_clause = or_(table.c[UOPS_EXECUTED] <= (uops_mean - 2 * uops_std),
                                       table.c[UOPS_EXECUTED] >= (uops_mean + 2 * uops_std)).self_group()
                        if uops_std != 0:
                            c_clause = or_(a_clause, b_clause).self_group()
                        else:
                            if cycle_std != 0:
                                c_clause = a_clause
                            else:
                                c_clause = or_(False, False)


                        d_clause = or_(c_clause,
                                       table.c["BR_MISP_RETIRED.ALL_BRANCHES"]
                                       <= 0).self_group()

                        d = table.delete() \
                                 .where(c_clause)

                        res = conn.execute(d)

                        # sel = select([table])
                        # res = conn.execute(sel)
                        # fh = open(f+".csv", "wb")
                        # outcsv = csv.writer(fh)
                        # outcsv.writerow(res.keys())
                        # outcsv.writerows(res)
                        # fh.close()

                        final.write ("######### {} ###########\n".format(f))
                        first = True
                        i = 0
                        for clm in table.c:
                            if first:
                                first = False
                                continue
                            sql = select([clm])
                            res = []

                            sql_res = conn.execute(sql)
                            for row in sql_res:
                                res.append(row[0])

                            final.write("{}: average: {}, std deviation: {}\n"
                                        .format(categories[i],
                                                average(res),
                                                std(res)
                                                )
                                        )
                            i = i+1
                        final.write ("---------------------------------------------------------\n")
                        table.drop(engine)

    except IOError, e:
        print ("{}".format(e))
        exit(-1)


if __name__ == "__main__":
    main()
