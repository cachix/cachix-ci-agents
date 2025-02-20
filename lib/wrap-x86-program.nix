{
  lib,
  stdenv,
  writeScript,
}:

let
  wrapPackage =
    pkg:
    let
      wrapBinary =
        name:
        writeScript "wrapped-${name}" ''
          #!/bin/sh
          exec /usr/bin/arch -x86_64 ${pkg}/bin/${name} "$@"
        '';

      binFiles = builtins.attrNames (builtins.readDir "${pkg}/bin");

      # Create an attribute set of all wrapped binaries
      wrappedBinaries = lib.genAttrs binFiles wrapBinary;

      wrapped = stdenv.mkDerivation {
        pname = "${pkg.pname}-x86_64-wrapped";
        version = pkg.version;

        buildInputs = [ pkg ];

        buildCommand = ''
          mkdir -p $out
          # Copy other files and directories from the original package
          cp -r ${pkg}/* $out/
          chmod -R u+w $out/bin

          # Clear the original bin directory
          rm -rf $out/bin
          mkdir -p $out/bin

          # Create symlinks for all wrapped binaries
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: path: ''
              ln -s ${path} $out/bin/${name}
            '') wrappedBinaries
          )}
        '';

        # Preserve meta attributes from the original package
        meta = pkg.meta // {
          description = "x86_64 wrapped version of ${pkg.meta.description or pkg.name}";
        };
      };

    in
    wrapped
    // {
      # Preserve the original package's override function
      override = f: wrapPackage (pkg.override f);

      # Expose the original package
      passthru.unwrapped = pkg;
    };
in
wrapPackage
