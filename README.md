# dotfiles

These dotfiles are for a Debian 9 host machine using KVM/libvirt to run development environments based on Ubuntu 16.04+.

Configs shared between the two systems are located in the `shared` folder. Configs unique to each system are located in their respective folders along with documentation for each disparity. Each folder also contains a complete package list installed on each system.

The host and VMs require specific configurations for Spice in order to support multiple displays. These dotfiles come configured to enable two monitors by default. More displays may be the default in the future.

## Debian

Currently version 9 (stretch) with 2770 packages.

```
* Xfce4
* URxvt
* bash
* vim
* virsh
* spice
```
## Ubuntu

Currently version 16.04 (Xenial Xerus) with 1745 packages.

```
* i3
* st
* bash
* vim
* dmenu
* spice
```

