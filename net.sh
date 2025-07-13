#!/usr/bin/env bash
#
# setup-lxc-net.sh
#
# Usage:
#   setup-lxc-net.sh -c CTID [-b BRIDGE] -t {dhcp,static} \
#                    [-a IP/CIDR] [-g GATEWAY] [-d DNS1[,DNS2,...]]
#
# Examples:
#   # DHCP on vmbr0:
#   setup-lxc-net.sh -c 101 -t dhcp
#
#   # Static IP 10.0.0.50/24, gateway 10.0.0.1, DNS Google's:
#   setup-lxc-net.sh -c 102 -t static -a 10.0.0.50/24 \
#                    -g 10.0.0.1 -d 8.8.8.8,8.8.4.4
#
set -euo pipefail

# Default bridge
BRIDGE="vmbr0"
CTID=""
TYPE=""
IPADDR=""
GATEWAY=""
DNS=""

usage() {
  cat <<EOF
Usage: $0 -c CTID [-b BRIDGE] -t {dhcp,static} [-a IP/CIDR] [-g GATEWAY] [-d DNS1[,DNS2,...]]

  -c CTID         : the container ID to configure
  -b BRIDGE       : Proxmox bridge to attach (default: vmbr0)
  -t TYPE         : dhcp or static
  -a IP/CIDR      : required if static (e.g. 192.168.1.50/24)
  -g GATEWAY      : required if static (e.g. 192.168.1.1)
  -d DNS1[,DNS2]  : optional DNS servers (will overwrite /etc/resolv.conf)

Examples:
  # DHCP on vmbr0
  $0 -c 101 -t dhcp

  # Static 10.0.0.50/24, gateway 10.0.0.1, Google DNS
  $0 -c 102 -t static -a 10.0.0.50/24 -g 10.0.0.1 -d 8.8.8.8,8.8.4.4
EOF
  exit 1
}

while getopts "c:b:t:a:g:d:" opt; do
  case $opt in
    c) CTID="$OPTARG" ;;
    b) BRIDGE="$OPTARG" ;;
    t) TYPE="$OPTARG" ;;
    a) IPADDR="$OPTARG" ;;
    g) GATEWAY="$OPTARG" ;;
    d) DNS="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validate mandatory
[[ -z "$CTID" || -z "$TYPE" ]] && usage
if [[ "$TYPE" != dhcp && "$TYPE" != static ]]; then
  echo "Error: -t must be 'dhcp' or 'static'" >&2; exit 1
fi
if [[ "$TYPE" == static && ( -z "$IPADDR" || -z "$GATEWAY" ) ]]; then
  echo "Error: static mode requires -a and -g" >&2; exit 1
fi

# Make sure container exists
if ! pct status "$CTID" &>/dev/null; then
  echo "Error: container $CTID not found" >&2; exit 1
fi

echo "Configuring LXC CT#${CTID} on bridge ${BRIDGE} as ${TYPE^^}..."

# Build the --net0 string
if [[ "$TYPE" == dhcp ]]; then
  NETOPTS="name=eth0,bridge=${BRIDGE},ip=dhcp"
else
  NETOPTS="name=eth0,bridge=${BRIDGE},ip=${IPADDR},gw=${GATEWAY}"
fi

# Apply network config to the LXC
pct set "$CTID" --net0 "${NETOPTS}"

# Restart container to pick up new net settings
echo "Restarting container..."
# First stop, then start
pct stop "$CTID"
pct start "$CTID"

# If DNS was specified, push resolv.conf inside
if [[ -n "$DNS" ]]; then
  echo "Setting DNS inside container to: ${DNS}"
  # Build resolv.conf content
  RESOLV=""
  IFS=',' read -ra ADDRARR <<< "$DNS"
  for srv in "${ADDRARR[@]}"; do
    RESOLV+="nameserver ${srv}"$'\n'
  done
  # Overwrite resolv.conf
  pct exec "$CTID" -- bash -c "echo -n '${RESOLV}' > /etc/resolv.conf"
fi

echo "Done! Container #${CTID} should now have network connectivity."
