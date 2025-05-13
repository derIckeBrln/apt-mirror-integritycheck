# 🧪 check-apt-mirror.sh

A validation and repair script for local APT mirrors created with [`apt-mirror`](https://manpages.ubuntu.com/manpages/latest/man1/apt-mirror.1.html).  
It verifies `.Packages`, `.Packages.gz`, and `.Packages.xz` files against their expected checksums from `Release` files and optionally repairs broken files.

---

## ✅ Features

- Parses `/etc/apt/mirror.list` to determine which distributions, components, and architectures are relevant
- Verifies:
  - File existence
  - File size and SHA256 checksum match
- Supports:
  - Dry-run mode for safe verification
  - `--fix` mode to automatically remove corrupted files
  - Automatic `apt-mirror` execution if any files were fixed

---

## 📁 Requirements

- A functioning APT mirror created using `apt-mirror`
- Bash environment with:
  - `bash`, `grep`, `awk`, `stat`, `sha256sum`

---

## 🔧 Usage

```bash
chmod +x check-apt-mirror.sh
```

### 🕵️ Run in validation-only mode:

```bash
./check-apt-mirror-integrity.sh
```

### 🔧 Run in fix mode (delete broken files + trigger apt-mirror):

```bash
./check-apt-mirror-integrity.sh --fix
```

If any invalid Packages* files are found, they will be removed and re-downloaded via apt-mirror.

## 🔄 Cron Integration (Recommended)

To automate validation and repair daily at 4:00 AM:

```
0 4 * * * root /usr/local/bin/check-apt-mirror.sh --fix >> /var/log/apt-mirror-check.log 2>&1
```

## 🧱 Notes

The script only checks architectures and components defined in mirror.list
- Currently verifies only Packages, Packages.gz, Packages.xz
- You can modify supported architectures directly in the script (default: amd64, i386)
