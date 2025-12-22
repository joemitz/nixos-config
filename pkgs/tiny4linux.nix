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

rustPlatform.buildRustPackage rec {
  pname = "tiny4linux";
  version = "2.2.2";

  inherit src;

  cargoHash = "sha256-2o65VzfjOAgTrjFDmSBbooHw+obVTKd+DXeF4tgm7Qg=";

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

  # Wrap binaries with proper library paths
  postFixup = ''
    wrapProgram $out/bin/tiny4linux-gui \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ wayland libxkbcommon libGL vulkan-loader ]}"
    wrapProgram $out/bin/tiny4linux-cli \
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
