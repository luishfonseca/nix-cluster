{ lib, ... }: {
  cidrToMask = cidr:
    let
      part = n: if n == 0 then 0 else part (n - 1) / 2 + 128;
      fullParts = cidr / 8;
    in
    lib.genList
      (i:
        if i < fullParts then 255
        else if fullParts < i then 0
        else part (lib.mod cidr 8)
      ) 4;

  maskIP = ip: cidr:
    lib.zipListsWith lib.bitAnd (map lib.toInt (lib.splitString "." ip)) (lib.my.cidrToMask cidr);
}
