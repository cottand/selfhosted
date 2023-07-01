{ config, pkgs, ... }: {

  environment.systemPackages = [ pkgs.udp2raw ];

  systemd.services."udp2raw" = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = ''
      ${pkgs.udp2raw} -s -l 0.0.0.0:9898 -r 127.0.0.1:51820 \
      -k 'pass' --auth-mode hmac_sha1 --raw-mode faketcp \
      -a --fix-gro --cipher-mode xor %u '';
  };

  networking.firewall.allowedTCPPorts = [ 9898 ];
}
