{
  coreutils,
  findutils,
  lsof,
  writeShellApplication,
}:

writeShellApplication {
  name = "nix-clean-stale-state";
  runtimeInputs = [
    coreutils
    findutils
    lsof
  ];
  text = ''
    build_root=/nix/var/nix/builds
    if [[ -d "$build_root" ]]; then
      find "$build_root" \
        -mindepth 1 -maxdepth 1 \
        -type d -name 'nix-*' -mmin +1440 -print0 |
      while IFS= read -r -d "" build_dir; do
        # Non-chroot builds keep the top-level directory open. Sandboxed
        # Linux builds keep the nested build directory open instead.
        if lsof "$build_dir" >/dev/null 2>&1; then
          continue
        fi
        if [[ -d "$build_dir/build" ]] && lsof "$build_dir/build" >/dev/null 2>&1; then
          continue
        fi
        rm -rf -- "$build_dir"
      done
    fi

    log_root=/nix/var/log/nix/drvs
    if [[ -d "$log_root" ]]; then
      find "$log_root" -type f -delete
      find "$log_root" -depth -mindepth 1 -type d -empty -delete
    fi
  '';
}
