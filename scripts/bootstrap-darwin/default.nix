{
  runCommand,
  runtimeShell,
  shellcheck-minimal,
}:

# bootstrap-darwin.sh uses nix and ssh from PATH, so that the user's Nix
# settings and caches and the system ssh (with its keychain and agent
# integration) apply.
runCommand "bootstrap-darwin"
  {
    nativeBuildInputs = [ shellcheck-minimal ];
    meta.mainProgram = "bootstrap-darwin";
  }
  ''
    shellcheck --shell=bash ${./bootstrap-darwin.sh} ${./remote.sh}

    # bootstrap-darwin.sh uploads remote.sh, which is next to it, to the Mac.
    libexec=$out/libexec/bootstrap-darwin
    install -D -m 755 ${./bootstrap-darwin.sh} $libexec/bootstrap-darwin.sh
    install -m 644 ${./remote.sh} $libexec/remote.sh
    substituteInPlace $libexec/bootstrap-darwin.sh \
      --replace-fail '#!/usr/bin/env bash' '#!${runtimeShell}'

    mkdir -p $out/bin
    ln -s $libexec/bootstrap-darwin.sh $out/bin/bootstrap-darwin
  ''
