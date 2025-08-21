{ pkgs, ... }:

let
  common = import ./common.nix { inherit pkgs; };
  inherit (common) makeCheck createAnalysisPackage;

  # Wrapper script for nixpkgs-fmt that exits non-zero if files were reformatted
  nixpkgs-fmt-exit-on-format = pkgs.writeShellScriptBin "nixpkgs-fmt-exit-on-format" ''
    # Run nixpkgs-fmt and capture output
    output=$(${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt "$@" 2>&1)
    echo "$output"

    # Check if any files were reformatted (look for non-zero count)
    if echo "$output" | tail -1 | grep -v "^0 /" > /dev/null; then
      echo "Files were reformatted"
      exit 1
    else
      echo "No formatting changes needed"
    fi
  '';

  # Individual check definitions
  deadnixCheck = makeCheck {
    name = "deadnix";
    description = "Nix dead code analysis";
    dependencies = with pkgs; [ deadnix ];
    command = "deadnix -q .";
    verboseCommand = "deadnix .";
  };

  nixpkgsFmtCheck = makeCheck {
    name = "nixpkgs-fmt";
    description = "Nix file formatting";
    dependencies = with pkgs; [ nixpkgs-fmt nixpkgs-fmt-exit-on-format ];
    roots = [ "." ];
    command = "nixpkgs-fmt-exit-on-format .";
    verboseCommand = "nixpkgs-fmt-exit-on-format .";
  };

  statixCheck = makeCheck {
    name = "statix";
    description = "Nix static analysis";
    dependencies = with pkgs; [ statix ];
    command = "statix check .";
    verboseCommand = "statix check .";
  };
in
createAnalysisPackage {
  name = "nix-analysis";
  description = "Nix code analysis";
  checks = {
    deadnix = deadnixCheck;
    nixpkgs-fmt = nixpkgsFmtCheck;
    statix = statixCheck;
  };
}
