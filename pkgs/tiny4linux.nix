{ lib
, rustPlatform
, pkg-config
, makeWrapper
, fontconfig
, wayland
, libxkbcommon
, libGL
, vulkan-loader
, src
}:

rustPlatform.buildRustPackage {
  pname = "tiny4linux";
  version = "2.2.1";

  inherit src;

  # fetchCargoVendor passes unknown args through to vendorStaging via @args // removeAttrs.
  # preBuild runs before the crate downloads, so we patch fetch-cargo-vendor-util here to
  # add a proper User-Agent (crates.io blocks python-requests UA with 403; nixpkgs PR #512735).
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-ZURy8sn2ljW6qrLt5ILM8vnRKCUhYqWdy1s8pExDDnc=";
    preBuild = ''
      util=$(command -v fetch-cargo-vendor-util)
      dir=$(mktemp -d)
      cp "$util" "$dir/fetch-cargo-vendor-util"
      chmod +w "$dir/fetch-cargo-vendor-util"
      sed -i 's/session = requests\.Session()/session = requests.Session()\n    session.headers.update({"User-Agent": "nixpkgs-fetchCargoVendor (https:\/\/github.com\/NixOS\/nixpkgs)"})/' "$dir/fetch-cargo-vendor-util"
      export PATH="$dir:$PATH"
    '';
  };

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    fontconfig
    wayland
    libxkbcommon
    libGL
    vulkan-loader
  ];

  buildFeatures = [ "gui" "cli" ];

  postFixup = ''
    wrapProgram $out/bin/tiny4linux-gui \
      --set WGPU_BACKEND vulkan \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ wayland libxkbcommon libGL vulkan-loader ]}"
    wrapProgram $out/bin/tiny4linux-cli \
      --set WGPU_BACKEND vulkan \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ wayland libxkbcommon libGL vulkan-loader ]}"
  '';

  meta = with lib; {
    description = "Linux controller for OBSBOT Tiny2 camera";
    homepage = "https://github.com/OpenFoxes/Tiny4Linux";
    license = licenses.eupl12;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "tiny4linux-gui";
  };
}
