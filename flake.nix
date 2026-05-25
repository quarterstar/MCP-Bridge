{
  description = "Python development environment with PyQt6";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      utils,
      pyproject-nix,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        project = pyproject-nix.lib.project.loadPyproject {
          projectRoot = ./.;
        };

        python = pkgs.python3.override {
          packageOverrides = self: super: {
            "pypika-tortoise" = self.buildPythonPackage rec {
              pname = "pypika-tortoise";
              version = "0.3.2";
              format = "pyproject";

              src = self.fetchPypi {
                pname = "pypika_tortoise";
                inherit version;
                hash = "sha256-9dUI4u8AJV5S7GrHnviJ4Q26syjyGMVc0TTE0C/59vQ=";
              };

              build-system = [
                self.setuptools
                self.poetry-core
              ];
              dependencies = [ ];
              doCheck = false;
            };

            "lmos-openai-types" = self.buildPythonPackage rec {
              pname = "lmos-openai-types";
              version = "0.2.1";
              format = "pyproject";

              src = pkgs.fetchFromGitHub {
                owner = "LMOS-IO";
                repo = "LMOS-openai-types";
                rev = "pydantic-gen";
                hash = "sha256-JBlb3i52tbIM4ajw/v+EkuiOuueUYpkAW/WKqviwIVk=";
              };

              build-system = [
                self.setuptools
                self.wheel
              ];
              dependencies = [ self.pydantic ];
              doCheck = false;
            };

            "tortoise-orm" = self.buildPythonPackage rec {
              pname = "tortoise-orm";
              version = "0.23.0";
              format = "pyproject";

              src = self.fetchPypi {
                pname = "tortoise_orm";
                inherit version;
                hash = "sha256-8l1DHvT7UhqE7a1YL0ucU9zMWr9s+8byKMvs5aE5Uvo=";
              };

              build-system = [
                self.setuptools
                self.poetry-core
              ];

              nativeBuildInputs = [ self.pythonRelaxDepsHook ];

              pythonRelaxDeps = [
                "aiosqlite"
                "pypika-tortoise"
              ];

              dependencies = with self; [
                pydantic
                typing-extensions
                asyncpg
                aiosqlite
                iso8601
                pytz
                self.${"pypika-tortoise"}
              ];
              doCheck = false;
            };

            mcp = super.mcp.overridePythonAttrs (_old: {
              version = "1.2.0";
              src = pkgs.fetchPypi {
                pname = "mcp";
                version = "1.2.0";
                hash = "sha256-KwbH7OmNbqnmN5yqONdLQyOFwzj7Uwy4Lixw6nrdlPU=";
              };
              doCheck = false;
            });

            mcpx = self.buildPythonPackage rec {
              pname = "mcpx";
              version = "0.1.1";
              format = "pyproject";

              src = self.fetchPypi {
                inherit pname version;
                hash = "sha256-nYo141fiZVSkzbwtYqrG6lmfvcHOygKJdR5Z8G3awf8=";
              };

              build-system = with self; [
                hatchling
                wheel
              ];
              dependencies = with self; [
                mcp
                pydantic
                loguru
                aiodocker
              ];
            };
          };
        };
        pythonPkgs = python.pkgs;

        runtimeLibs = [ ];

        package =
          let
            parsedDeps = pyproject-nix.lib.renderers.withPackages {
              inherit project python;
            };
          in
          pythonPkgs.buildPythonPackage {
            pname = project.pyproject.project.name;
            version = project.pyproject.project.version or "0.9.1";
            format = "pyproject";

            src = ./.;

            build-system = with pythonPkgs; [
              setuptools
              wheel
            ];

            dependencies = parsedDeps pythonPkgs;

            nativeBuildInputs = [ pythonPkgs.pythonRelaxDepsHook ];

            pythonRelaxDeps = [ "mcp" ];

            inherit runtimeLibs;

            doCheck = false;
          };
      in
      {
        packages.default = package;

        devShells.default = pkgs.mkShell rec {
          packages = with pkgs; [
            python
            uv
          ];

          shellHook = # bash
            ''
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:$LD_LIBRARY_PATH"

              if [ ! -d ".venv" ]; then
                uv venv --python ${python.interpreter}
              fi

              source .venv/bin/activate
            '';

          inherit runtimeLibs;
        };
      }
    );
}
