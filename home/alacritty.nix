_:

{
  programs.alacritty = {
    enable = true;
    theme = "moonfly";
    settings = {
      font = {
        normal = {
          family = "Hack Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "Hack Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "Hack Nerd Font";
          style = "Italic";
        };
        size = 12.0;
      };
      colors.primary.background = "#000000";
      colors.normal.magenta = "#d79600";
      colors.bright.magenta = "#ffbf5f";
    };
  };
}
