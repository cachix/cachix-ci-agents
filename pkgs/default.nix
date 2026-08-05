# Package-set construction shared by every machine.
{
  nixpkgs,
  system,
  overlays,
}:
import nixpkgs {
  inherit system overlays;
  # The GitHub runner requires the EOL nodejs 20.
  config.allowInsecurePredicate =
    pkg:
    builtins.elem (nixpkgs.lib.getName pkg) [
      "nodejs"
      "nodejs-slim"
    ]
    && nixpkgs.lib.versions.major (nixpkgs.lib.getVersion pkg) == "20";
}
