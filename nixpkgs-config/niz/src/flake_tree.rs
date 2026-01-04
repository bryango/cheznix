use std::{collections::BTreeMap, fmt::Display};

use anyhow::anyhow;
use serde::{Deserialize, Serialize};
use termtree::Tree;

#[non_exhaustive]
#[derive(Deserialize, Debug, Clone)]
pub(crate) struct FlakeLock {
    version: u32,
    pub(crate) nodes: AllLockNodes,
}

#[derive(Deserialize, Debug, Clone)]
pub(crate) struct AllLockNodes(BTreeMap<NodeID, LockNode>);

/// Unique identifier of a flake input, as defined in `flake.lock`.
///
/// For example, if there are multiple inputs named `nixpkgs`, they might be
/// represented as "nixpkgs" and "nixpkgs_2" in `flake.lock`.
#[derive(
    Deserialize, Serialize, derive_more::Display, Debug, Clone, PartialEq, Eq, PartialOrd, Ord,
)]
pub(crate) struct NodeID(String);

#[non_exhaustive]
#[derive(Deserialize, Debug, Clone)]
struct LockNode {
    inputs: Option<BTreeMap<String, FlakeNode>>,
}

/// Link to another flake input, used for the `.follows` redirection/
///
/// For example, `.follows = "nix-darwin/nixpkgs"` is represented as
/// `NodeLink(vec!["nix-darwin", "nixpkgs"])`.
#[derive(Deserialize, Serialize, Debug, Clone)]
struct NodeLink(Vec<String>);

/// Flake input node, either an ID (resolved) or a link to another input
/// (unresolved).
///
/// Each flake input is a map from a user facing, user friendly name to
/// an actual `FlakeNode`. In the unresolved case, the user facing name is
/// the last component of a `NodeLink`.
#[derive(Deserialize, Serialize, Debug, Clone)]
#[serde(untagged)]
enum FlakeNode {
    Id(NodeID),
    Link(NodeLink),
}

#[derive(Serialize, Debug)]
struct ResolvedInput {
    flake_node: FlakeNode,
    id: NodeID,
}

type ResolvedInputsMap = BTreeMap<String, ResolvedInput>;

fn get_node_link(node: FlakeNode) -> NodeLink {
    match node {
        FlakeNode::Id(id) => NodeLink(vec![id.0]),
        FlakeNode::Link(link) => link,
    }
}

fn error_key_not_found(key: impl Display) -> anyhow::Error {
    anyhow!("could not find flake input node {key}")
}

impl AllLockNodes {
    fn resolve_node(&self, node: &FlakeNode) -> anyhow::Result<NodeID> {
        match node {
            FlakeNode::Id(id) => Ok(NodeID(id.0.clone())),
            FlakeNode::Link(link) => {
                if link.0.len() == 1 {
                    return Ok(NodeID(link.0[0].clone()));
                }
                let first_part = &link.0[0];
                let second_part = &link.0[1];
                let resolved_tag = &self
                    .0
                    .get(&NodeID(first_part.clone()))
                    .ok_or_else(|| error_key_not_found(first_part))?
                    .inputs
                    .clone()
                    .unwrap_or_default()
                    .get(second_part)
                    .ok_or_else(|| error_key_not_found(second_part))?
                    .clone();
                let mut new_link_parts = get_node_link(resolved_tag.clone()).0;
                new_link_parts.extend_from_slice(&link.0[2..]);
                let new_link = NodeLink(new_link_parts);
                self.resolve_node(&FlakeNode::Link(new_link))
            }
        }
    }

    fn resolve_inputs(&self, node: &NodeID) -> anyhow::Result<ResolvedInputsMap> {
        let inputs = &self
            .0
            .get(node)
            .ok_or_else(|| error_key_not_found(node.0.clone()))?
            .inputs;
        let mut resolved_inputs = BTreeMap::new();
        for (flake_ref, flake_node) in inputs.clone().unwrap_or_default() {
            let resolved = ResolvedInput {
                flake_node: flake_node.clone(),
                id: self.resolve_node(&flake_node)?,
            };
            resolved_inputs.insert(flake_ref.clone(), resolved);
        }
        Ok(resolved_inputs)
    }

    fn resolve_all(&self) -> anyhow::Result<BTreeMap<NodeID, ResolvedInputsMap>> {
        let mut all_resolved = BTreeMap::new();
        for (node, _) in self.0.clone() {
            all_resolved.insert(node.clone(), self.resolve_inputs(&node)?);
        }
        Ok(all_resolved)
    }

    pub(crate) fn make_tree(&self) -> anyhow::Result<termtree::Tree<NodeID>> {
        make_tree(&self.resolve_all()?, &NodeID("root".to_string()))
    }
}

fn make_tree(
    all_resolved: &BTreeMap<NodeID, ResolvedInputsMap>,
    node: &NodeID,
) -> anyhow::Result<termtree::Tree<NodeID>> {
    let mut tree = Tree::new(node.clone());
    let inputs = all_resolved
        .get(node)
        .ok_or_else(|| error_key_not_found(node))?;
    for ResolvedInput { flake_node: _, id } in inputs.values() {
        tree.push(make_tree(all_resolved, id)?.clone());
    }
    Ok(tree)
}

#[derive(Deserialize, Debug, Clone)]
pub(crate) struct FlakeTree {
    #[serde(flatten)]
    deps: BTreeMap<String, FlakeTree>,
}

#[derive(Debug)]
pub(crate) struct FlakeTreeWithRoot {
    root: String,
    deps: Vec<FlakeTreeWithRoot>,
}

const FLAKE_TOPLEVEL_NODE: &str = "root";

impl From<FlakeTree> for FlakeTreeWithRoot {
    fn from(flake_tree: FlakeTree) -> Self {
        if flake_tree.deps.len() == 1 && flake_tree.deps.contains_key(FLAKE_TOPLEVEL_NODE) {
            let (_root, subtree) = flake_tree.deps.into_iter().next().unwrap();
            return Self::from(subtree);
        }
        let deps: Vec<FlakeTreeWithRoot> = flake_tree
            .deps
            .into_iter()
            .map(|(root, subtree)| {
                let mut subtree_with_root: FlakeTreeWithRoot = Self::from(subtree);
                subtree_with_root.root = root;
                subtree_with_root
            })
            .collect();
        Self {
            root: FLAKE_TOPLEVEL_NODE.to_string(),
            deps,
        }
    }
}

#[test]
fn flake_tree_from_json() {
    let data = r#"
        {
          "root": {
            "darwin-apps": {},
            "home-attrs": {},
            "nix-darwin": {
              "nixpkgs": {}
            },
            "nixpkgs": {},
            "nixpkgs-config": {
              "determinate-nix-src": {
                "nixpkgs": {}
              },
              "flake-compat": {},
              "flake-utils": {
                "systems": {}
              },
              "haumea": {
                "nixpkgs": {}
              },
              "infuse": {},
              "nixgl": {
                "flake-utils": {
                  "systems": {}
                },
                "nixpkgs": {}
              },
              "nixpkgs": {},
              "yants": {}
            },
            "system-manager": {
              "nixpkgs": {}
            }
          }
        }
    "#;

    let flake_tree = serde_json::from_str::<FlakeTree>(data).unwrap();
    println!("{:#?}", flake_tree);
    let flake_tree_with_root: FlakeTreeWithRoot = flake_tree.clone().into();
    println!("{:#?}", flake_tree_with_root);
    let tree: termtree::Tree<String> = flake_tree_with_root.into();
    println!("{tree}");
}

impl From<FlakeTreeWithRoot> for termtree::Tree<String> {
    fn from(flake_tree_with_root: FlakeTreeWithRoot) -> Self {
        let mut tree = termtree::Tree::new(flake_tree_with_root.root);
        for subtree in flake_tree_with_root.deps {
            tree.push(subtree);
        }
        tree
    }
}
