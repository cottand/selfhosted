{ mkShell
, scripts
, terraform
, colmena
, fish
, nomad_1_8
, consul
, vault
, seaweedfs
, wander
, attic
, bws
, go
, pkg-config
, nixVersions
, pkgs
, ...
}: mkShell {
  name = "selfhosted-dev";
  packages = [
    # roachdb
    terraform
    colmena
    fish
    vault
    nomad_1_8
    consul
    seaweedfs
    wander
    attic
    bws

    # for development
    go
    pkg-config
    nixVersions.latest


    scripts.nixmad
    scripts.bws-get
    scripts.keychain-get
    scripts.gen-protos

    pkgs.protoc-gen-go
  ];
  shellHook = ''
    export BWS_ACCESS_TOKEN=$(security find-generic-password -gw -l "bitwarden/secret/m3-cli")
    fish --init-command 'abbr -a weeds "nomad alloc exec -i -t -task seaweed-filer -job seaweed-filer weed shell -master 10.10.11.1:9333" ' && exit'';

  NOMAD_ADDR = "https://10.10.11.1:4646";
  #          VAULT_ADDR = "https://10.10.2.1:8200";
  VAULT_ADDR = "https://vault.mesh.dcotta.eu:8200";

  NIX_PATH="";
}
