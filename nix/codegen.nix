{ pkgs, ... }:

let
  common = import ./common.nix { inherit pkgs; };
  inherit (common) makeCheck createAnalysisPackage;

  # Trim whitespace check
  trimWhitespaceCheck = makeCheck {
    name = "trim-whitespace";
    description = "Trim trailing whitespace from source files";
    dependencies = with pkgs; [ gnused findutils ];
    command = ''
      echo "Trimming trailing whitespace..."
      find . -type f \( -name "*.py" -o -name "*.toml" -o -name "*.nix" -o -name "*.md" \) \
        -not -path "./.*" -not -path "./result*" -not -path "./build*" -not -path "./dist*" \
        -exec sed -i 's/[[:space:]]*$//' {} \;
      echo "Whitespace trimming complete."
    '';
    verboseCommand = ''
      echo "Trimming trailing whitespace with verbose output..."
      find . -type f \( -name "*.py" -o -name "*.toml" -o -name "*.nix" -o -name "*.md" \) \
        -not -path "./.*" -not -path "./result*" -not -path "./build*" -not -path "./dist*" \
        -print -exec sed -i 's/[[:space:]]*$//' {} \;
      echo "Whitespace trimming complete."
    '';
  };
in
createAnalysisPackage {
  name = "codegen";
  description = "Code generation (whitespace cleanup)";
  checks = {
    trim-whitespace = trimWhitespaceCheck;
  };
}
