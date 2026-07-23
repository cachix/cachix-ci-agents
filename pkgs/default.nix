# Package-set construction shared by every machine.
{
  nixpkgs,
  system,
  overlays,
}:
import nixpkgs {
  inherit system overlays;
  config.permittedInsecurePackages = [
    "nodejs-20.20.2"
    "nodejs-slim-20.20.2"
  ];
}
