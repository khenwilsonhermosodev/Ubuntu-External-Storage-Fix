**External Storage Fixer** automates a Linux-side repair for one specific NTFS problem: a mismatch between `$MFT` and `$MFTMirr`, which can prevent Ubuntu from mounting the drive.

## Run it

1. Download `External Storage Fixer.sh`.
2. Open your **Downloads** folder in Ubuntu Files.
3. Right-click an empty area and choose **Open in Terminal**.
4. Run:

   ```bash
   sudo bash "./External Storage Fixer.sh"
   ```

The script installs `ntfs-3g` and `udisks2` if they’re missing. It then finds USB or removable disks, unmounts their mounted partitions, checks NTFS partitions for the MFT mirror mismatch, repairs partitions where that mismatch is detected, and attempts to mount the filesystems again. If auto re-mount fails, try to manually reinsert the drive.

## What it does—and doesn’t do

- Processes detected USB or removable disks one at a time.
- Leaves NTFS metadata unchanged when the targeted mismatch isn’t detected.
- Skips partitions it can’t unmount and core system mount points.
- Attempts to mount detected filesystems again when it finishes.

This uses `ntfsfix`, which can repair some NTFS problems but is **not a full replacement for CHKDSK**. The script may not detect drives whose USB connection isn’t reported by Ubuntu as USB or removable. It can’t repair every filesystem error or hardware problem.
