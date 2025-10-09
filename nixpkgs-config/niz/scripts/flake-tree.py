#!/usr/bin/env python3
# vim: nomodeline
#
# minimal implementation of `nix flake metadata`
#
# namely, print a tree of _locked_ flake inputs
# with each node labeled by the _unique_ name in flake.lock
# this is useful for deduplicating flake inputs
#

import json
import itertools
import argparse
import sys

def get_args_parser():
    args_parser = argparse.ArgumentParser(
        description="print the inputs tree from Nix's flake.lock",
    )
    args_parser_group = args_parser.add_mutually_exclusive_group()
    args_parser_group.add_argument(
        "--resolve",
        action="store_true",
        help="print the _flattened_ resolved inputs in JSON",
    )
    args_parser_group.add_argument(
        "--json",
        action="store_true",
        help="print the resolved inputs _tree_ in JSON",
    )
    args_parser_group.add_argument(
        "--jsonc",
        action="store_true",
        help="print the JSON tree with a vim modeline comment for folding",
    )
    args_parser_group.add_argument(
        "--ascii",
        action="store_true",
        help="format the tree using only ascii characters",
    )
    return args_parser

# unique id of a node, namely "global" keys of "nodes" in flake.lock
NodeID = str
AllNodes = dict[NodeID, dict]

# link to another flake input, used for the `.follows` redirection
NodeLink = list[str]

# resolved / unresolved value of a flake input
# each flake input is a map from a "local" name to a `NodeTag`
# "local" names are the last component of a `NodeLink`
NodeTag = NodeID | NodeLink


def get_node_link(tag: NodeTag) -> NodeLink:
    if isinstance(tag, NodeID):
        return [tag]
    return tag


def resolve_node(nodes: AllNodes, tag: NodeTag) -> NodeID:
    if isinstance(tag, NodeID):
        return tag
    if len(tag) == 1:
        return tag[0]

    link: NodeLink = tag

    # resolve the first parts ([0], [1]) of the link
    resolved_tag: NodeTag = nodes[link[0]]["inputs"][link[1]]

    # continue to the next parts [2:]
    new_link = get_node_link(resolved_tag) + link[2:]

    return resolve_node(nodes, new_link)


def resolve_inputs(nodes: AllNodes, root: NodeID) -> dict:
    node: dict = nodes[root]
    inputs: dict[str, NodeTag] = node.get("inputs", {})
    return {
        key: {"tag": tag, "id": resolve_node(nodes, tag)}
        # if resolve_node(nodes, tag) != tag
        # else tag # human-readable, but not machine readable
        for key, tag in inputs.items()
    }


def absorb_descendants(resolved: AllNodes, root: NodeID):
    inputs: dict[str, dict] = resolved[root]
    return {
        res["id"]: absorb_descendants(resolved, res["id"])
        for res in inputs.values()  # fmt: skip
    }


"""
    Library for formatting trees, from https://github.com/jonathanj/eliottree
"""

# Copyright (c) 2015 Jonathan M. Lange <jml@mumak.net>
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


class TreeOptions(object):
    def __init__(
        self,
        FORK="\u251c",
        LAST="\u2514",
        VERTICAL="\u2502",
        HORIZONTAL="\u2500",
        NEWLINE="\u23ce",
        ARROW="\N{RIGHTWARDS DOUBLE ARROW}",
        HOURGLASS="\N{WHITE HOURGLASS}",
    ):
        self.FORK = FORK
        self.LAST = LAST
        self.VERTICAL = VERTICAL
        self.HORIZONTAL = HORIZONTAL
        self.NEWLINE = NEWLINE
        self.ARROW = ARROW
        self.HOURGLASS = HOURGLASS

    def vertical(self):
        return "".join([self.VERTICAL, "   "])

    def fork(self):
        return "".join([self.FORK, self.HORIZONTAL, self.HORIZONTAL, " "])

    def last(self):
        return "".join([self.LAST, self.HORIZONTAL, self.HORIZONTAL, " "])


ASCII_OPTIONS = TreeOptions(
    FORK="|",
    LAST="+",
    VERTICAL="|",
    HORIZONTAL="-",
    NEWLINE="\n",
    ARROW="=>",
    HOURGLASS="|Y|",
)


def _format_newlines(prefix: str, formatted_node: str, options: TreeOptions):
    """
    Convert newlines into U+23EC characters, followed by an actual newline and
    then a tree prefix so as to position the remaining text under the previous
    line.
    """
    replacement = "".join([options.NEWLINE, "\n", prefix])
    return formatted_node.replace("\n", replacement)


TreeBranches = dict[str, dict]


def _format_tree(children: TreeBranches, options: TreeOptions, prefix="", depth=0):
    next_prefix = prefix + options.vertical()
    listed: list[dict] = [
        {node_id: grandchildren}  # fmt: skip
        for node_id, grandchildren in children.items()
    ]
    for child in listed[:-1]:
        for node_id, grandchildren in child.items():
            yield "".join(
                [
                    prefix,
                    options.fork(),
                    _format_newlines(next_prefix, node_id, options),
                ]
            )
            for result in _format_tree(
                grandchildren, options, next_prefix, depth=depth + 1
            ):
                yield result
    if listed:
        last_prefix = "".join([prefix, "    "])
        for node_id, grandchildren in listed[-1].items():
            yield "".join(
                [
                    prefix,
                    options.last(),
                    _format_newlines(last_prefix, node_id, options),
                ]
            )
            for result in _format_tree(
                grandchildren,
                options,
                last_prefix,
                depth=depth + 1,
            ):
                yield result


def format_tree(root: NodeID, children: TreeBranches, options=None):
    lines = itertools.chain(
        [root],
        _format_tree(children, options or TreeOptions()),
        # [""],
    )
    return "\n".join(lines)


if __name__ == "__main__":
    args = get_args_parser().parse_args()

    with open("flake.lock", "r") as lockfile:
        lock = json.load(lockfile)
        version = lock["version"]
        if version != 7:
            print(f"unsupported lockfile version {version}")
            sys.exit(1)

        nodes: AllNodes = lock["nodes"]

    resolved = {root: resolve_inputs(nodes, root) for root in nodes}
    if args.resolve:
        print(json.dumps(resolved, indent=2))
        sys.exit(0)

    absorbed = {lock["root"]: absorb_descendants(resolved, lock["root"])}
    if args.json or args.jsonc:
        print(json.dumps(absorbed, indent=2))
        if args.jsonc:
            print("// vim: ft=jsonnet foldmethod=syntax foldlevel=3")
        sys.exit(0)

    if args.ascii:
        print(format_tree("root", absorbed["root"], ASCII_OPTIONS))
    else:
        print(format_tree("root", absorbed["root"]))
