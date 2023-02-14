{
  description = "Hello World!";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";

    gomod2nix = {
      url = "github:tweag/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "utils";
    };
  };

  outputs = { self, nixpkgs, utils, gomod2nix }:
  let
    targetSystems = with utils.lib.system; [
      x86_64-linux
      x86_64-darwin
      aarch64-linux
      aarch64-darwin
    ];

    # We only source go files to have better cache hits when actively working
    # on non-go files.
    src = nixpkgs.lib.sourceFilesBySuffices ./. [ ".go" "go.mod" "go.sum" "gomod2nix.toml" ];

  in utils.lib.eachSystem targetSystems (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            go = prev.go_1_20;
            buildGoApplication = prev.buildGo120Application;
          })

          gomod2nix.overlays.default
        ];
      };

      hello-world = pkgs.buildGoApplication {
        name = "hello-world";
        modules = ./gomod2nix.toml;
        inherit src;
        postInstall = "mv $out/bin/repo-3 $out/bin/hello-world";
      };

      ci = import ./nix/ci.nix {
        inherit pkgs;
        gomod2nix = (gomod2nix.packages.${system}.default);
        inherit src;
      };

    in {
      packages = {
        default = hello-world;
        hello-world = hello-world;
      };

      apps = {
        check = ci.check;
        update = ci.update;
        default = {type = "app"; program = "${hello-world}/bin/hello-world"; };
      };

      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go
          gopls
          gotools
          go-tools
          gomod2nix.packages.${system}.default
          protoc-gen-go
        ];
      };
  });
}
