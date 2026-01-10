{ ... }:

{
  programs.tmux = {
    enable = true;
    clock24 = true;
    historyLimit = 10000;
    mouse = true;

    extraConfig = ''
      # Update environment variables for GUI apps
      set -g update-environment "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR"

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
}
