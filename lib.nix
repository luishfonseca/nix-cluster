{ pkgs, lib, system, ... }: {
  nodeRunner = node:
    let
      inherit (node.config.system) build;
      inherit (lib.systems.parse.mkSystemFromString system) cpu;

      tap = "tap-${node.config.networking.hostName}";
    in
    pkgs.writeShellScript "node_runner.sh" ''
      ${pkgs.iproute2}/bin/ip link show ${tap} >/dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "Interface ${tap} does not exist. Is the network setup?"
        exit 1
      fi

      mac="52:54:00:$(${pkgs.iproute2}/bin/ip link show ${tap} | ${pkgs.gnugrep}/bin/grep -ohP '(?<=link/ether )\S+' | ${pkgs.coreutils}/bin/cut -d':' -f 4-)"
      init=$(${pkgs.gnugrep}/bin/grep -ohP 'init=\S+' ${build.netbootIpxeScript}/netboot.ipxe)

      qemu-system-${cpu.name} \
        -enable-kvm -cpu host -m 2G \
        -nographic -serial mon:stdio \
        -nic tap,ifname=${tap},script=no,downscript=no,mac=$mac \
        -kernel ${build.kernel}/bzImage -initrd ${build.netbootRamdisk}/initrd.zst \
        -append "$init console=ttyS0,115200"
    '';

  clusterRunner = nodes:
    let
      runners = lib.concatStringsSep "\n" (lib.mapAttrsToList
        (name: node: ''
          ${pkgs.tmux}/bin/tmux new-window -n ${name} -t cluster '${lib.my.nodeRunner node}'
        '')
        nodes);
    in
    pkgs.writeShellScript "cluster_runner.sh" ''
      ${pkgs.tmux}/bin/tmux kill-session -t cluster 2> /dev/null
      ${pkgs.tmux}/bin/tmux new-session -d -s cluster
      ${runners}
      ${pkgs.tmux}/bin/tmux select-window -t cluster:0
      ${pkgs.tmux}/bin/tmux attach-session -t cluster
    '';

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

  setupNetwork = nodes: { bridge, gateway, cidr, dhcpRange }:
    let
      netmask = lib.concatMapStringsSep "." toString (lib.my.cidrToMask cidr);
      network = lib.concatMapStringsSep "." toString (lib.zipListsWith lib.bitAnd (map lib.toInt (lib.splitString "." gateway)) (lib.my.cidrToMask cidr));

      taps = lib.concatStringsSep "\n" (lib.mapAttrsToList
        (_: node: ''
          ${pkgs.iproute2}/bin/ip link del tap-${node.config.networking.hostName} 2>/dev/null

          ${pkgs.iproute2}/bin/ip tuntap add tap-${node.config.networking.hostName} mode tap
          ${pkgs.iproute2}/bin/ip link set tap-${node.config.networking.hostName} up
          ${pkgs.iproute2}/bin/ip link set tap-${node.config.networking.hostName} master ${bridge}
        '')
        nodes);
    in
    pkgs.writeShellScript "setup_network.sh" ''
      if [ "$EUID" -ne 0 ]; then
        echo "Please run this as root or with sudo."
        exit 2
      fi

      ${pkgs.iproute2}/bin/ip link del ${bridge} 2>/dev/null

      ${pkgs.iproute2}/bin/ip link add ${bridge} type bridge
      ${pkgs.iproute2}/bin/ip link set ${bridge} up
      ${pkgs.iproute2}/bin/ip addr add ${gateway}/${toString cidr} dev ${bridge}

      ${taps}

      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${network}/${netmask} -j MASQUERADE 2>/dev/null

      echo 1 > /proc/sys/net/ipv4/ip_forward
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${network}/${netmask} -j MASQUERADE

      pkill -f dnsmasq-cluster 2>/dev/null

      exec -a dnsmasq-cluster ${pkgs.dnsmasq}/bin/dnsmasq --strict-order --conf-file="" \
      --except-interface=lo --interface=${bridge} --port=0 \
      --listen-address=${gateway} --bind-interfaces \
      --dhcp-range=${dhcpRange},${netmask} --dhcp-option=3,${gateway} \
      --dhcp-leasefile=/dev/null --dhcp-no-override --dhcp-sequential-ip
    '';

  mkNodePackage = (name: node: pkgs.symlinkJoin {
    inherit name;
    paths = with node.config.system.build; [
      netbootRamdisk
      kernel
      netbootIpxeScript
    ];
  });

  mkApp = path: { type = "app"; program = "${path}"; };

  mkNode = (name: modules: lib.nixosSystem {
    inherit system pkgs lib;
    modules = [
      ({ modulesPath, ... }: {
        imports = [ (modulesPath + "/installer/netboot/netboot.nix") ];
        networking.hostName = name;
        system.stateVersion = lib.versions.majorMinor lib.version; # State is not persisted so this can always be latest.
      })
    ] ++ modules;
  });
}

