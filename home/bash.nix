{ config, pkgs, ... }:

{
  programs.bash = {
    enable = true;
    shellAliases = {
      code = "codium";
      c = "claude";
      nano = "micro";
      ls = "eza";
      top = "btop";
      zzz = "systemctl suspend";
      nhs = "_nh_rebuild_commit switch";
      nhb = "_nh_rebuild_commit boot";
    };
    sessionVariables = {
      # Non-secret environment variables
      NODE_ENV = "development";
      DEVICE_IP = "192.168.0.249";
      HUSKY = "0";

      # Android SDK paths
      ANDROID_HOME = "$HOME/Android/Sdk";
    };
    initExtra = ''
      # Source alias file if it exists
      test -s ~/.alias && . ~/.alias || true

      # Java home for Gradle
      export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

      # Android SDK path additions
      export PATH=$PATH:$ANDROID_HOME/emulator
      export PATH=$PATH:$ANDROID_HOME/platform-tools

      # Load secrets from sops
      if [ -f ~/.config/secrets.env ]; then
        set -a
        source ~/.config/secrets.env
        set +a
      fi

      # NH rebuild with auto-commit function
      _nh_rebuild_commit() {
        local mode=$1
        local current_dir=$(pwd)

        cd /home/joemitz/nixos-config
        nh os $mode /home/joemitz/nixos-config
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
          if ! git diff --quiet || ! git diff --cached --quiet; then
            claude -p "Check git diff and them complete both of these 2 tasks: 1) Edit /home/joemitz/nixos-config/CLAUDE.md with any changes 2) Write a 5-10 word lowercase commit description to /home/joemitz/nixos-config/nhs-commit-msg.txt (e.g. 'enable nix-ld for android tools')" --model haiku --allowedTools "Edit" "Write" "Read" "Bash(git diff:*)" && \
            local commit_msg=$(cat /home/joemitz/nixos-config/nhs-commit-msg.txt) && \
            local generation=$(nixos-rebuild list-generations | grep True | awk '{print $1}') && \
            rm /home/joemitz/nixos-config/nhs-commit-msg.txt && \
            git add -A && \
            git commit -m "Gen $generation: $commit_msg" && \
            echo "Changes committed. Pushing to remote..." && \
            git push && \
            echo "Successfully pushed to remote!" || \
            echo "Warning: Commit succeeded but push failed. Run 'git push' manually."
          else
            echo "No configuration changes to commit"
          fi
        fi

        cd "$current_dir"
      }

      # Auto-attach to main tmux session
      if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
        # Try to attach to main session, create if doesn't exist
        tmux attach-session -t main || tmux new-session -s main
      fi
    '';
  };
}
