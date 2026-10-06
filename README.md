# os-lab2
bash script for a simple antivirus quarantine and restoring files

## 1. Overview

### Folder hierarchy

```
.
├── Makefile          # Shortcuts for running both tools with default arguments
├── antivirusd.sh     # Monitoring/scanning daemon
├── restore.sh        # Interactive quarantine review and restore tool
├── README.md         # This file
│
├── dir/              # (created at runtime if not already present) monitored directory
├── malicious_dir/    # (created at runtime if not already present) quarantine directory
├── directory-info.last   # (created at runtime) previous `ls -l` snapshot of dir
└── directory-info.new    # (created at runtime) latest `ls -l` snapshot of dir
```

### What each file does

**`antivirusd.sh`** takes three arguments: `<dir> <malicious_dir> <interval-secs>`.

1. Creates `dir` and `malicious_dir` if they don't exist.
2. Runs an initial scan of every file in `dir`.
3. Loops forever: every `interval-secs` seconds it takes an `ls -l` snapshot of `dir` and compares it with the previous one using `cmp`. A full scan only runs when the snapshots differ, so an unchanged directory costs almost nothing.
4. A file is flagged as malicious if **either** condition is true:
   - its name ends with a flagged extension, or
   - its contents contain a flagged keyword as a whole word (case-insensitive, via `grep -iwq`).
5. Flagged files are copied into `malicious_dir`, deleted from `dir`, and a message such as `evil.exe is malicious and it is DELETED` is printed.

> `dir` should contain files only. Subdirectories are not supported.

**`restore.sh`** takes two arguments: `<dir> <malicious_dir>`.

1. Lists the files currently in `malicious_dir` as a numbered menu (or prints `No malicious files to review.` and exits if it is empty).
2. Lets you pick a file by number, or enter `q` to quit.
3. For the chosen file, offers three actions:
   - **1** – Restore: copy the file back into `dir` and remove it from quarantine (use for false positives).
   - **2** – Permanently delete it from `malicious_dir` (it was genuinely malicious).
   - **3** – Leave it as is and return to the list.
4. Repeats until you quit or the quarantine is empty.

**`Makefile`** provides two convenience targets:

| Target               | Runs                                                                                         |
| -------------------- | -------------------------------------------------------------------------------------------- |
| `make run_antivirus` | `mkdir -p malicious_dir` then `./antivirusd.sh dir malicious_dir 2` (checks every 2 seconds) |
| `make run_restore`   | `./restore.sh dir malicious_dir`                                                             |

## 2. Prerequisites

The scripts use only standard command-line tools (`bash`, `grep`, and the GNU coreutils (`ls`, `cp`, `rm`, `mkdir`, `sleep`)) that should be preinstalled with Ubuntu, and `make` is the only one that may be missing.

| Requirement                              | Used for                                |
| ---------------------------------------- | --------------------------------------- |
| `bash`                                   | Running the scripts                     |
| `grep`, `coreutils`, `diffutils` (`cmp`) | Scanning, copying, and comparing snapshots  |
| `make`                                   | Using the Makefile shortcuts |

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

## 4. Where the flagged lists are defined

Both lists are defined at the top of **`antivirusd.sh`**, on lines 3 and 4:

```bash
flagged_extensions=(.exe .bat .vbs .scr .ps1)
flagged_content=(virus trojan malware worm ransomware)
```

To change what gets flagged, edit these arrays, adding or removing space-separated entries. Extensions include the leading dot, and keywords are plain words.
