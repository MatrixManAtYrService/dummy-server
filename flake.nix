{
  description = "A simple FastAPI server with structured logging demo";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, uv2nix, pyproject-nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        python = pkgs.python312;

        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = ./.;
        };

        pyprojectOverlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope (
          nixpkgs.lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            pyprojectOverlay
          ]
        );

        editableOverlay = workspace.mkEditablePyprojectOverlay {
          root = "$REPO_ROOT";
        };

        editableHatchling = final: prev: {
          dummyserver = prev.dummyserver.overrideAttrs (old: {
            nativeBuildInputs =
              old.nativeBuildInputs
              ++ final.resolveBuildSystem {
                editables = [ ];
              };
          });
        };

        editablePythonSet = pythonSet.overrideScope (
          nixpkgs.lib.composeManyExtensions [
            editableOverlay
            editableHatchling
          ]
        );

        pythonEnv = pythonSet.mkVirtualEnv "dummyserver" workspace.deps.default;
        
        # Create wrapper scripts for subcommands
        serveScript = pkgs.writeShellScriptBin "dummyserver-serve" ''
          exec ${pythonEnv}/bin/dummyserver serve "$@"
        '';
        
        openapiScript = pkgs.writeShellScriptBin "dummyserver-openapi" ''
          exec ${pythonEnv}/bin/dummyserver openapi "$@"
        '';
      in
      {
        packages = {
          default = pythonEnv;
          codegen = pkgs.callPackage ./nix/codegen.nix { };
          nix-analysis = pkgs.callPackage ./nix/nix-analysis.nix { };
          python-analysis = pkgs.callPackage ./nix/python-analysis.nix { };
        };

        apps = rec {
          serve = {
            type = "app";
            program = "${serveScript}/bin/dummyserver-serve";
          };
          openapi = {
            type = "app";
            program = "${openapiScript}/bin/dummyserver-openapi";
          };
          default = serve;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (editablePythonSet.mkVirtualEnv "dummyserver" workspace.deps.all)
            uv
          ];
          env = {
            UV_NO_SYNC = "1";
            UV_PYTHON = python.interpreter;
            UV_PYTHON_DOWNLOADS = "never";
          };
          shellHook = ''
            export REPO_ROOT=$(pwd)
          '';
        };
      });
}
