# Nix Clustering Framework

This flake enables the development of NixOS machine clusters. Key features include:

- **Stateless** - The system stays on memory, no state gets written to the disk.
- **Testable** - Run all systems as VMs with a single command.

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
