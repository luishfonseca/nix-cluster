{ self, ... } @ inputs: inputs.utils.lib.eachDefaultSystem (system:
  let
    pkgs = import inputs.nixpkgs { inherit system; };
    lib = inputs.nixpkgs.lib.extend (final: prev: import ./lib {
      inherit inputs pkgs system;
      lib = final;
      root = ./.;
    });

    nodes = lib.mapAttrs lib.my.mkNode {
      test1.cluster.virtual = true;
      test2.cluster.virtual = true;
    };

    nodePackages = lib.mapAttrs lib.my.mkNodePackage nodes;
  in
  {
    nixosConfigurations = nodes;

    packages = {
      default = pkgs.linkFarm "cluster" nodePackages;
    } // nodePackages;

    apps = {
      default = lib.my.mkApp (lib.my.clusterRunner nodes);
      network = lib.my.mkApp (lib.my.setupNetwork nodes {
        bridge = "br8";
        gateway = "10.225.0.254";
        cidr = 16;
        dhcpRange = "10.225.0.1,10.225.0.253";
      });
    } // lib.mapAttrs (name: node: lib.my.mkApp (lib.my.nodeRunner node)) nodes;
  }
)
