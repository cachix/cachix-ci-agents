# Linux

Based on [cachix-deploy-hetzner-dedicated](https://github.com/cachix/cachix-deploy-hetzner-dedicacted).


# MacOS

Based on [Cachix Deploy for nix-darwin](https://docs.cachix.org/deploy/running-an-agent/darwin).

Make sure to install rosetta: `softwareupdate --install-rosetta --agree-to-license`

# Secrets

Secrets are managed by agenix: https://github.com/ryantm/agenix

### Add a new secret, machine, or user

Edit `secrets/secrets.nix` to add secrets, machines, and users.

You can get the public key for a machine with `ssh-keyscan`:

```shell
ssh-keyscan <IP/DOMAIN>
```

Create a new encrypted secret with:

```shell
cd secrets
agenix -e <NAME>.age -i ~/.ssh/<publickey>
```

### Edit an existing secret

```shell
cd secrets
agenix -e <NAME>.age -i ~/.ssh/<publickey>
```
