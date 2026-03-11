{
  description = "wsxwm — a Wayland window manager built on neuswc";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          neuwld = pkgs.stdenv.mkDerivation {
            pname = "neuwld";
            version = "unstable";
            src = pkgs.fetchgit {
              url = "https://git.sr.ht/~shrub900/neuwld";
              hash = "sha256-0+rgWrefh19bBEmcqw0Lal1PHkendtCkQ2EIg+LHb74=";
            };
            nativeBuildInputs = with pkgs; [
              pkg-config
              bmake
              wayland-scanner
            ];
            buildInputs = with pkgs; [
              pixman
              freetype
              libdrm
              wayland
            ];
            propagatedBuildInputs = with pkgs; [
              fontconfig
            ];
            patches = [ ./0001-add-whiskeylake-pci-ids.patch ];
            buildPhase = ''
              runHook preBuild
              bmake PREFIX=${placeholder "out"}
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              bmake PREFIX=${placeholder "out"} install
              runHook postInstall
            '';
          };
          neumenu = pkgs.stdenv.mkDerivation {
            pname = "neumenu";
            version = "unstable";
            src = pkgs.fetchgit {
              url = "https://git.sr.ht/~uint/neumenu";
              hash = "sha256-oASly6REP1EGV8jBROMZJR+Q8TrkVNKga4Yub37xjxo=";
            };
            nativeBuildInputs = with pkgs; [
              pkg-config
              bmake
            ];
            propagatedBuildInputs = with pkgs; [
              fontconfig
              pixman # ← add this
              wayland-scanner
            ];
            buildInputs = with pkgs; [
              neuswc # ← add this, provides swc.xml
              neuwld
              wayland
              wayland-scanner
              libxkbcommon
              fontconfig
              pixman
            ];
            preBuild = ''
              substituteInPlace config.mk \
                --replace "/usr/share/swc/swc.xml" "${neuswc}/share/swc/swc.xml"
            '';
            buildPhase = ''
              runHook preBuild
              bmake PREFIX=${placeholder "out"}
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              bmake PREFIX=${placeholder "out"} install
              runHook postInstall
            '';
          };
          neuswc = pkgs.stdenv.mkDerivation {
            pname = "neuswc";
            version = "unstable";
            src = pkgs.fetchgit {
              url = "https://git.sr.ht/~shrub900/neuswc";
              hash = "sha256-2y7nKZKKWQaxJSuz5ia4VIcR4ibsAt/M6oqDy5jRpg4=";
            };
            nativeBuildInputs = with pkgs; [
              pkg-config
              wayland-scanner
              bmake
            ];
            buildInputs = with pkgs; [
              neuwld
              libdrm
              pixman
              wayland
              wayland-protocols
              libxkbcommon
              libinput
              systemd
              libxcb
              libxcb-wm
              libxcb-util
              xcbutilxrm
            ];
            env.NIX_CFLAGS_COMPILE = "-I${pkgs.linuxHeaders}/include -I${pkgs.libdrm.dev}/include/libdrm -I${pkgs.libxcb.dev}/include";
            buildPhase = ''
              runHook preBuild
              bmake PREFIX=${placeholder "out"} ENABLE_LIBUDEV=1 ENABLE_XWAYLAND=1
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              bmake PREFIX=${placeholder "out"} ENABLE_LIBUDEV=1 ENABLE_XWAYLAND=1 install
              runHook postInstall
            '';
            postPatch = ''
              substituteInPlace Makefile \
                --replace 'install -m 4755' 'install -m 0755'
            '';
          };

        in
        {
          inherit neuwld neuswc neumenu;

          default = pkgs.stdenv.mkDerivation {
            pname = "wsxwm";
            version = "unstable";
            src = pkgs.fetchgit {
              url = "https://github.com/uint23/wsxwm";
              hash = "sha256-xXyRdFU/HYgbs9drGnqAh4mz4BgtcYfc6VJX8SvXFD4=";
            };
            nativeBuildInputs = with pkgs; [
              pkg-config
              bmake
            ];
            buildInputs = with pkgs; [
              neuswc
              neuwld
              wayland
              libxkbcommon
              libinput
              pixman
              libdrm
              systemd
              libxcb
              libxcb-wm

              havoc
            ];
            buildPhase = ''
              runHook preBuild
              export LDLIBS=$(pkg-config --libs \
                swc wayland-server xkbcommon libinput pixman-1 libdrm wld \
                libudev xcb xcb-composite xcb-ewmh xcb-icccm)
              bmake PREFIX=${placeholder "out"}
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              install -Dm755 wsxwm "$out/bin/wsxwm"
              runHook postInstall
            '';
            meta = with pkgs.lib; {
              description = "Wayland window manager built on neuswc";
              homepage = "https://wayland.fyi";
              platforms = platforms.linux;
              mainProgram = "wsxwm";
            };
          };
        }
      );
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.neuwld
              self.packages.${system}.neuswc
              self.packages.${system}.neumenu
              self.packages.${system}.default
            ];
          };
        }
      );
      defaultPackage = forAllSystems (system: self.packages.${system}.default);
    };
}
