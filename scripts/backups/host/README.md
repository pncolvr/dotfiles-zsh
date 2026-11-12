# Host backup

`create.sh` uses rsync to back up `/home`, plus the system files a fresh OS install can't bring back, to an external disk (**Tardis**).

The recovery plan is to **reinstall the OS**, restore `/home`, then reinstall packages and copy back whatever configs and data you need. The script deliberately doesn't back up or restore the whole of `/`.

```sh
backup                     # zsh function in .zshrc: runs create.sh backup with sudo
sudo ./create.sh backup
sudo ./create.sh restore
backup-browse              # zsh function: runs create.sh browse (no sudo)
./create.sh browse         # mount the disk and open the backup in the file manager
backup-eject               # zsh function: runs create.sh eject
./create.sh eject          # flush, unmount and power off the disk
```

`browse` must run **without** `sudo`, so the file manager opens as your user and in your desktop session. It only asks for your password to mount the disk. It leaves the disk mounted and prints the command to unmount and power it off when you're done.

Backups go to `/mnt/Tardis/<hostname>/` (`BACKUP_ROOT` at the top of `create.sh`):

```
home/                         copy of /home (minus caches and other excludes)
system-essentials/
  packages/pkglist.txt        explicitly installed repo packages (pacman -Qqen)
  packages/aur.txt            explicitly installed AUR/foreign packages (pacman -Qqem)
  files/etc, files/opt, ...   SYSTEM_PATHS, copied with their full paths
```

`SYSTEM_PATHS` in `create.sh` lists what goes into `system-essentials/files`. Paths that don't exist are skipped.

| Path | Why |
| --- | --- |
| `/etc` | fstab, sudoers, pacman.conf, mkinitcpio, GRUB, udev rules, systemd units, network and Wi-Fi configs |
| `/opt`, `/usr/local` | software installed by hand |
| `/root`, `/srv` | root's home, served data |
| `/var/spool/cron` | crontabs (cronie) |
| `/var/lib/libvirt` | VM disks and definitions |

Commented out in `SYSTEM_PATHS`, so not backed up. Uncomment a line to include it:

| Path | Why it's off |
| --- | --- |
| `/var/lib/docker` | images and volumes; can be large |
| `/var/lib/mysql` | database files; only MariaDB's client library is installed, so this is probably left over from an old install |

Also not included: `/var/lib/flatpak` (reinstall the apps instead), and everything else under `/` that comes with the packages.

**Live data:** VM disks (and Docker or database files, if you turn them on) are copied while their services may be running. A copy of a running VM or database can be inconsistent. For a guaranteed clean copy, shut down the VMs first, or stop the services (`sudo systemctl stop libvirtd docker`).

## What's skipped in `/home`

`HOME_FILTERS` in `create.sh` is a list of rsync filter rules. The aim is to keep configs and the main folders (Documents, Pictures, Projects source, ...) and skip anything that can be recreated. On the machine this was written for, the backup came out about 75% smaller.

- **Caches:** `~/.cache`, plus the `Cache`, `Code Cache`, `GPUCache`, `CachedData`, `*ShaderCache`, `Dawn*Cache` and `Crashpad` folders under `.config` and `.local/share`.
- **Build output in `Projects`:** `bin`, `obj`, `target`, `.gradle`, and anywhere in home `node_modules`, `.dart_tool`, `__pycache__`, `.venv`. `build/` and `dist/` are kept, because some projects commit files there.
- **Apps:** browsers (they sync), Discord, Teams, Steam, the Locally Uncensored data folders, Heroic's `Partitions` and `tools` (its config is kept), ComfyUI `models` and `venv`.
- **Toolchains and package caches:** rustup, cargo registry, go, dotnet, nuget, npm, nvm, fnm, pyenv, conda, pipx, yarn, pub-cache, ollama, `~/.vscode` (extensions).
- **VS Code:** only `.config/Code/User` is kept, minus `workspaceStorage`. `.local/share/vscode-profiles` is kept in full.

How the rules work:
- The **first rule that matches wins**, which is why the `+` (keep) rules are at the top.
- Paths are relative to `/home/`, so `/*/go/` means `~/go` for every user. It doesn't match a `go` folder inside a project. A pattern without a leading `/`, like `node_modules/`, matches at any depth.
- `--delete-excluded` also removes newly excluded paths from the existing backup on the next run.

To test a change without copying anything, list what would be backed up:

```sh
rsync -anx --stats --filter='- /*/.cache/' ... /home/ /tmp/none/ | tail
```

## Restoring after a reinstall

`sudo ./create.sh restore` restores **only `/home`**. It then prints where everything else is:

```sh
sudo pacman -S --needed - < /mnt/Tardis/<hostname>/system-essentials/packages/pkglist.txt
paru -S --needed - < /mnt/Tardis/<hostname>/system-essentials/packages/aur.txt   # or your AUR helper
```

Copy configs back from `system-essentials/files/etc` file by file. Don't overwrite the new `/etc` wholesale: fstab UUIDs and machine-id will be different. To bring back Docker or libvirt data, stop the service, rsync the directory back with `-aAXH`, then start it again.

## What the script does

1. Mounts `/mnt/Tardis` if it isn't already mounted (`sudo mount /mnt/Tardis`, which reads its settings from fstab).
2. Checks that `/mnt/Tardis` is a mountpoint before every step: before `mkdir` and before each rsync.
3. Runs the rsyncs.
4. Unmounts the disk and powers it off on exit, including on errors and Ctrl+C. This happens even if the disk was already mounted before you started (`browse` is the exception: it leaves the disk mounted).

Before unmounting, the script runs `sync` and prints "Flushing writes...", because on a USB disk writing out the cache can take a while. If the disk is busy, it retries for 10 seconds. If it's still busy after that, it lists the processes using the disk (`fuser -vm`) and leaves it mounted: close them and run `sudo umount /mnt/Tardis`. A common culprit is a terminal whose current directory is somewhere on the disk.

After unmounting, it runs `udisksctl power-off` to spin the disk down and cut its USB power, the same as "Safely remove" in a file manager. Unplug only after you see "safe to unplug". To power it off by hand: `udisksctl power-off -b /dev/disk/by-label/Tardis`.

## One-time setup

The disk has to mount at a fixed path from `/etc/fstab`, not at udisks' default `/run/media/$USER/Tardis`.

**1. Create the mountpoint and make it immutable.** Do this while the disk is **not** mounted:

```sh
sudo mkdir -p /mnt/Tardis
sudo chattr +i /mnt/Tardis
lsattr -d /mnt/Tardis      # should show ----i---------
```

**2. Find the disk's UUID and filesystem type.** Plug the disk in and run:

```sh
lsblk -o NAME,LABEL,UUID,FSTYPE,MOUNTPOINTS
```

Find the row for your backup partition, for example `sdd1  Tardis  1a2b3c4d-...  ext4`. Use the UUID of the **partition** (`sdd1`), not the whole disk (`sdd`). Run `sudo blkid` for the same information.

**3. Add a line to `/etc/fstab`** (`sudo -e /etc/fstab`). Replace `<your-uuid>` with that UUID, and `ext4` with its FSTYPE if it's different:

```
UUID=<your-uuid>  /mnt/Tardis  ext4  nosuid,nodev,nofail,noauto,x-gvfs-show,x-udisks-auth  0 2
```

**4. Reload and test:**

```sh
sudo systemctl daemon-reload
udisksctl mount -b /dev/disk/by-uuid/<your-uuid>
findmnt /mnt/Tardis
```

### fstab options

| Option | Why |
| --- | --- |
| `UUID=…` | Identifies this exact disk, so another disk labelled "Tardis" never gets mounted there. Look it up with `lsblk -o NAME,LABEL,UUID,FSTYPE`. |
| `noauto` | Don't mount at boot. The script or the file manager mounts it when needed. |
| `nofail` | Boot doesn't stall if the disk is missing. |
| `nosuid,nodev` | Ignore setuid bits and device files on the disk. |
| `x-gvfs-show` | Show it in the file manager or device notifier. |
| `x-udisks-auth` | Let your normal user mount it through udisks (it may ask for your password). |
| `0 2` | Not dumped; checked with fsck after the root filesystem. |

When a disk has an fstab entry, udisks mounts it at that path. Clicking it in the file manager also mounts it on `/mnt/Tardis`.

## Why it's set up this way

If the disk isn't mounted, rsync writes into the empty mountpoint directory, which is on another filesystem, and fills it.

- **While rsync is running** this can't happen. A normal `umount` fails with "target is busy". A lazy `umount -l` or pulling the cable doesn't redirect writes either: rsync keeps writing to the detached disk, or fails with I/O errors.
- **Between steps** it can happen. If the disk goes away after the check, `mkdir -p` and the next rsync would write to whatever is now at that path. The checks before each step make that gap small.
- **`chattr +i` on the mountpoint** closes the gap completely. The **immutable** flag means nothing can be created inside the directory, not even by root. When the disk is mounted, the disk's own root directory covers it, so the flag only matters while the disk is unmounted. Remove it with `sudo chattr -i /mnt/Tardis`.
- **Why not `/run/media`:** udisks creates that directory when it mounts and deletes it when it unmounts, so you can't set the flag on it. `/run` is also a tmpfs held in RAM, so a backup that ran with the disk missing would fill RAM.
- **No `--delete-before`:** it makes rsync scan the whole source and destination before copying anything, so a run sits silent for minutes at the start. `--delete-excluded` already turns on `--delete`, which deletes old files during the transfer and lets copying start right away.
- **`rsync -x`** only applies to the source (don't cross filesystems). It doesn't protect the destination.
