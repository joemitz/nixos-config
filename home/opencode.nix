_:

{
  # opencode reads ANTHROPIC_API_KEY from the environment automatically
  # (sourced from ~/.config/secrets.env), so no auth.json/apiKey needed here.
  home.file.".config/opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = "anthropic/claude-sonnet-5";
  };
}
