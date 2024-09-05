sudo lsof -n | grep -e $(realpath /dev/dri/by-path/pci-0000:03:00.0-card) -e $(realpath /dev/dri/by-path/pci-0000:03:00.0-render)
