# vim: nomodeline

import json

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
        key: {"original": tag, "resolved": get_node(nodes, tag)}
        # if get_node(nodes, tag) != tag
        # else tag # human-readable, but not machine readable
        for key, tag in inputs.items()
    }


resolved = {root: resolve_inputs(nodes, root) for root in nodes}
# print(json.dumps(resolved, indent=2))


def absorb_descendants(resolved: AllNodes, root: NodeID):
    inputs: dict = resolved[root]
    return {
        key: absorb_descendants(resolved, tag["resolved"])
        for key, tag in inputs.items()
    }


absorbed = absorb_descendants(resolved, lock["root"])
print(json.dumps({lock["root"]: absorbed}, indent=2))
print('// vim: ft=jsonnet foldmethod=syntax foldlevel=3')
