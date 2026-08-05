{ nix }:

let
  appendPatches = patches: old: {
    patches = (old.patches or [ ]) ++ patches;
  };
in
(nix.overrideScope (
  _final: prev: {
    nix-store = prev.nix-store.overrideAttrs (appendPatches [
      # Use a unique temproots filename per LocalStore instance.
      # This was reverted in 2.35.1 because it breaks when downgrading Nix.
      ../patches/nix-store-gc-temproot.patch
      # Refuse store path hash rewrites that would modify build
      # outputs on darwin instead of silently corrupting signed
      # Mach-O binaries (NixOS/nix#6065, nixpkgs#507531).
      # No-op rewrites (no hash occurrences in the output) are
      # skipped; byte-changing ones fail with OutputRejected.
      ../patches/nix-store-refuse-darwin-output-rewrites.patch
    ]);
  }
)).overrideAttrs
  (_old: {
    # Disable more flaky tests unit tests.
    # Needs investigating.
    doCheck = false;
  })
