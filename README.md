# os-lab2
bash script for a simple antivirus quarantine and restoring files

## 1. Overview

### Folder hierarchy

```
.
├── Makefile          # Shortcuts for running both tools with default arguments
├── antivirusd.sh     # Monitoring/scanning daemon
├── restore.sh        # Interactive quarantine review and restore tool
├── antivirus-cron.sh # One-shot scan meant to be run by cron
├── README.md         # This file
│
├── dir/              # (created at runtime if not already present) monitored directory
├── malicious_dir/    # (created at runtime if not already present) quarantine directory
│   └── white.list    # (created at runtime) date-modified + name of files that shouldn't be quarantined
├── directory-info.last   # (created at runtime) previous `ls -l` snapshot of dir
└── directory-info.new    # (created at runtime) latest `ls -l` snapshot of dir
```

> `antivirusd.sh` writes the two snapshot files in the **current working directory**. `antivirus-cron.sh` keeps `directory-info.last` / `directory-info.new` in the **parent folder of `malicious_dir`** (see [section 6](#6-scheduling-the-scan-with-cron-every-minute-at-second-23)).

### What each file does

**`antivirusd.sh`** takes three arguments: `<dir> <malicious_dir> <interval-secs>`.

1. Exits with an error if `dir` and `malicious_dir` are the same path.
2. Creates `dir` and `malicious_dir` if they don't exist, and creates an empty white list (`malicious_dir/white.list`) if there isn't one yet.
3. Runs an initial scan of every file in `dir`.
4. Loops forever: every `interval-secs` seconds it takes an `ls -l` snapshot of `dir` and compares it with the previous one using `cmp`. A full scan only runs when the snapshots differ, so an unchanged directory costs almost nothing.
5. A file is flagged as malicious if **either** condition is true:
   - its name ends with a flagged extension, or
   - its contents contain a flagged keyword (case-insensitive, via `grep -iq`).
6. Every flagged file is then checked against the **white list** (see [section 4](#4-the-white-list)). If its modification date and name match an entry, it is considered safe and left alone.
7. Flagged files that are not white-listed are **moved** into `malicious_dir` (so they are removed from `dir`), and a message such as `evil.exe is malicious and it is DELETED` is printed.

> `dir` should contain files only. Subdirectories are not supported.

**`restore.sh`** takes two arguments: `<dir> <malicious_dir>`.

1. Creates `malicious_dir/white.list` if it doesn't exist.
2. Lists the files currently in `malicious_dir` as a numbered menu. The white list file itself is never shown, so the numbers may skip one. If nothing but the white list is left, it prints `No malicious files to review.` and exits.
3. Lets you pick a file by number, or enter `q` to quit. Choosing the number of the white list file (or any invalid number) is rejected.
4. For the chosen file, offers three actions:
   - **1** – Restore: move the file back into `dir`, and **add its date modified + name to the white list** so the antivirus doesn't flag it again (use for false positives).
   - **2** – Permanently delete it from `malicious_dir` (it was genuinely malicious).
   - **3** – Leave it as is and return to the list.
5. Repeats until you quit or the quarantine is empty.

**`antivirus-cron.sh`** takes two mandatory arguments: `<dir> <malicious_dir>`

1. cron starts it at second 0 of every minute, and the script sleeps 23 seconds before doing anything, so the scan runs at second 23.
2. Exits with an error if `dir` and `malicious_dir` are the same path; creates both directories if missing.
3. Compares an `ls -l` snapshot of `dir` with the one from the previous run (`directory-info.last`). On the very first run there is no previous snapshot, so it scans immediately. Afterwards it only scans when the snapshots differ.
4. A scan uses the same flagging rules as `antivirusd.sh` (flagged extension or flagged keyword), **but it does not use the white list**.
5. Flagged files are moved to `malicious_dir` and `<name> is malicious and it is DELETED` is printed.
6. Exits.

**`Makefile`** provides two convenience targets:

| Target | Runs |
| - | - |
| `make run_antivirus` | `mkdir -p malicious_dir` then `./antivirusd.sh dir malicious_dir 2` (checks every 2 seconds) |
| `make run_restore` | `./restore.sh dir malicious_dir` |

## 2. Prerequisites

The scripts use only standard command-line tools (`bash`, `grep`, and the GNU coreutils (`ls`, `cp`, `mv`, `rm`, `mkdir`, `touch`, `cat`, `date`, `sleep`)) that should be preinstalled with Ubuntu, and `make` is the only one that may be missing.

| Requirement | Used for |
| - | - |
| `bash` | Running the scripts |
| `grep`, `coreutils`, `diffutils` (`cmp`) | Scanning, copying, and comparing snapshots |
| `make` | Using the Makefile shortcuts |

Install on Ubuntu:

```bash
sudo apt update # update package lists
sudo apt install -y make bash grep coreutils diffutils # install prerequisites (installs any missing ones)
```

Verify:

```bash
make --version
```
should print a version number, and

```bash
bash --version
```
should print a version number

## 3. Running the tools

### Starting the antivirus

**Using make (default settings):**

```bash
make run_antivirus
```

This monitors `./dir`, quarantines into `./malicious_dir`, and checks every 2 seconds.

**Or run it directly with your own settings:**

```bash
./antivirusd.sh <dir> <malicious_dir> <interval-secs>
# example:
./antivirusd.sh dir malicious_dir 5
```

The program runs until you stop it with `Ctrl+C`. Leave it running in its own terminal.

### Review and restore quarantined files

```bash
make run_restore
# or:
./restore.sh dir malicious_dir
```

> you should not run both scripts concurrently

## 4. The white list

The white list stops false positives from being quarantined over and over.

- **Location:** `malicious_dir/white.list` (created automatically by `antivirusd.sh` and `restore.sh`).
- **Format:** plain text, one entry per line: the file's **date modified** (as printed by `date -r <file>`) followed by a space and the file **name** (no path), e.g.:
  ```
  Tue Oct  6 14:02:11 EET 2026 setup.exe
  Tue Oct  6 14:05:40 EET 2026 notes-about-malware.txt
  ```
- **How it is filled:** every time you restore a file with option **1** in `restore.sh`, its date modified + name are appended automatically.
- **How it is used:** at the start of every scan, `antivirusd.sh` reads the list. A file that would be flagged is **not** quarantined if its current `date -r` output plus its name exactly match an entry (case-sensitive). Because the date is part of the match, **if a white-listed file is modified later it no longer matches and will be flagged again**.
- **Editing it by hand:** you can add entries with any text editor, but they must follow the exact `date -r` format above. To make a restored file subject to scanning again, delete its line.
- **`antivirus-cron.sh` ignores the white list.** A file restored with `restore.sh` will be quarantined again by the cron job if it still matches a flagged extension or keyword.

> `white.list` is not a quarantined file: `restore.sh` hides it from the menu, and it is not scanned because it lives in `malicious_dir`, not in `dir`.

## 5. Where the flagged lists are defined

Both lists are defined at the top of **`antivirusd.sh`**, on lines 3 and 4\
(same goes for **`antivirus-cron.sh`**):

```bash
flagged_extensions=(.exe .bat .vbs .scr .ps1)
flagged_content=(virus trojan malware worm ransomware)
```

To change what gets flagged, edit these arrays, adding or removing space-separated entries. Extensions include the leading dot, and keywords are plain words (matched anywhere in the file, not only as whole words). Edit both scripts if you use both tools.

## 6. Scheduling the scan with cron (every minute, at second 23)

### Prerequisites

1. **The cron service is installed and running.** (It is usually preinstalled on Ubuntu)
   Ubuntu/Debian
   ```bash
   sudo apt update
   sudo apt install -y cron            # install if missing
   sudo systemctl enable --now cron    # start now and on every boot
   systemctl status cron               # should say "active (running)"
   ```

    Fedora (what I tested and working on)
    ```bash
    sudo dnf update
    sudo dnf install -y crond
    sudo systemctl enable --now crond
    systemctl status crond               # should say "active (running)"
    ```

2. **All project files are in place**: `antivirus-cron.sh` in the project folder, and the `dir/` folder to monitor (the script creates `dir/` and `malicious_dir/` if missing).
3. **Stop `antivirusd.sh`** (`Ctrl+C`) and do not run `restore.sh` while the cron job is active. The tools should not run concurrently.

### Step-by-step

1. **Open a terminal in the project folder and note its path:**
   ```bash
   pwd
   ```
   output is `path/to/project/folder`

2. **Open your crontab for editing**:
   ```bash
   crontab -e
   ```

3. **Add this line at the end** (one single line, with your own **absolute** paths):
   ```cron
   * * * * * path/to/project/folder/antivirus-cron.sh path/to/dir/folder path/to/malicious_dir/folder
   ```
   | Part | Meaning |
   | - | - |
   | `* * * * *` | every minute |
   | `antivirus-cron.sh ... dir malicious_dir` | the script, with the monitored and quarantine directories |

   > The script sleeps 23 seconds after cron starts it, so the scan runs at second 23 of every minute.

4. **Save and exit** (in `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`).

5. **Confirm the job is installed:**
   ```bash
   crontab -l
   ```
   > you should see the line you just added 

6. **To stop the job**, run `crontab -e` and delete (or comment out with `#`) the line.