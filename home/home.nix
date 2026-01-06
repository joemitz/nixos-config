{ config, pkgs, claude-code, tiny4linux, ... }:

{
  home.stateVersion = "25.11";

  home.packages = [
    (pkgs.callPackage ../pkgs/tiny4linux.nix { src = tiny4linux; })
    claude-code.packages.x86_64-linux.default
    pkgs.gh
    pkgs.jq
    pkgs.tmux
    pkgs.vscodium
    pkgs.postman
    pkgs.zoom-us
    pkgs.vorta
    pkgs.devbox
    pkgs.tidal-hifi
    pkgs.guvcview
    pkgs.vlc
    pkgs.remmina
    pkgs.android-studio
    pkgs.android-tools
    pkgs.patchelf
    pkgs.nodejs_24
    pkgs.kdePackages.kate
    pkgs.micro
    pkgs.btop
    pkgs.eza
    pkgs.bat
    pkgs.lazygit
  ];

  programs.git = {
    enable = true;
    package = pkgs.gitFull;  # Use gitFull for libsecret support
    settings = {
      user = {
        name = "Joe Mitzman";
        email = "joemitz@gmail.com";
      };
      init.defaultBranch = "main";
      color.ui = "auto";
      core = {
        editor = "micro";
        autocrlf = "input";
        safecrlf = true;
        hooksPath = "/dev/null";
      };
      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };
      credential = {
        helper = "libsecret";  # Store credentials in KDE Wallet
      };
      push.autoSetupRemote = true;
      alias = {
        co = "commit -m";
        st = "status";
        br = "branch";
        hi = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
        type = "cat-file -t";
        dump = "cat-file -p";
        pu = "push";
        ad = "add";
        ch = "checkout";
        cp = "!f() { git commit -m \"$1\" && git push; }; f";
        lb = "!git reflog show --pretty=format:'%gs ~ %gd' --date=relative | grep 'checkout:' | grep -oE '[^ ]+ ~ .*' | awk -F~ '!seen[$1]++' | head -n 10 | awk -F' ~ HEAD@{' '{printf(\"  \\033[33m%s: \\033[37m %s\\033[0m\\n\", substr($2, 1, length($2)-1), $1)}'";
        ma = "!sh -c 'branches=$(git branch --list {master,main} | grep -Eo \"\\b(master|main)\\b\" | tr -s \"\\n\" \" \") && git log --merges --pretty=format:\"%n %C(yellow) %h %C(reset) %C(green) %s %C(reset) %C(blue) %an %C(reset) %C(red) %ad %C(reset)\" --date=relative -30 --color $branches'";
      };
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "macbook" = {
        hostname = "192.168.0.232";
        user = "joemitz";
      };
    };
  };

  programs.firefox.enable = true;

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      code = "codium";
      c = "claude";
      nano = "micro";
      ls = "eza";
      cat = "bat";
      top = "btop";
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

  programs.tmux = {
    enable = true;
    clock24 = true;
    historyLimit = 10000;
    mouse = true;

    extraConfig = ''
      # Mouse wheel scroll
      bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
      bind -n WheelDownPane select-pane -t= \; send-keys -M

      # Custom keybindings
      bind h split-window -h    # Split horizontal with h
      bind v split-window -v    # Split vertical with v
      bind n new-window         # New window with n
      bind w kill-window        # Close window with w
      bind x kill-pane          # Close pane with x

      # Pane movement with arrow keys
      bind Right swap-pane -U   # Move pane left
      bind Up swap-pane -U      # Move pane up
      bind Down swap-pane -D    # Move pane down
      bind Left swap-pane -D    # Move pane right

      # Clear console with Ctrl+K
      bind -n C-k send-keys 'clear' Enter

      # Map Ctrl-_ to ESC [ Z (Shift-Tab)
      unbind -n C-_
      bind -n C-_ send-keys Escape '[' 'Z'

      # Enable status bar
      set -g status on
      set -g status-left "[#S] "
      set -g status-right ""
    '';
  };

  programs.alacritty = {
    enable = true;
    theme = "moonfly";
    settings = {
      colors.primary.background = "#000000";
    };
  };

  xdg.desktopEntries.guvcview = {
    name = "guvcview";
    exec = "guvcview -z";
    icon = "guvcview";
    terminal = false;
    categories = [ "AudioVideo" "Video" ];
    comment = "GTK UVC Viewer";
  };

  xdg.desktopEntries.tiny4linux = {
    name = "Tiny4Linux";
    exec = "tiny4linux-gui";
    icon = "camera-video";
    terminal = false;
    categories = [ "AudioVideo" "Video" ];
    comment = "Control OBSBOT Tiny2 camera";
  };

}
