{ fetchpatch, nix }:

let
  appendPatches = patches: old: {
    patches = (old.patches or [ ]) ++ patches;
  };
in
(nix.overrideScope (
  _final: prev: {
    nix-store = prev.nix-store.overrideAttrs (appendPatches [
      (fetchpatch {
        url = "https://github.com/cachix/nix/commit/8e2f8b77f7f6a9451a49ca34617b69f807df9ec3.diff";
        stripLen = 2;
        hash = "sha256-621lqYQr5s/W62EuP4LwVxtjAg7xAPOHYRswWifU7ts=";
      })
      ../patches/nix-store-gc-temproot.patch
      # Refuse store path hash rewrites that would modify build
      # outputs on darwin instead of silently corrupting signed
      # Mach-O binaries (NixOS/nix#6065, nixpkgs#507531).
      # No-op rewrites (no hash occurrences in the output) are
      # skipped; byte-changing ones fail with OutputRejected.
      ../patches/nix-store-refuse-darwin-output-rewrites.patch
    ]);
    nix-expr = prev.nix-expr.overrideAttrs (appendPatches [
      (fetchpatch {
        url = "https://github.com/cachix/nix/commit/41ac8bee461829d3af0a5440d7c60f94b7a26fb5.diff";
        stripLen = 2;
        includes = [ "eval-cache.cc" ];
        hash = "sha256-t0R+Y/j9f7tXZlgUxebP69XAI7jGZ5+12TuwMeqrErM=";
      })
    ]);
    nix-fetchers = prev.nix-fetchers.overrideAttrs (appendPatches [
      ../patches/nix-fetchers-addtemproot.patch
    ]);
  }
)).overrideAttrs
  (_old: {
    # Disable more flaky tests unit tests.
    # Needs investigating.
    doCheck = false;
  })
