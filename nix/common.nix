# Common utilities for analysis packages
{ pkgs, ... }:

let
  # Create a check script that runs in current directory or multiple roots
  makeCheck = args:
    let
      name = args.name or (throw "makeCheck: 'name' is required");
      description = args.description or name;
      dependencies = args.dependencies or [ ];
      roots = args.roots or [ "." ]; # Default to current directory
      commandArg = args.command or (throw "makeCheck: 'command' is required");
      verboseCommandArg = args.verboseCommand or commandArg;
      checkGitChanges = args.checkGitChanges or false;
      rootsStr = builtins.concatStringsSep " " roots;

      # Wrap command with git change detection if requested
      wrapWithGitCheck = cmd: verbose:
        if checkGitChanges then ''
          # Store git status before command
          git_status_before=$(git status --porcelain ${rootsStr} || true)

          # Run the actual command
          ${cmd}
          command_exit_code=$?

          # Check git status after command
          git_status_after=$(git status --porcelain ${rootsStr} || true)

          if [[ "$git_status_before" != "$git_status_after" ]]; then
            echo "📝 Files were modified by ${name}:"
            echo "$git_status_after"

            if [[ "''${CI:-0}" == "1" ]]; then
              echo ""
              echo "❌ Files were out of date in CI!"
              echo "To fix this, run the analysis tools locally and commit the changes."
              exit 1
            else
              echo ""
              echo "✅ Files have been updated"
              echo "💡 Consider committing these changes"
            fi
          else
            echo "✅ No changes made by ${name}"
          fi

          # Return the original command's exit code
          exit $command_exit_code
        '' else cmd;

      wrappedCommand = wrapWithGitCheck commandArg false;
      wrappedVerboseCommand = wrapWithGitCheck verboseCommandArg true;

      # Generate commands for each root
      generateRootCommands = verbose:
        let
          cmdToUse = if verbose then wrappedVerboseCommand else wrappedCommand;
        in
        builtins.concatStringsSep "\n\n" (map
          (root: ''
            echo "Running ${name} in root: ${root}"
            cd "${root}"
            ${cmdToUse}
            cd - > /dev/null
          '')
          roots);

      # Basic environment setup
      environment = {
        LANG = "en_US.UTF-8";
        LC_ALL = "en_US.UTF-8";
        PYTHONIOENCODING = "utf-8";
      } // (args.environment or { });

      # Resolve dependencies with basic tools
      resolvedDeps = dependencies ++ (with pkgs; [ coreutils ]) ++ (if checkGitChanges then [ pkgs.git ] else [ ]);
    in
    {
      inherit name description roots;
      command = wrappedCommand;
      verboseCommand = wrappedVerboseCommand;
      scriptContent = ''
        # Set up environment variables
        ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: "export ${k}=${pkgs.lib.escapeShellArg (toString v)}") environment)}

        # Add dependencies to PATH
        export PATH="${pkgs.lib.concatStringsSep ":" (map (dep: "${dep}/bin") resolvedDeps)}:$PATH"

        # Store original directory
        original_dir=$(pwd)

        # Run the appropriate command based on verbose mode
        if [ "$verbose" = "true" ]; then
          ${generateRootCommands true}
        else
          ${generateRootCommands false}
        fi

        # Return to original directory
        cd "$original_dir"
      '';
    };

  # Generate a script that runs multiple checks
  generateAnalysisScript =
    { name
    , description ? "Code analysis"
    , checks ? { }
    }:
    let
      checkScripts = builtins.concatStringsSep "\n\n" (
        builtins.attrValues (builtins.mapAttrs
          (checkName: check: ''
            # ============================================================================
            # CHECK: ${checkName}
            # Description: ${check.description}
            # ============================================================================
            echo "================================================"
            echo "[${checkName}] ${check.description}"
            echo "================================================"

            # Start timing
            start_time=$(date +%s)

            # Execute the check script
            ${check.scriptContent}
            check_exit_code=$?

            # Calculate timing
            end_time=$(date +%s)
            duration=$((end_time - start_time))s

            # Report result
            if [ $check_exit_code -eq 0 ]; then
              echo "✅ ${check.description} - PASSED ($duration)"
            else
              echo "❌ ${check.description} - FAILED ($duration)"
              if [ -z "''${FAILED_CHECKS:-}" ]; then
                FAILED_CHECKS="${checkName}"
              else
                FAILED_CHECKS="''$FAILED_CHECKS,${checkName}"
              fi
            fi
          '')
          checks)
      );
    in
    ''
      set -euo pipefail

      verbose=false
      while getopts "v" opt; do
        case ''${opt} in
          v ) verbose=true;;
          \? ) echo "Usage: $0 [-v]"
               exit 1;;
        esac
      done

      export verbose

      # Initialize failed checks tracker
      FAILED_CHECKS=""

      echo "🔍 Running ${description}..."
      echo ""

      ${checkScripts}

      echo "================================================"
      if [ -z "$FAILED_CHECKS" ]; then
        echo "🎉 All ${description} checks passed!"
      else
        echo "❌ Some checks failed: $FAILED_CHECKS"
        exit 1
      fi
    '';

  # Create a runnable script package
  createAnalysisPackage = args:
    let
      scriptText = generateAnalysisScript args;
    in
    pkgs.writeShellScriptBin args.name scriptText;
in
{
  inherit makeCheck generateAnalysisScript createAnalysisPackage;
}
