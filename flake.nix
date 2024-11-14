{
  description = "Node.js development environment based on node:20-bookworm-slim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells."${system}" = let
          bareMinimum = with pkgs; [nodejs_20 git];
    in {
            
    default = pkgs.mkShell {
      nativeBuildInputs =
       bareMinimum
       ++ (with pkgs; [
       #prisma-engines
       openssl
       ]);  

      shellHook = ''

        # Create working directory structure
        export PROJECT_ROOT="$PWD"
        WORK_DIR="$PWD/app"
        if [ ! -d "$PWD/app" ]; then
            mkdir -p "$WORK_DIR"
            chmod 755 "$WORK_DIR"
        fi

        if [ ! -d "$PROJECT_ROOT/build" ]; then
          npm install  
          npm run build
        fi  

        cd $PWD/app

        # Copy configuration files 
          cp "$PROJECT_ROOT/.npmrc" .
          cp "$PROJECT_ROOT/.env" .
        
          cp "$PROJECT_ROOT/package.json" .
        
          cp "$PROJECT_ROOT/package-lock.json" .
        
          cp -r "$PROJECT_ROOT/patches" .

          cp -r "$PROJECT_ROOT/queries" .

        # Install production dependencies
          npm i --only=prod

        # Copy build directory if it exists
        if [ -d "$PROJECT_ROOT/build" ]; then
              echo "Copying build directory contents..."
                cp -av "$PROJECT_ROOT/build/." . || {
                echo "Failed to copy build directory contents"
                return 1
                }
        fi

        # Set up environment variables
          export NODE_ENV=test
        
        # Print environment info
        echo "Node.js version: $(node --version)"
        echo "npm version: $(npm --version)"
        echo "Working directory: $(pwd)"

        # Function to start the application
        start_app() {
            npm start
        }

        echo "To start the application, run: start_app"
      '';
    };
    dev = pkgs.mkShell {
       nativeBuildInputs =
       bareMinimum
       ++ (with pkgs; [
       #prisma-engines
       openssl
       ]);
      shellHook = '' 
        npm install
        npm run db:migrate:latest
        npm run db:seed:import
        
        # Set up environment variables
        export NODE_ENV=development
        
        # Print environment info
        echo "Node.js version: $(node --version)"
        echo "npm version: $(npm --version)"
        echo "Working directory: $(pwd)"

        # Function to start the application
        dev_app() {
            npm run dev
        }

        echo "To start the application, run: dev_app"

      '';      
          };    
    ci-format = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [corepack];
          };

    ci-reviewdog = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              corepack
              nodejs_22
            ];
    };
    };
    # Optional: Add a package definition if you want to build it
    packages."${system}".default = pkgs.stdenv.mkDerivation {
      name = "node-app";
      src = ./.;
      
      buildInputs = with pkgs; [
        nodejs_20
        dumb-init
      ];

      buildPhase = ''
        mkdir -p /tmp/app
        cp -r . /tmp/app/
        cd /tmp/app
        npm i --only=prod
      '';

      installPhase = ''
        mkdir -p $out/tmp/app
        cp -r /tmp/app/* $out/tmp/app/
        
        mkdir -p $out/bin
        cat > $out/bin/start-app <<EOF
        #!${pkgs.bash}/bin/bash
        exec ${pkgs.dumb-init}/bin/dumb-init ${pkgs.nodejs_20}/bin/node $out/tmp/app/bin/cli api
        EOF
        chmod +x $out/bin/start-app
      '';
    };
    
  };
}