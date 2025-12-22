{ lib
, rustPlatform
, pkg-config
, fontconfig
, wayland
, libxkbcommon
, libGL
, src
}:

rustPlatform.buildRustPackage rec {
  pname = "tiny4linux";
  version = "2.2.2";

  inherit src;

  cargoHash = "sha256-2o65VzfjOAgTrjFDmSBbooHw+obVTKd+DXeF4tgm7Qg=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    fontconfig
    wayland
    libxkbcommon
    libGL
  ];

  buildFeatures = [ "gui" "cli" ];

  # Ensure the binary can find Wayland libraries at runtime
  postInstall = ''
    patchelf --set-rpath "${lib.makeLibraryPath buildInputs}:$(patchelf --print-rpath $out/bin/tiny4linux-gui)" $out/bin/tiny4linux-gui || true
    patchelf --set-rpath "${lib.makeLibraryPath buildInputs}:$(patchelf --print-rpath $out/bin/tiny4linux-cli)" $out/bin/tiny4linux-cli || true
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
