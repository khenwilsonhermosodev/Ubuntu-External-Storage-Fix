#!/usr/bin/env bash
set -uo pipefail

sudo -v || exit 1

missing=()
dpkg-query -W -f='${Status}' ntfs-3g 2>/dev/null | grep -q 'install ok installed' ||
  missing+=(ntfs-3g)
dpkg-query -W -f='${Status}' udisks2 2>/dev/null | grep -q 'install ok installed' ||
  missing+=(udisks2)

if ((${#missing[@]})); then
  sudo apt-get update || exit 1
  sudo apt-get install -y "${missing[@]}" || exit 1
fi

command -v ntfsfix >/dev/null && command -v udisksctl >/dev/null || {
  echo "Required repair or disk tools are unavailable."
  exit 1
}

declare -a disks=()
while read -r disk transport removable; do
  if [[ "$transport" == "usb" || "$removable" == "1" ]]; then
    disks+=("$disk")
  fi
done < <(lsblk -dnpo NAME,TRAN,RM)

((${#disks[@]})) || { echo "No USB or removable disks detected."; exit 0; }

declare -a partitions=()
for disk in "${disks[@]}"; do
  while read -r name type; do
    [[ "$type" == "part" ]] && partitions+=("$name")
  done < <(lsblk -lnpo NAME,TYPE "$disk")
done

declare -A usable=()
for part in "${partitions[@]}"; do
  usable["$part"]=1

  # Never attempt to unmount a partition used for core system directories.
  while read -r mountpoint; do
    case "$mountpoint" in
      /|/boot|/boot/efi|/home)
        echo "Skipping $part because it is mounted at $mountpoint."
        usable["$part"]=0
        ;;
    esac
  done < <(findmnt -rn -S "$part" -o TARGET 2>/dev/null || true)

  [[ "${usable[$part]}" == "1" ]] || continue
  if findmnt -rn -S "$part" >/dev/null; then
    echo "Unmounting $part ..."
    if ! udisksctl unmount -b "$part"; then
      echo "Could not unmount $part; skipping it."
      usable["$part"]=0
    fi
  fi
done

for part in "${partitions[@]}"; do
  [[ "${usable[$part]}" == "1" ]] || continue
  fs=$(blkid -o value -s TYPE "$part" 2>/dev/null || true)

  if [[ "$fs" == "ntfs" || "$fs" == "ntfs3" ]]; then
    check=$(sudo ntfsfix --no-action "$part" 2>&1 || true)
    if grep -Fq '$MFTMirr does not match $MFT' <<<"$check"; then
      echo "Repairing NTFS MFT mirror on $part ..."
      sudo ntfsfix "$part" || echo "Repair failed on $part."
    else
      echo "No MFT mirror mismatch on $part; leaving NTFS metadata unchanged."
    fi
  fi
done

for part in "${partitions[@]}"; do
  [[ "${usable[$part]}" == "1" ]] || continue
  fs=$(blkid -o value -s TYPE "$part" 2>/dev/null || true)
  [[ -n "$fs" && "$fs" != "swap" ]] || continue

  if ! findmnt -rn -S "$part" >/dev/null; then
    echo "Mounting $part ..."
    udisksctl mount -b "$part" || echo "Could not mount $part."
  fi
done

echo "Finished."
