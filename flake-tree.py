# vim: nomodeline

import json
import itertools

NodeLink = list[str]
NodeID = str
NodeTag = NodeID | NodeLink
AllNodes = dict[NodeID, dict]

with open("flake.lock", "r") as lockfile:
    lock = json.load(lockfile)
    version = lock["version"]
    if version != 7:
        print(f"unsupported lockfile version {version}")
        exit(1)

    nodes = lock["nodes"]


def get_node_link(tag: NodeTag) -> NodeLink:
    if isinstance(tag, str):
        return [tag]
    return tag


def resolve_node(nodes: AllNodes, link: NodeLink) -> NodeID:
    if len(link) == 1:
        return link[0]

    tag = nodes[link[0]]["inputs"][link[1]]
    link = get_node_link(tag) + link[2:]

    return resolve_node(nodes, link)


def get_node(nodes: AllNodes, tag: NodeTag) -> NodeID:
    return resolve_node(nodes, get_node_link(tag))


def resolve_inputs(nodes: AllNodes, root: NodeID) -> dict:
    node: dict = nodes[root]
    inputs: dict[str, NodeTag] = node.get("inputs", {})
    return {
        key: {"tag": tag, "id": get_node(nodes, tag)}
        # if get_node(nodes, tag) != tag
        # else tag # human-readable, but not machine readable
        for key, tag in inputs.items()
    }


resolved = {root: resolve_inputs(nodes, root) for root in nodes}
# print(json.dumps(resolved, indent=2))


def absorb_descendants(resolved: AllNodes, root: NodeID):
    inputs: dict[str, dict] = resolved[root]
    if not inputs:
        return root
    return {
        res["id"]: absorb_descendants(resolved, res["id"])
        for res in inputs.values()
    }


absorbed = {lock["root"]: absorb_descendants(resolved, lock["root"])}
# print(json.dumps(absorbed, indent=2))
# print("// vim: ft=jsonnet foldmethod=syntax foldlevel=3")


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


RIGHT_DOUBLE_ARROW = "\N{RIGHTWARDS DOUBLE ARROW}"
HOURGLASS = "\N{WHITE HOURGLASS}"


class Options(object):
    def __init__(
        self,
        FORK="\u251c",
        LAST="\u2514",
        VERTICAL="\u2502",
        HORIZONTAL="\u2500",
        NEWLINE="\u23ce",
        ARROW=RIGHT_DOUBLE_ARROW,
        HOURGLASS=HOURGLASS,
    ):
        self.FORK = FORK
        self.LAST = LAST
        self.VERTICAL = VERTICAL
        self.HORIZONTAL = HORIZONTAL
        self.NEWLINE = NEWLINE
        self.ARROW = ARROW
        self.HOURGLASS = HOURGLASS

    def color(self, node, depth):
        return lambda text, *a, **kw: text

    def vertical(self):
        return "".join([self.VERTICAL, "   "])

    def fork(self):
        return "".join([self.FORK, self.HORIZONTAL, self.HORIZONTAL, " "])

    def last(self):
        return "".join([self.LAST, self.HORIZONTAL, self.HORIZONTAL, " "])


ASCII_OPTIONS = Options(
    FORK="|",
    LAST="+",
    VERTICAL="|",
    HORIZONTAL="-",
    NEWLINE="\n",
    ARROW="=>",
    HOURGLASS="|Y|",
)


def _format_newlines(prefix, formatted_node, options):
    """
    Convert newlines into U+23EC characters, followed by an actual newline and
    then a tree prefix so as to position the remaining text under the previous
    line.
    """
    replacement = "".join([options.NEWLINE, "\n", prefix])
    return formatted_node.replace("\n", replacement)


def _format_tree(nodeid, children_dict: dict | str, options, prefix="", depth=0):
    color = options.color(nodeid, depth)
    # options.set_depth(depth)
    next_prefix = prefix + color(options.vertical())
    if isinstance(children_dict, str):
        return children_dict
    children: list[dict] = [ {key: value} for key, value in children_dict.items()]
    for child in children[:-1]:
        for child_id, child_children in child.items():
            yield "".join(
                [
                    prefix,
                    color(options.fork()),
                    _format_newlines(next_prefix, child_id, options),
                ]
            )
            for result in _format_tree(
                child_id, child_children, options, next_prefix, depth=depth + 1
            ):
                yield result
    if children:
        last_prefix = "".join([prefix, "    "])
        yield "".join(
            [
                prefix,
                color(options.last()),
                _format_newlines(last_prefix, list(children[-1].keys())[0], options),
            ]
        )
        for result in _format_tree(
            list(children[-1].keys())[0],
            list(children[-1].values())[0],
            options,
            last_prefix,
            depth=depth + 1,
        ):
            yield result


def format_tree(node, children, options=None):
    lines = itertools.chain(
        [node],
        _format_tree(node, children, options or Options()),
        [""],
    )
    return "\n".join(lines)


def format_ascii_tree(tree, children):
    """Formats the tree using only ascii characters"""
    return format_tree(tree, children, ASCII_OPTIONS)


def print_tree(*args, **kwargs):
    print(format_tree(*args, **kwargs))


print(format_tree("root", absorbed["root"]))
