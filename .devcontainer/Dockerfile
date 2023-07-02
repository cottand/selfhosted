FROM  --platform=linux/amd64 nixos/nix:2.15.1

COPY nix.conf /etc/nix/nix.conf

RUN nix-channel --update
RUN nix-env --install --attr nixpkgs.vim
RUN nix-env --install --attr nixpkgs.morph


# RUN nix-build -A pythonFull '<nixpkgs>'