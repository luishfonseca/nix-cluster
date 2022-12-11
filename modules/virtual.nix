{ config, options, lib, pkgs, modulesPath, ... }:

with lib;
let cfg = config.cluster.virtual; in
{
  options.cluster.virtual = mkEnableOption "Virtual Machine";

  config = mkIf cfg ({
    services.getty.autologinUser = "root";
  } // import (modulesPath + "/profiles/minimal.nix") { inherit config lib; }
  // import (modulesPath + "/profiles/qemu-guest.nix") { inherit config lib; });
}
