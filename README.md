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
│   └── white.list    # (created at runtime) names of files that shouldn't be quarantined
├── directory-info.last   # (created at runtime) previous `ls -l` snapshot of dir
└── directory-info.new    # (created at runtime) latest `ls -l` snapshot of dir
```

### What each file does

**`antivirusd.sh`** takes three arguments: `<dir> <malicious_dir> <interval-secs>`.

1. Creates `dir` and `malicious_dir` if they don't exist, and creates an empty white list (`malicious_dir/white.list`) if there isn't one yet.
2. Runs an initial scan of every file in `dir`.
3. Loops forever: every `interval-secs` seconds it takes an `ls -l` snapshot of `dir` and compares it with the previous one using `cmp`. A full scan only runs when the snapshots differ, so an unchanged directory costs almost nothing.
4. A file is flagged as malicious if **either** condition is true:
   - its name ends with a flagged extension, or
   - its contents contain a flagged keyword (case-insensitive, via `grep -iq`).
5. Every flagged file is then checked against the **white list** (see [section 4](#4-the-white-list)). If its name is on the list, it is considered safe and left alone.
6. Flagged files that are not white-listed are copied into `malicious_dir`, deleted from `dir`, and a message such as `evil.exe is malicious and it is DELETED` is printed.

> `dir` should contain files only. Subdirectories are not supported.

**`restore.sh`** takes two arguments: `<dir> <malicious_dir>`.

1. Creates `malicious_dir/white.list` if it doesn't exist.
2. Lists the files currently in `malicious_dir` as a numbered menu. The white list file itself is never shown, so the numbers may skip one. If nothing but the white list is left, it prints `No malicious files to review.` and exits.
3. Lets you pick a file by number, or enter `q` to quit. Choosing the number of the white list file is rejected as invalid.
4. For the chosen file, offers three actions:
   - **1** – Restore: copy the file back into `dir`, remove it from quarantine, and **add its name to the white list** so the antivirus doesn't flag it again (use for false positives).
   - **2** – Permanently delete it from `malicious_dir` (it was genuinely malicious).
   - **3** – Leave it as is and return to the list.
5. Repeats until you quit or the quarantine is empty.

**`antivirus-cron.sh`** takes two mandatory arguments: `[dir] [malicious_dir]`

1. cron starts it at second 0 of every minute, the scan runs at second 23.
2. Scans every file in `dir` once, using the same rules as `antivirusd.sh` (flagged extension or flagged keyword, minus white-listed names).
3. Copies flagged files to `malicious_dir`, deletes them from `dir`, and prints a timestamped message.
4. Exits. (A lock prevents two runs from overlapping.)

**`Makefile`** provides two convenience targets:

| Target | Runs |
| - | - |
| `make run_antivirus` | `mkdir -p malicious_dir` then `./antivirusd.sh dir malicious_dir 2` (checks every 2 seconds) |
| `make run_restore` | `./restore.sh dir malicious_dir` |

## 2. Prerequisites

The scripts use only standard command-line tools (`bash`, `grep`, and the GNU coreutils (`ls`, `cp`, `rm`, `mkdir`, `touch`, `cat`, `sleep`)) that should be preinstalled with Ubuntu, and `make` is the only one that may be missing.

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
- **Format:** plain text, one file name per line (name only, no path), e.g.:
  ```
  setup.exe
  notes-about-malware.txt
  ```
- **How it is filled:** every time you restore a file with option **1** in `restore.sh`, its name is appended automatically.
- **How it is used:** at the start of every scan, `antivirusd.sh` reads the list. A file that would be flagged is **not** quarantined if its name matches an entry exactly (case-sensitive).
- **Editing it by hand:** you can add names with any text editor. To make a restored file subject to scanning again, delete its line.

> `white.list` is not a quarantined file: `restore.sh` hides it from the menu, and it is not scanned because it lives in `malicious_dir`, not in `dir`.

## 5. Where the flagged lists are defined

Both lists are defined at the top of **`antivirusd.sh`**, on lines 3 and 4\
(same goes for **`antivirus-cron.sh`**):

```bash
flagged_extensions=(.exe .bat .vbs .scr .ps1)
flagged_content=(virus trojan malware worm ransomware)
```

To change what gets flagged, edit these arrays, adding or removing space-separated entries. Extensions include the leading dot, and keywords are plain words (matched anywhere in the file, not only as whole words).

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

2. **`flock`** (from `util-linux`) must exist, and it is preinstalled on Ubuntu. Check with `flock --version`.
3. **All project files are in place**: `antivirus-cron.sh` in the project folder, and the `dir/` folder to monitor (the script creates `dir/` and `malicious_dir/` if missing).
4. **Stop `antivirusd.sh`** (`Ctrl+C`) and do not run `restore.sh` while the cron job is active. The tools should not run concurrently.

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

3. **Add this line at the end** (one single line, with your own absolute path):
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