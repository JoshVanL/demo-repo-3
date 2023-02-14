{ pkgs, gomod2nix, src }:

let
  checkgomod2nix = pkgs.writeShellApplication {
    name = "check-gomod2nix";
    runtimeInputs = [ gomod2nix ];
    text = ''
      tmpdir=$(mktemp -d)
      trap 'rm -rf -- "$tmpdir"' EXIT
      gomod2nix --dir ${src} --outdir "$tmpdir"
      if ! diff -q "$tmpdir/gomod2nix.toml" ${src}/gomod2nix.toml; then
        echo '>> gomod2nix.toml is not up to date. Please run:'
        echo '>> $ nix run .#update'
        exit 1
      fi
      echo '>> gomod2nix.toml is up to date'
    '';
  };

  genproto = pkgs.writeShellApplication {
    name = "update-proto";
    runtimeInputs = [ pkgs.protoc-gen-go ];
    text = ''
      protoc --go_out="$1" --go_opt=paths=source_relative \
        --go-grpc_out="$1" --go-grpc_opt=paths=source_relative \
        pkg/proto/hello/v1alpha1/hello.proto
    '';
  };

  checkproto = pkgs.writeShellApplication {
    name = "check-proto";
    runtimeInputs = [ genproto ];
    text = ''
      tmpdir=$(mktemp -d)
      trap 'rm -rf -- "$tmpdir"' EXIT
      update-proto "$tmpdir"
      a='./'
      b="$tmpdir"
      for ((n=0;n<2;n++)); do
        for f in $(find "$a" -name "*.pb.go" | grep -oP "^$a/\K.*"); do
          if ! diff -q "$a/$f" "$b/$f"; then
            echo '>> proto files are not up to date. Please run:'
            echo '>> $ nix run .#update'
            exit 1
          fi
        done
        a="$tmpdir"
        b='./'
      done
      echo '>> proto files are up to date'
    '';
  };

  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = [
      genproto
      gomod2nix
    ];
    text = ''
      update-proto .
      gomod2nix
      echo '>> Updated. Please commit the changes.'
    '';
  };

  check = pkgs.writeShellApplication {
    name = "check";
    runtimeInputs = [
      checkgomod2nix
      checkproto
    ];
    text = ''
      check-proto
      check-gomod2nix
    '';
  };

in {
  update = {type = "app"; program = "${update}/bin/update";};
  check = {type = "app"; program = "${check}/bin/check";};
}
