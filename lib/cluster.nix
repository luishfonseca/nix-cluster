{ pkgs, lib, system, root, ... }: {

  mkNodePackage = (name: node: pkgs.symlinkJoin {
    inherit name;
    paths = with node.config.system.build; [
      netbootRamdisk
      kernel
      netbootIpxeScript
    ];
  });

  mkApp = path: { type = "app"; program = "${path}"; };

  mkNode = (name: config: lib.nixosSystem {
    inherit system pkgs lib;
    modules = [
      config
      ({ modulesPath, ... }: {
        imports = [ (modulesPath + "/installer/netboot/netboot.nix") ];
        networking.hostName = name;
        system.stateVersion = lib.versions.majorMinor lib.version; # State is not persisted so this can always be latest.
      })
    ] ++ (lib.my.listModulesRecursive "${root}/modules");
  });
}

