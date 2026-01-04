use std::{collections::BTreeMap, fmt::Display};

use anyhow::bail;
use serde::{Deserialize, Serialize};
use termtree::Tree;

const FLAKE_TOPLEVEL_NODE: &str = "root";

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
    #[serde(skip)]
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
    /// Resolves a single FlakeNode into a unique node ID.
    ///
    /// This function is recursive since the `.follows` NodeLink
    /// is recursive by its nature.
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

    /// Resolves flake inputs starting from a top level node.
    fn resolve_inputs(&self, node: &NodeID) -> anyhow::Result<ResolvedInputsMap> {
        let inputs = &self
            .0
            .get(node)
            .ok_or_else(|| error_key_not_found(&node.0))?
            .inputs;
        let mut resolved_inputs = BTreeMap::new();
        for (flake_ref, flake_node) in inputs.clone().unwrap_or_default() {
            let resolved = ResolvedInput {
                name: flake_ref.clone(),
                follows: flake_node.clone(),
                id: self.resolve_node(flake_node)?,
            };
            resolved_inputs.insert(flake_ref, resolved);
        }
        Ok(ResolvedInputsMap(resolved_inputs))
    }

    /// Resolves all top level flake inputs.
    fn resolve_all(&self) -> anyhow::Result<BTreeMap<NodeID, ResolvedInputsMap>> {
        let mut all_resolved = BTreeMap::new();
        for (node, _) in self.0.clone() {
            all_resolved.insert(node.clone(), self.resolve_inputs(&node)?);
        }
        Ok(all_resolved)
    }

    /// Turns the resolved inputs into a [`termtree::Tree<ResolvedInput>`].
    pub(crate) fn make_tree(&self) -> anyhow::Result<termtree::Tree<ResolvedInput>> {
        let all_resolved = self.resolve_all()?;
        let root = FLAKE_TOPLEVEL_NODE.to_string();
        make_tree(
            &all_resolved,
            ResolvedInput {
                name: root.clone(),
                follows: FlakeNode::Id(NodeID(root.clone())),
                id: NodeID(root.clone()),
            },
        )
    }
}

fn make_tree(
    all_resolved: &BTreeMap<NodeID, ResolvedInputsMap>,
    resolved_input: ResolvedInput,
) -> anyhow::Result<termtree::Tree<ResolvedInput>> {
    let mut tree = Tree::new(resolved_input.clone());
    let inputs = all_resolved
        .get(&resolved_input.id)
        .ok_or_else(|| error_key_not_found(resolved_input.id))?;
    for (_flake_ref, resolved_input) in inputs.0.clone() {
        tree.push(make_tree(all_resolved, resolved_input)?);
    }
    Ok(tree)
}
