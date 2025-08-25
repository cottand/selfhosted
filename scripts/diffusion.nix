{ pkgs
, stdenv
, lib
, ...
}:
let
  #  diffusion21 = pkgs.fetchgit {
  #    url = "https://huggingface.co/stabilityai/stable-diffusion-2-1";
  #    hash = "sha256-dyA0VMquJ98Pu5mPr6F2VvflgI+3jtocyh3XqQUGcTI=";
  #  };
  #
  model = pkgs.fetchurl {
    url = "https://huggingface.co/stabilityai/stable-diffusion-2-1/resolve/main/v2-1_768-ema-pruned.ckpt";
    hash = "sha256-rSozw2HB9ZPEofsy6oGvzitbt9GYPGuUeTomo7VLCKA=";
  };

  modelConfig = pkgs.fetchurl {
    url = "https://github.com/Stability-AI/stablediffusion/raw/main/configs/stable-diffusion/v2-midas-inference.yaml";
    hash = "sha256-muJMxgELvWApyH58AS44V0cCLmzkKI/6kBb4HVnT03Y=";
  };

  repoWithModel =
    stdenv.mkDerivation {
      pname = "selfhosted-diffusion-dev";
      version = "1.10.1";

      src = pkgs.fetchFromGitHub {
        # https://github.com/AUTOMATIC1111/stable-diffusion-webui
        owner = "AUTOMATIC1111";
        repo = "stable-diffusion-webui";
        rev = "v1.10.1";
        sha256 = "sha256-lY+fZQ9yzFBVX5hrmvaIAm/FaRnsIkB2z4WpcJMmL3w=";
      };

      configurePhase = ''
        cp -r ${model} ./models/Stable-diffusion/model-v2-1-768.ckpt
        cp -r ${modelConfig} ./models/Stable-diffusion/model-v2-1-768.yaml
        ls -la models/Stable-diffusion
      '';

      installPhase = ''
        mkdir -p $out
        cp -r . $out
      '';

    };
in
pkgs.writeShellApplication {
  name = "diffusion-webui";
  runtimeInputs = [
    pkgs.pkg-config
    pkgs.python310
    pkgs.cmake
    pkgs.protobuf
    pkgs.cargo
  ];
  text = ''
    ${repoWithModel}/webui.sh
  '';
}
