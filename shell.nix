{ mkShell
, scripts
, pkgs
, ...
}: mkShell {
  name = "selfhosted-dev";
  packages = [
    # terraform and admin
    pkgs.terraform
    pkgs.vault
    pkgs.nomad_1_9
    pkgs.consul
    pkgs.bws

    # gcloud + components
    # see https://nixos.wiki/wiki/Google_Cloud_SDK
    (pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [ ]))

    pkgs.colmena
    pkgs.fish
    pkgs.seaweedfs
    pkgs.wander
    pkgs.attic
    pkgs.grpcurl

    # for development
    pkgs.go
    pkgs.pkg-config
    # Nix pinned in order to be able to compile Nixmad
    pkgs.nixVersions.nix_2_19


    scripts.nixmad
    scripts.bws-get
    scripts.keychain-get
    scripts.gen-protos

    pkgs.protoc-gen-go
  ];
  shellHook = ''
    export BWS_ACCESS_TOKEN=$(security find-generic-password -gw -l "bitwarden/secret/m3-cli")
    fish --init-command 'abbr -a weeds "nomad alloc exec -i -t -task seaweed-filer -job seaweed-filer weed shell -master seaweed-master-http.nomad:9333" ' && exit
  '';

  NOMAD_ADDR = "https://inst-kzsrv-control.golden-dace.ts.net:4646";
  CONSUL_ADDR = "https://inst-kzsrv-control.golden-dace.ts.net:8501";
  VAULT_ADDR = "https://vault.dcotta.com:8200";

  NIX_PATH = "";
}
