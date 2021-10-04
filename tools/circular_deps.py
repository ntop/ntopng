#!/usr/bin/env python

# (C) 2013-21 - ntop.org
# Author: Simone Mainardi <mainardi@ntop.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

import argparse
import re
import sys
from pathlib import Path
import networkx as nx

__version__ = '1.0.0'

class CircularDeps(object):
    def __init__(self):
        self._G = None # The graph
        self._requires = [] # All the dependencies read from files

    def _build_requires(self):
        # Iterate over all lua files, both community and pro
        for available_path in ['./../scripts', './../pro/scripts']:
            for path in Path(available_path).rglob('*.lua'):
                # Exclude backup files (e.g., starting with #)
                if path.name.startswith('.') or path.name.startswith('#') or path.name.startswith('~'):
                    continue

                # Search for requires
                with path.open('r', encoding="utf-8") as fid:
                    for line in fid:
                        res = [
                            # require without assignment
                            re.search(r'^require.*\"(.*?)\"' ,line),
                            re.search(r'^require.*\'(.*?)\'' ,line),
                            # require with assignment to local variables
                            re.search(r'^local.*require.*\"(.*?)\"' ,line),
                            re.search(r'^local.*require.*\'(.*?)\'' ,line),
                            # require with assignment to global variables
                            re.search(r'^[^\s].*require.*\"(.*?)\"' ,line),
                            re.search(r'^[^\s].*require.*\'(.*?)\'' ,line),
                        ]

                        # Add requires
                        for r in res:
                            if r and r.group:
                                required = r.group(1)
                                self._requires.append((path.name.replace('.lua', ''), required))

    def _build_graph(self):
        self._G = nx.DiGraph()
        self._G.add_edges_from(self._requires)

    def _find_cycles(self):
        all_cycles = []

        # For each node
        for n in self._G.nodes():
            try:
                # Search a cycle with Depth-first traversal
                cycle = list(nx.find_cycle(self._G, n))

                # If cycle not already found, add it to the results list
                found = False
                for c in all_cycles:
                    if cycle == c:
                        found = True
                        break

                if not found:
                    all_cycles.append(cycle)

            # When no cycles are found for the current node, an exception is thrown and it is safe to ignore it
            except nx.exception.NetworkXNoCycle:
                pass

        print(all_cycles)

    def check(self):
        self._build_requires()
        self._build_graph()
        self._find_cycles()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Find cycles in Lua dependencies. Re-run after removing cycles until no other cycle shows up.')
    parser.add_argument('-V', '--version', action='version', version='%(prog)s v' + sys.modules[__name__].__version__)
    args = parser.parse_args()

    tf = CircularDeps()

    tf.check()
