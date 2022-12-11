{ ... } @ args:
let
  inherit (args) lib;

  mkModules = dir: lib.filter
    (p: lib.hasSuffix ".nix" p && !(lib.hasPrefix "_" p))
    (lib.filesystem.listFilesRecursive dir);
in
{
  my = { inherit mkModules; } //
    (lib.foldr (p: acc: acc // (import p args)) { } (mkModules ./.));
}
