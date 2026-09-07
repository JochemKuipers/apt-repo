# Personal APT repository

Unofficial packages of howdy-next, adguard-tray, and skills-manager.

```sh
curl -fsSL https://jochemkuipers.github.io/apt-repo/jochem.sources \
  | sudo tee /etc/apt/sources.list.d/jochem.sources
sudo apt update
sudo apt install howdy-next adguard-tray skills-manager
```

Remove any old howdy-next or adguard-tray APT sources first.
