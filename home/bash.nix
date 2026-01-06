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
      # NH with auto-commit and auto-push: rebuild, commit, and push on success
      nhs = ''
        current_dir=$(pwd) && \
        cd /home/joemitz/nixos-config && \
        nh os switch /home/joemitz/nixos-config && \
        exit_code=$? && \
        if [ $exit_code -eq 0 ]; then \
          if ! git diff --quiet || ! git diff --cached --quiet; then \
            generation=$(nixos-rebuild list-generations | grep True | awk '{print $1}') && \
            timestamp=$(date +"%Y-%m-%d %H:%M") && \
            git add -A && \
            git commit -m "generation $generation [$timestamp]" && \
            echo "" && \
            echo "Changes committed. Pushing to remote..." && \
            git push && \
            echo "Successfully pushed to remote!" || \
            echo "Warning: Commit succeeded but push failed. Run 'git push' manually."; \
          else \
            echo "No configuration changes to commit"; \
          fi; \
        fi && \
        cd "$current_dir"
      '';
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

      # Auto-attach to main tmux session
      if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
        # Try to attach to main session, create if doesn't exist
        tmux attach-session -t main || tmux new-session -s main
      fi
    '';
  };
}
