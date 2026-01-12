{ config, ... }:

{
  # sops-nix secrets management
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/persist-dotfiles/home/joemitz/.config/sops/age/keys.txt";

    # Define secrets and their output paths
    secrets = {
      "npm_token" = { owner = "joemitz"; };
      "gemini_api_key" = { owner = "joemitz"; };
      "openai_api_key" = { owner = "joemitz"; };
      "anthropic_api_key" = { owner = "joemitz"; };
      "circleci_token" = { owner = "joemitz"; };
      "android_release_keystore_password" = { owner = "joemitz"; };
      "android_release_key_password" = { owner = "joemitz"; };
      "android_keystore_password" = { owner = "joemitz"; };
      "apc_wss_admin_bearer_token" = { owner = "joemitz"; };
      "apc_wss_firebase_admin_config" = { owner = "joemitz"; };
      "apc_wss_a3_pg_password" = { owner = "joemitz"; };
      "borg_passphrase" = { owner = "root"; mode = "0400"; };
      "kopia_server_password" = { owner = "root"; mode = "0400"; };
    };

    # Create a templated secrets.env file for bash to source
    templates."secrets.env" = {
      owner = "joemitz";
      path = "/home/joemitz/.config/secrets.env";
      content = ''
        export NPM_TOKEN="${config.sops.placeholder.npm_token}"
        export GEMINI_API_KEY="${config.sops.placeholder.gemini_api_key}"
        export OPENAI_API_KEY="${config.sops.placeholder.openai_api_key}"
        export ANTHROPIC_API_KEY="${config.sops.placeholder.anthropic_api_key}"
        export CIRCLECI_TOKEN="${config.sops.placeholder.circleci_token}"
        export ANDROID_RELEASE_KEYSTORE_PASSWORD="${config.sops.placeholder.android_release_keystore_password}"
        export ANDROID_RELEASE_KEY_PASSWORD="${config.sops.placeholder.android_release_key_password}"
        export ANDROID_RELEASE_KEY_ALIAS="release-key"
        export ANDROID_KEYSTORE_ALIAS="Anova"
        export ANDROID_KEYSTORE_PASSWORD="${config.sops.placeholder.android_keystore_password}"
        export APC_WSS_ADMIN_BEARER_TOKEN="${config.sops.placeholder.apc_wss_admin_bearer_token}"
        export APC_WSS_FIREBASE_ADMIN_CONFIG="${config.sops.placeholder.apc_wss_firebase_admin_config}"
        export APC_WSS_GOOGLE_KMS_A3_SECRET_KEYRING="apc-wss-server"
        export APC_WSS_GOOGLE_KMS_A3_SECRET_KEY_NAME="a3-secret-encryption-key"
        export APC_WSS_A3_PG_HOST="anova-postgres-prod.cvgbnekce97r.us-west-2.rds.amazonaws.com"
        export APC_WSS_A3_PG_PORT="5432"
        export APC_WSS_A3_PG_USER="root"
        export APC_WSS_A3_PG_PASSWORD="${config.sops.placeholder.apc_wss_a3_pg_password}"
        export APC_WSS_A3_PG_DATABASE="anova_core_production"
      '';
    };
  };
}
