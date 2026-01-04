use std::{collections::BTreeMap, fmt::Display};

use anyhow::bail;
use serde::{Deserialize, Serialize};
use termtree::Tree;

/// Deserialized flake.lock file.
#[non_exhaustive]
#[derive(Deserialize, Debug, Clone)]
pub(crate) struct FlakeLock {
    pub(crate) version: u32,
    pub(crate) nodes: AllLockNodes,
}

#[derive(Deserialize, Debug, Clone)]
pub(crate) struct AllLockNodes(BTreeMap<NodeID, NodeWithInputs>);

/// Unique identifier of a flake input, as defined in `flake.lock`.
///
/// For example, if there are multiple inputs named `nixpkgs`, they might be
/// represented as "nixpkgs" and "nixpkgs_2" in `flake.lock`.
#[derive(
    Deserialize,
    Serialize,
    derive_more::Display,
    derive_more::From,
    Debug,
    Clone,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
)]
struct NodeID(String);

/// "Flattened" flake inputs as specified in `flake.lock`.
///
/// Each flake input is a map from a user facing, user friendly name to
/// an actual `FlakeNode`.
#[non_exhaustive]
#[derive(Deserialize, Debug, Clone)]
struct NodeWithInputs {
    inputs: Option<BTreeMap<String, FlakeNode>>,
}

/// Flake input node, either an ID (resolved) or a link to another input
/// (unresolved).
#[derive(Deserialize, Serialize, Debug, Clone)]
#[serde(untagged)]
enum FlakeNode {
    Id(NodeID),
    Link(NodeLink),
}

/// Link to another flake input, used for the `.follows` redirection.
///
/// For example, `follows = "nix-darwin/nixpkgs"` is represented as
/// `["nix-darwin", "nixpkgs"]`.
#[derive(Deserialize, Serialize, Debug, Clone)]
struct NodeLink(Vec<String>);

impl Display for NodeLink {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0.join("/"))
    }
}

#[derive(Serialize, Debug, Clone)]
pub(crate) struct ResolvedInput {
    name: String,
    follows: FlakeNode,
    id: NodeID,
}

impl Display for ResolvedInput {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}{}",
            self.id,
            if self.name != self.id.0 {
                format!(" <- {}", self.name)
            } else {
                "".into()
            }
        )
    }
}

#[derive(Debug, Clone)]
struct ResolvedInputsMap(BTreeMap<String, ResolvedInput>);

fn error_key_not_found(key: impl Display) -> anyhow::Error {
    anyhow::anyhow!("could not find flake input node {key}")
}

impl AllLockNodes {
    fn resolve_node(&self, node: FlakeNode) -> anyhow::Result<NodeID> {
        match node {
            FlakeNode::Id(id) => Ok(NodeID(id.0)),
            FlakeNode::Link(link) => {
                let link = link.0;
                if link.is_empty() {
                    bail!(
                        "found an input that follows an empty set; {}",
                        "this may be useful but is currently unsupported."
                    );
                }
                let toplevel_node = NodeID(link[0].clone());
                if link.len() == 1 {
                    return Ok(toplevel_node);
                }
                let inputs_ref = &link[1];
                let inputs = self
                    .0
                    .get(&toplevel_node)
                    .ok_or_else(|| error_key_not_found(toplevel_node))?
                    .inputs
                    .clone()
                    .unwrap_or_default();
                let resolved_node = inputs
                    .get(inputs_ref)
                    .ok_or_else(|| error_key_not_found(inputs_ref))?
                    .clone();
                let mut new_link = match resolved_node {
                    FlakeNode::Id(id) => NodeLink(vec![id.0]),
                    FlakeNode::Link(link) => link,
                }
                .0;
                new_link.extend_from_slice(&link[2..]);
                let new_link = NodeLink(new_link);
                self.resolve_node(FlakeNode::Link(new_link))
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
                name: flake_ref.clone(),
                follows: flake_node.clone(),
                id: self.resolve_node(flake_node)?,
            };
            resolved_inputs.insert(flake_ref.clone(), resolved);
        }
        Ok(ResolvedInputsMap(resolved_inputs))
    }

    fn resolve_all(&self) -> anyhow::Result<BTreeMap<NodeID, ResolvedInputsMap>> {
        let mut all_resolved = BTreeMap::new();
        for (node, _) in self.0.clone() {
            all_resolved.insert(node.clone(), self.resolve_inputs(&node)?);
        }
        Ok(all_resolved)
    }

    pub(crate) fn make_tree(&self) -> anyhow::Result<termtree::Tree<ResolvedInput>> {
        let all_resolved = self.resolve_all()?;
        make_tree(
            &all_resolved,
            ResolvedInput {
                name: "root".to_string(),
                follows: FlakeNode::Id(NodeID("root".to_string())),
                id: NodeID("root".to_string()),
            },
        )
    }
}

fn make_tree(
    all_resolved: &BTreeMap<NodeID, ResolvedInputsMap>,
    resolved_input: ResolvedInput, // singlet
) -> anyhow::Result<termtree::Tree<ResolvedInput>> {
    let mut tree = Tree::new(resolved_input.clone());
    let inputs = all_resolved
        .get(&resolved_input.id)
        .ok_or_else(|| error_key_not_found(resolved_input.id))?;
    for (_, resolved_input) in inputs.0.clone() {
        tree.push(make_tree(all_resolved, resolved_input)?);
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
