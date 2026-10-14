{
  lib,
  overlaysFor ? (_system: [ ]),
}:

let
  # Return a function from a system to its package set.
  # Each system is instantiated at most once, on first use.
  pkgsFor =
    {
      inputs,
      config ? { },
      overlays ? [ ],
    }:
    let
      instantiate =
        system:
        import inputs.nixpkgs {
          inherit system config;
          overlays = overlaysFor system ++ overlays;
        };
      pkgsBySystem = lib.genAttrs lib.systems.flakeExposed instantiate;
    in
    system: pkgsBySystem.${system};

  mkMachine =
    name:
    {
      inputs,
      pkgsForSystem ? pkgsFor { inherit inputs; },
      system,
      hardware,
      modules ? [ ],
      specialArgs ? { },
    }:
    let
      pkgs = pkgsForSystem system;
      platform = pkgs.stdenv.hostPlatform;
      machineModule = {
        # Also the Cachix Deploy agent name.
        networking.hostName = name;
        cachix.machine.hardware = hardware;
      };
    in
    if platform.isLinux then
      inputs.nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        modules = [
          # Use the supplied package set and take the platforms from it.
          inputs.nixpkgs.nixosModules.readOnlyPkgs
          { nixpkgs.pkgs = pkgs; }
          ../profiles/linux-runner.nix
          machineModule
        ]
        ++ modules;
      }
    else if platform.isDarwin then
      inputs.nix-darwin.lib.darwinSystem {
        inherit specialArgs;
        modules = [
          # Use the supplied package set and take the platforms from it.
          # nix-darwin has no equivalent of the NixOS `readOnlyPkgs` module.
          {
            nixpkgs = {
              inherit pkgs;
              inherit (pkgs.stdenv) hostPlatform buildPlatform;
            };
          }
          ../profiles/macos-runner.nix
          machineModule
        ]
        ++ modules;
      }
    else
      throw "Machine '${name}': unsupported platform '${platform.system}', expected Linux or Darwin";

  mkMachines =
    {
      inputs,
      pkgsForSystem ? pkgsFor { inherit inputs; },
      machines,
    }:
    lib.mapAttrs (
      name: machine: mkMachine name ({ inherit inputs pkgsForSystem; } // machine)
    ) machines;

  mkFlake =
    { machines, pkgsForSystem }:
    let
      byClass = class: lib.filterAttrs (_name: machine: machine.class == class) machines;

      # Select by build platform so cross-compiled machines use the right builder.
      buildSystem = machine: machine.pkgs.stdenv.buildPlatform.system;
      systems = lib.unique (map buildSystem (builtins.attrValues machines));
      machinesFor = system: lib.filterAttrs (_name: machine: buildSystem machine == system) machines;
      machinePackages = lib.mapAttrs (_: machine: machine.config.system.build.toplevel);

      # Referencing the derivations in JSON makes them dependencies of the spec.
      mkDeploySpec =
        pkgs: selectedMachines:
        pkgs.writeText "deploy.json" (builtins.toJSON { agents = machinePackages selectedMachines; });

      packagesFor =
        system:
        let
          pkgs = pkgsForSystem system;
          deploy = mkDeploySpec pkgs machines;
        in
        machinePackages (machinesFor system)
        // {
          inherit deploy;
          default = deploy;
          "deploy-${system}" = mkDeploySpec pkgs (machinesFor system);
        };
    in
    {
      nixosConfigurations = byClass "nixos";
      darwinConfigurations = byClass "darwin";
      packages = lib.genAttrs systems packagesFor;
    };
in
{
  inherit
    pkgsFor
    mkMachine
    mkMachines
    mkFlake
    ;
}
