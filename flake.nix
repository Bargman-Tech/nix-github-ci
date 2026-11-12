{
  description = "GitHub Actions CI generation for NixOS flakes — mkCi library + workflow apps";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;
      ciLib = import ./lib/ci_library.nix { inherit lib pkgs; };
    in
    {
      lib = {
        # { self, lib, pkgs, parallelism?, fleet? }: →
        #   { ci = { github-actions; github-actions-filtered; machines; jobs }; }
        # Fleet data (machine names, timeouts, scan excludes) is supplied by
        # the consumer — this repository carries no fleet data.
        mkCi = import ./lib/mk-ci.nix;

        # Raw builders for consumers that assemble their own workflow:
        #   ciLib = import nix-github-ci.lib.ciLibrary { inherit lib; pkgs = …; }
        ciLibrary = ./lib/ci_library.nix;
      };

      apps.${system} = {
        # Run from the CONSUMING flake's directory:
        #   nix run github:Bargman-Tech/nix-github-ci#generate-ci-workflow \
        #     > .github/workflows/ci.yml
        # (or re-export these apps from your own flake, gitlab-ci style)
        generate-ci-workflow = {
          type = "app";
          meta.description = "Generate GitHub Actions workflow from Nix evaluation";
          program = "${ciLib.generateWorkflowScript { }}/bin/generate-ci-workflow";
        };
        validate-ci-workflow = {
          type = "app";
          meta.description = "Validate GitHub Actions workflow";
          program = "${ciLib.validateWorkflowScript}/bin/validate-ci-workflow";
        };
      };

      checks.${system} = {
        formatting = pkgs.runCommand "check-formatting"
          { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; }
          ''
            nixpkgs-fmt --check ${self} && touch $out
          '';
        deadnix = pkgs.runCommand "check-deadnix"
          { nativeBuildInputs = [ pkgs.deadnix ]; }
          ''
            deadnix --fail --no-lambda-arg --no-lambda-pattern-names ${self} && touch $out
          '';
      };
    };
}
