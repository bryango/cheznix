import json

NodeLink = list[str]
NodeName = str | NodeLink


def get_node_link(name: NodeName) -> NodeLink:
    if isinstance(name, str):
        return [name]
    return name


def resolve_node(nodes: dict[str, dict], link: NodeLink) -> str:
    if len(link) == 1:
        return link[0]

    name = nodes[link[0]]["inputs"][link[1]]
    link = get_node_link(name) + link[2:]

    return resolve_node(nodes, link)


def get_node(nodes: dict[str, dict], name: NodeName) -> str:
    return resolve_node(nodes, get_node_link(name))


def resolve_inputs(nodes: dict, root: str) -> dict:
    node: dict = nodes[root]
    inputs: dict = node.get("inputs", {})
    return {
        key: {"original": name, "resolved": get_node(nodes, name)}
        if get_node(nodes, name) != name
        else name
        for key, name in inputs.items()
    }


with open("flake.lock", "r") as lockfile:
    lock = json.load(lockfile)
    version = lock["version"]
    if version != 7:
        print(f"unsupported lockfile version {version}")
        exit(1)

    nodes = lock["nodes"]
    resolved = {root: resolve_inputs(nodes, root) for root in nodes}
    print(json.dumps(resolved, indent=2))
