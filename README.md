# Linux

Based on [cachix-deploy-hetzner-dedicated](https://github.com/cachix/cachix-deploy-hetzner-dedicacted).


# MacOS

Based on [Cachix Deploy for nix-darwin](https://docs.cachix.org/deploy/running-an-agent/darwin).

Make sure to install rosetta: `softwareupdate --install-rosetta --agree-to-license`

### Debugging

#### Launchd

List services:
```
sudo launchctl list
```

Print detailed service status:
```
sudo launchctl print system/org.nixos.github-runner-cachix-aarch64-darwin-0
```

Restart a service:
```
sudo launchctl kickstart -k system/org.nixos.github-runner-cachix-aarch64-darwin-0
```

View launchd logs for the service:
```
sudo log show --last 10m | grep "org.nixos.github-runner-cachix-aarch64-darwin-0"
```

#### Low disk space

> [!NOTE]
> This may be outdated information for newer versions of macOS.

If automatic software updates are disabled, but automatic downloads aren't, macOS will continously download udpates into /tmp, eventually filling up the disk.

Run `software update --list` to view the pending updates.

You can install everything (including major OS upgrades) with `sudo softwareudpate --install --all -R`.

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
