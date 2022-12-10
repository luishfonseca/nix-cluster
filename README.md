# Nix Clustering Framework

This flake enables the development of NixOS machine clusters. Key features include:

- **Stateless** - The node's root stays on RAM, no state gets written to the disk.
- **Testable** - A single command to run all nodes as VMs.

## Local Running

First setup the network:

```
nix run .#network
```

Run only a specific node:

```
nix run .#node1
```

Run all nodes:

```
nix run
```
