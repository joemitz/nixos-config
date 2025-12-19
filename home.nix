{ config, pkgs, claude-code, ... }:

{
  home.stateVersion = "25.11";

  home.packages = [
    claude-code.packages.x86_64-linux.default
  ];

  programs.git = {
    enable = true;
    userName = "Joe Mitzman";
    userEmail = "joemitz@gmail.com";

    extraConfig = {
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
    };

    aliases = {
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
}
