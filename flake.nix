{
  description = "wsxwm — a minimal Wayland desktop environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    neu-nix = {
      url = "github:ricardomaps/neu-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      neu-nix,
    }:
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
          neu = neu-nix.packages.${system};
        in
        {
          inherit (neu)
            neuwld
            neuswc
            neumenu
            swall
            swiv
            mojito
            hst
            ;

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
              neu.neuswc
              neu.neuwld
              wayland
              libxkbcommon
              libinput
              pixman
              libdrm
              systemd
              libxcb
              libxcb-wm
              fontconfig # ← add this
            ];
            buildPhase = ''
              runHook preBuild
              LDLIBS=$(pkg-config --libs \
                swc wayland-server xkbcommon libinput pixman-1 libdrm wld \
                libudev xcb xcb-composite xcb-ewmh xcb-icccm)
              bmake PREFIX=${placeholder "out"} LDLIBS="$LDLIBS"
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
          neu = neu-nix.packages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              neu.neuswc
              neu.neumenu
              neu.swall
              neu.swiv
              neu.hst
              neu.hack
              neu.mojito
              neu.hevel
              pkgs.havoc
              self.packages.${system}.default
            ];
          };
        }
      );

      defaultPackage = forAllSystems (system: self.packages.${system}.default);
    };
}
