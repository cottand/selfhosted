{ dockerTools, busybox, seaweedfs, cacert, ... }:
dockerTools.buildImage {
  name = "seaweedfs";
  tag = seaweedfs.version;
  copyToRoot = [
    # Debugging utilities for `fly ssh console`
    busybox
    seaweedfs
  ];
  config = {
    Entrypoint = [ "${seaweedfs}/bin/weed" ];
    Env = [
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
