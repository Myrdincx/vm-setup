# GPU Virtual Machine Setup

A simple setup for virtual machines on Linux that has GPU passthrough. \
This setup will make use of the [PRIME](https://wiki.archlinux.org/title/PRIME) technology so that you can use your dGPU both on the host and guest!

## Table of Contents

- [Before Getting Started](#before-getting-started)
    - [Setting up the bios](#setting-up-the-bios)
    - [Gathering Information](#gathering-information)
      - [Gathering PCI Device Addresses](#gathering-pci-device-addresses)
      - [Confirming PCI Device Path](#confirming-the-pci-device-path)
- [The Setup](#the-setup)
    - [Disabling SDDM](#disabling-sddm)
    - [Setting up scripts](#setting-up-the-scripts)
      - [Plasma Desktop with IGPU](#starting-plasma-desktop-with-the-igpu)
      - [Checking dGPU usage](#checking-that-you-dgpu-is-not-in-use)
- [Trying it out!](#trying-everything-out)
- [Reverting Changes](#reverting-changes)
- [Acknowledgements](#acknowledgements)
- [Contributing](#contributing)
- [Support](#support)

## Before getting started

> [!IMPORTANT]  
> You need **2 GPU's** to make this work, your integrated graphics can also count as a 2nd GPU. \
> Make sure you have a **cable** in your mobo going to your monitor, additionally, make sure you have a **cable or dummy plug** going from your dGPU to your monitor.
> 
> This guide is specifically created for the **KDE Plasma desktop environment**

This is my current setup, tested on the Fedora 40 KDE Spin, however, this should work on other distros using KDE Plasma.

### Setting up the BIOS

> [!NOTE]
> The exact name of the settings might be different based on your BIOS, just try to find anything that sounds close to the list below.

Before we get started with setting everything up, we have to make sure that the BIOS has the correct settings. Make sure to look for the following settings:
- `IOMMU` = Enabled
- `Initiate Graphics` = Forced
- `Integrated Graphics` = IGD
- `Resizable Bar` = Disabled (ReBar can be iffy with this setup)

### Gathering information

Before we get started with setting up the scripts, we have to gather some information.

#### Gathering PCI device addresses

> [!NOTE]
> We gather the PCI device addresses to make sure Plasma-Desktop only uses the Integrated Graphics.

Run the following script to list all PCI buses/devices your system has:
```
lspci -nn
```

Now look for `VGA compatible` and copy the numbers to the left of it. \
In my case:
```
03:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21 [Radeon RX 6800/6800 XT / 6900 XT] [1002:73bf] (rev c1)

13:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Raphael [1002:164e] (rev cb)
```
We only need to know that `03:00.0` is the dedicated GPU (dGPU) and `13:00.0` is the Integrated GPU (iGPU).

#### Confirming the PCI device path

Use the following command and make sure you have the following things:
```
ls /dev/dri/by-path/
```
The output should be something like:
```
pci-0000:03:00.0-card  pci-0000:03:00.0-render  pci-0000:13:00.0-card  pci-0000:13:00.0-render
```
> [!NOTE]
> The numbers will be different according to your PCI device addresses that you gathered in the previous step.

## The setup

### Disabling SDDM

> [!NOTE]  
> SDDM tends to load before your iGPU and use your dGPU, we don't want this to happen, so we will disable SDDM.
> This however means that you will not have a graphical login, and you will have to use the **TTY** to login (further info later on).

To **temporarily** stop SDDM:

```
sudo systemctl stop sddm
```

To **permanently** stop SDDM:
```
sudo systemctl disable sddm
```

### Setting up the scripts

#### Starting Plasma-Desktop with the iGPU

> [!NOTE] 
> We will make a script to start plasma-desktop with the iGPU, this makes sure it does not use your dGPU (so you can pass it through to the vm).

```
KWIN_DRM_DEVICES=$(realpath /dev/dri/by-path/pci-0000:13:00.0-card) startplasma-wayland
```

> [!IMPORTANT]
> Make sure to replace the `13:00.0` with the number from the iGPU you gathered before by using `lspci -nn`

> [!TIP]
> In order to make this easier, you can setup an alias in `~/.bashrc`, this way you don't need to remember/type the script out everytime you start your system. \
> ```
> ~/.bashrc
> alias start-desktop="KWIN_DRM_DEVICES=$(realpath /dev/dri/by-path/pci-0000:13:00.0-card) startplasma-wayland"
> ```
> Make sure you add the alias at the bottom of your `~/.bashrc` file.

#### Checking that you dGPU is not in use

In order for the dGPU to be passed through your VM, it can not be in use.
We can check this by using the following script:
```
sudo lsof -n | grep -e $(realpath /dev/dri/by-path/pci-0000:03:00.0-card) -e $(realpath /dev/dri/by-path/pci-0000:03:00.0-render)
```
> [!IMPORTANT]
> Replace the `pci-0000:03:00.0-card` and `pci-0000:03:00.0-render` with the correct path of your dGPU that you gathered in the previous steps.

> [!NOTE]
> Once again, we can make a simple script to make this step easier:
> ```
> nano vm-check.sh
> sudo lsof -n | grep -e $(realpath /dev/dri/by-path/pci-0000:03:00.0-card) -e $(realpath /dev/dri/by-path/pci-0000:03:00.0-render)
> chmod +x vm-check.sh
> ```

## Trying everything out

1. Start by disabling sddm and reboot
2. Open TTY by using CTRL+ALT+F1 (You can also press F2, F3, ... F8)
3. Login using your normal credentials
4. Type `start-desktop` (the alias you made in `~/.bashrc`)
5. Now type `./vm-check.sh` and wait for the output.
 - No output = you're good to go!
 ``` 
No output may look like this:

 lsof: WARNING: can't stat() fuse.portal file system /run/user/1000/doc
      Output information may be incomplete.
```
- Output = Close all the programs that are listed, re-run `./vm-check.sh` to assure they're closed

6. Start the VM and make sure you passed through the dGPU

> [!NOTE]
> You can still use your dGPU on the host system, just make sure to close down the programs after using it, so your VM can use your dGPU. \
> Using your dGPU will make use of the [PRIME](https://wiki.archlinux.org/title/PRIME) technology. \
> You might need to add `DRI_PRIME=1` to your launch options in steam games.

## Reverting changes

In case you want to revert everything you have done before, follow these steps:
1. Re-enable SDDM
```
sudo systemctl enable sddm
```
2. Remove the alias from `~/.bashrc`
3. Remove the `./vm-check.sh` script
4. (Remove PRIME launch option in steam)

## Acknowledgements

 Big thank you to the [VFIO Discord](https://discord.gg/f63cXwH) and the people in there that helped me out :) 

## Contributing

Contributions are always welcome!

In case you figured out new methods or want to update this guide, feel free to create a PR request or contact me on Discord (see support section).

## Support

For support, please contact me on [Discord](https://discord.com/users/300300616335622154). \
Additionally, you can create an Issue on Github :)

