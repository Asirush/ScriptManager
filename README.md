# 🚀 Script Installer

This repository contains a collection of helper scripts to manage executable `.sh` utilities stored in the `scripts/` directory. It includes:

- `install.sh`: Installs scripts into a system-wide or user-wide path.
- `uninstall.sh`: Removes installed scripts.
- `update.sh`: Reinstalls or updates existing scripts.
- `check-installed.sh`: Verifies which scripts are currently installed.

---

## 📌 Features

- Automatically makes `.sh` scripts executable
- Installs scripts to `/usr/local/bin` (safe across macOS and Linux)
- Logs actions to `~/install.log`, `~/uninstall.log`, etc.
- Supports `--dry-run` to simulate actions without applying changes
- No need to type `.sh` when running installed scripts
- Verifies installed script state with `check-installed.sh`

---

## 🍏 macOS Users

⚠️ macOS has `/usr/bin` as **read-only** (due to SIP).  
✅ This script uses `/usr/local/bin`, which is writable and safe on macOS.

Make sure you have a recent version of Bash:
```bash
brew install bash
```

---

## ⚙️ Installation

### 1. Clone the Repository
```bash
git clone https://github.com/your-repo/script-installer.git
cd script-installer
```

### 2. Make Main Scripts Executable
```bash
chmod +x install.sh uninstall.sh update.sh check-installed.sh
```

### 3. Install Scripts
```bash
sudo ./install.sh
```

You can also test with:
```bash
./install.sh --dry-run
```

✅ This will:
- Make all `scripts/*.sh` executable
- Copy them to `/usr/local/bin` **without** the `.sh` extension
- Log all actions to `~/install.log`

---

## 📂 Installed Script Location

Scripts are copied to:
```bash
/usr/local/bin/
```

You can now run them from anywhere:
```bash
my-script      # instead of ./scripts/my-script.sh
```

---

## 🧹 Uninstallation

To remove installed scripts:
```bash
sudo ./uninstall.sh
```

Dry-run version:
```bash
./uninstall.sh --dry-run
```

---

## ♻️ Updating Scripts

To reinstall or update installed scripts:
```bash
sudo ./update.sh
```

Simulate updates without applying:
```bash
./update.sh --dry-run
```

---

## 🔍 Check Installed Scripts

To see which scripts from `scripts/` are currently installed:
```bash
./check-installed.sh
```

---

## 🛠 Usage Example

```bash
# Install everything
sudo ./install.sh

# Confirm installation
./check-installed.sh

# Update after editing a script
sudo ./update.sh

# Remove everything
sudo ./uninstall.sh
```

---

## 🧾 Logs

| Action        | Log File          |
|---------------|-------------------|
| Installation  | `~/install.log`   |
| Uninstallation| `~/uninstall.log` |
| Update        | `~/update.log`    |
| Check         | `~/check-installed.log` |

Use `cat ~/install.log` to inspect logs.

---

## 🔧 Troubleshooting

### 1. Script Not Found in Terminal
Ensure `/usr/local/bin` is in your `PATH`:

```bash
echo $PATH
```

If missing, add it:
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
For Zsh:
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

### 2. Scripts Not Found in `scripts/`
Ensure the `scripts/` directory contains at least one `.sh` file.

---

### 3. Permission Issues
Make sure scripts are executable:
```bash
chmod +x install.sh uninstall.sh update.sh
```

# Support This Project

If you find this project helpful, consider supporting it by donating via PayPal. Your contribution helps keep the project maintained and improved.

[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.me/AsirAbdukhalikov)

Thank you for your support!
