{ ... } @ args:
let
  inherit (args) lib;

  listModulesRecursive = dir: lib.filter
    (p: lib.hasSuffix ".nix" p && !(lib.hasPrefix "_" p))
    (lib.filesystem.listFilesRecursive dir);
in
{
  my = { inherit listModulesRecursive; } //
    (lib.foldr (p: acc: acc // (import p args)) { } (listModulesRecursive ./.));
}
