{ mkShell
, scripts
, pkgs
, self
, ...
}: mkShell {
  name = "selfhosted-dev";
  packages = [
    # terraform and admin
    pkgs.terraform
    pkgs.vault-bin
    pkgs.nomad
    pkgs.consul
    pkgs.bws
    pkgs.postgresql
    pkgs.mqttui
    pkgs.nix-diff
    pkgs.awscli

    # gcloud + components
    # see https://nixos.wiki/wiki/Google_Cloud_SDK
    (pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [ ]))

    pkgs.colmena
    pkgs.fish
    #pkgs.seaweedfs
    pkgs.wander
    pkgs.attic-client
    pkgs.attic-server # has atticadm CLI
    pkgs.grpcurl

    # for development
    pkgs.go
    pkgs.pkg-config
    self.inputs.go-overlay.packages.${pkgs.stdenv.hostPlatform.system}.govendor
    # Nix pinned in order to be able to compile Nixmad
    #    pkgs.nixVersions.nix_2_19
    # until https://nixpkgs-tracker.ocfox.me/?pr=356133 lands
    pkgs.nixVersions.latest


    scripts.bws-get
    scripts.keychain-get
    scripts.gen-protos

    pkgs.oapi-codegen

    pkgs.protoc-gen-go
  ];
  shellHook = ''
    export BWS_ACCESS_TOKEN=$(security find-generic-password -gw -l "bitwarden/secret/m3-cli")
    fish \
        --init-command 'abbr -a weeds "nomad alloc exec -i -t -task seaweed-filer -job seaweed-filer weed shell -master seaweed-master-http.nomad:9333" ' \
        --init-command 'abbr -a ship --set-cursor  "nix eval .#nomadJobs.% --json | nomad run -json -" ' \
        && exit
  '';

  NOMAD_ADDR = "https://nomad.dcotta.com";
  CONSUL_ADDR = "https://consul.dcotta.com";

  VAULT_ADDR = "https://vault.dcotta.com:8200";

  NIX_PATH = "";

  # see https://github.com/hashicorp/terraform/issues/36704#issuecomment-2745044595
  AWS_REQUEST_CHECKSUM_CALCULATION = "when_required";
  AWS_RESPONSE_CHECKSUM_VALIDATION = "when_required";

  # ensure you specify the endpoints in terraform if dealing with actual AWS as opposed to B2
  AWS_ENDPOINT_URL_S3 = "https://s3.us-east-005.backblazeb2.com";

  NIX_SSHOPTS = "-o ControlMaster=no";
}
