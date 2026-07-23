{
  nixpkgs,
  darwin,
  cachix-deploy-flake,
  pkgsFor,
}:

let
  lib = nixpkgs.lib;
in
rec {
  deployFor = system: cachix-deploy-flake.lib (pkgsFor system);

  mkNixosMachine =
    {
      name,
      system,
      modules,
      bootstrap ? null,
      specialArgs ? { },
      defaultPackage ? false,
      ...
    }:
    let
      deploy = deployFor system;
      moduleArgs = {
        _module.args = specialArgs;
      };
      bootstrapConfiguration =
        if bootstrap == null then
          null
        else
          deploy.bootstrapNixOS (
            bootstrap
            // {
              inherit system;
              imports = [ moduleArgs ] ++ (bootstrap.imports or [ ]);
            }
          );
      deploymentModules =
        if bootstrapConfiguration == null then
          [ moduleArgs ] ++ modules
        else
          [ bootstrapConfiguration.module ] ++ modules;
    in
    {
      inherit name system defaultPackage;
      nixosConfiguration =
        if bootstrapConfiguration != null then
          bootstrapConfiguration.nixos
        else
          lib.nixosSystem {
            inherit
              system
              modules
              specialArgs
              ;
            pkgs = pkgsFor system;
          };
      darwinConfiguration = null;
      package = deploy.nixos { imports = deploymentModules; };
    };

  mkDarwinMachine =
    {
      name,
      system,
      modules,
      specialArgs ? { },
      defaultPackage ? false,
      ...
    }:
    let
      moduleArgs = {
        _module.args = specialArgs;
      };
    in
    {
      inherit name system defaultPackage;
      nixosConfiguration = null;
      darwinConfiguration = darwin.lib.darwinSystem {
        inherit
          system
          modules
          specialArgs
          ;
        pkgs = pkgsFor system;
      };
      package = (deployFor system).darwin {
        imports = [ moduleArgs ] ++ modules;
      };
    };

  mkMachine =
    machine:
    if machine.kind == "nixos" then
      mkNixosMachine machine
    else if machine.kind == "darwin" then
      mkDarwinMachine machine
    else
      throw "Unsupported machine kind: ${machine.kind}";

  evalMachines = lib.mapAttrs (name: machine: mkMachine (machine // { inherit name; }));

  mkDeploySpec =
    { system, machines }:
    (deployFor system).spec {
      agents = lib.mapAttrs (_name: machine: machine.package) (evalMachines machines);
    };

  mkFlake =
    {
      machines,
      systems ? null,
      devShellFor ? null,
      extraPackagesFor ? (_system: { }),
    }:
    let
      builtMachineAttrs = evalMachines machines;
      builtMachines = lib.attrValues builtMachineAttrs;
      outputSystems =
        if systems == null then lib.unique (map (machine: machine.system) builtMachines) else systems;

      packagesFor =
        system:
        let
          systemMachines = lib.filter (machine: machine.system == system) builtMachines;
          defaultMachines = lib.filter (machine: machine.defaultPackage) systemMachines;
          defaultMachine =
            if lib.length defaultMachines > 1 then
              throw "Multiple default deployment packages for ${system}"
            else if defaultMachines != [ ] then
              lib.head defaultMachines
            else if lib.length systemMachines == 1 then
              lib.head systemMachines
            else
              null;
        in
        lib.listToAttrs (map (machine: lib.nameValuePair machine.name machine.package) systemMachines)
        // lib.optionalAttrs (defaultMachine != null) {
          default = defaultMachine.package;
        }
        // extraPackagesFor system;
    in
    {
      nixosConfigurations = lib.mapAttrs (_name: machine: machine.nixosConfiguration) (
        lib.filterAttrs (_name: machine: machine.nixosConfiguration != null) builtMachineAttrs
      );

      darwinConfigurations = lib.mapAttrs (_name: machine: machine.darwinConfiguration) (
        lib.filterAttrs (_name: machine: machine.darwinConfiguration != null) builtMachineAttrs
      );

      packages = lib.genAttrs outputSystems packagesFor;
    }
    // lib.optionalAttrs (devShellFor != null) {
      devShells = lib.genAttrs outputSystems (system: {
        default = devShellFor system;
      });
    };
}
