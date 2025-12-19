{ config, pkgs, claude-code, ... }:

{
  home.stateVersion = "25.11";

  home.packages = [
    claude-code.packages.x86_64-linux.default
    pkgs.gh
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Joe Mitzman";
        email = "joemitz@gmail.com";
      };
      init.defaultBranch = "main";
      color.ui = "auto";
      core = {
        editor = "vim";
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
        helper = "store";
        "https://github.com".helper = "store";
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

  programs.bash = {
    enable = true;
    shellAliases = {
      # NH with auto-commit and auto-push: rebuild, commit, and push on success
      nhs = ''
        current_dir=$(pwd) && \
        cd /home/joemitz/nixos && \
        nh os switch && \
        exit_code=$? && \
        if [ $exit_code -eq 0 ]; then \
          if ! git diff --quiet || ! git diff --cached --quiet; then \
            generation=$(nixos-rebuild list-generations | grep current | awk '{print $1}') && \
            timestamp=$(date +"%Y-%m-%d %H:%M") && \
            git add -A && \
            git commit -m "nixos: rebuild generation $generation [$timestamp]

Changes:
$(git diff --cached --name-only | sed 's/^/- /')

Built with: nh os switch" && \
            echo "" && \
            echo "Changes committed. Pushing to remote..." && \
            git push && \
            echo "Successfully pushed to remote!" || \
            echo "Warning: Commit succeeded but push failed. Run 'git push' manually."; \
          else \
            echo "No configuration changes to commit"; \
          fi; \
        fi && \
        cd "$current_dir" && \
        exit $exit_code
      '';
    };
  };
}
