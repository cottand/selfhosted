# https://nixos.wiki/wiki/Overlays
final: prev:
{
  consul = prev.buildGoModule rec {
    pname = "consul";
    version = "1.19.0";

    # Note: Currently only release tags are supported, because they have the Consul UI
    # vendored. See
    #   https://github.com/NixOS/nixpkgs/pull/48714#issuecomment-433454834
    # If you want to use a non-release commit as `src`, you probably want to improve
    # this derivation so that it can build the UI's JavaScript from source.
    # See https://github.com/NixOS/nixpkgs/pull/49082 for something like that.
    # Or, if you want to patch something that doesn't touch the UI, you may want
    # to apply your changes as patches on top of a release commit.
    src = prev.fetchFromGitHub {
      owner = "hashicorp";
      repo = pname;
      rev = "refs/tags/v${version}";
      hash = "sha256-GO2BfdozsAo1r4iSyQdAEG8Tm6OkJhSUrH3bZ9lWuO8=";
    };

    # This corresponds to paths with package main - normally unneeded but consul
    # has a split module structure in one repo
    subPackages = [
      "."
      "connect/certgen"
    ];

    vendorHash = "sha256-h3eTCj/0FPiY/Dj4cMj9VqKBs28ArnTPjRIC3LT06j0=";

    doCheck = false;

    ldflags = [
      "-X github.com/hashicorp/consul/version.GitDescribe=v${version}"
      "-X github.com/hashicorp/consul/version.Version=${version}"
      "-X github.com/hashicorp/consul/version.VersionPrerelease="
    ];
    meta.mainProgram = "consul";
    passthru = {
      tests = { inherit (prev.nixosTests) consul; };
      updateScript = prev.nix-update-script { };
    };
  };
}
