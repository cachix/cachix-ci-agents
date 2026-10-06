# Runtime secrets for a CI machine.
{ lib, ... }:

let
  secretModule = {
    options.path = lib.mkOption {
      type = lib.types.str;
      description = ''
        The runtime path of the secret. The deployment's secret provider
        creates the file and sets permissions for the services that read it.
      '';
    };
  };
in
{
  options.cachix.secrets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule secretModule);
    default = { };
    description = ''
      Paths to runtime secrets supplied by the deployment's secret provider.
    '';
  };
}
