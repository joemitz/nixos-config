{ lib
, stdenvNoCC
, fetchurl
}:

# nixpkgs lags upstream releases; devbox 0.18.0 removed the Jetify Cloud
# browser-login flow (devbox auth/cache/secrets) that broke when Jetify's
# login page went down, so we track the latest upstream binary release
# directly here instead of pkgs.devbox.
stdenvNoCC.mkDerivation rec {
  pname = "devbox";
  version = "0.18.3";

  src = fetchurl {
    url = "https://github.com/jetify-com/devbox/releases/download/${version}/devbox_${version}_linux_amd64.tar.gz";
    hash = "sha256-ssT4RNi2kXrI9lvNFF5I0EcFpUr8LYDjU++XkpvNxGY=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 devbox $out/bin/devbox
    runHook postInstall
  '';

  meta = with lib; {
    description = "Instant, easy, predictable shells and containers";
    homepage = "https://www.jetify.com/devbox";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "devbox";
  };
}
