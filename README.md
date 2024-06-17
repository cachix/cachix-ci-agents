# Linux

Based on [cachix-deploy-hetzner-dedicated](https://github.com/cachix/cachix-deploy-hetzner-dedicacted).


# MacOS

Based on [Cachix Deploy for nix-darwin](https://docs.cachix.org/deploy/running-an-agent/darwin).

Make sure to install rosetta: `softwareupdate --install-rosetta --agree-to-license`

# Secrets

Secrets are managed by sops: https://github.com/Mic92/sops-nix

Add a new secret:

```shell
sops secrets.yaml
```

To add a new key, edit `.sops.yaml`, then run:

```shell
sops updatekeys secrets.yaml
```
