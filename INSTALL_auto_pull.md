# Automatic Git Pull with PowerShell 7 and Deploy Key

This document explains how to set up an **automatic git pull** for a private GitHub repository using:

- **PowerShell 7**
- An **SSH deploy key** (same key can be used on multiple machines, if you want)
- The script `auto-pull.ps1`

Instructions are given for **Windows** and **Linux**.

---

## 1. Prerequisites (GitHub side, not for users)

1. Generate an SSH key pair in shell (this can be done on any machine):

   ```bash
   ssh-keygen -t ed25519 -C "deploy-key-afm-analysis" -f id_ed25519_afm_analysis
   ```
   
   When asked, enter a valid passphrase which every user needs to provide when requesting an auto pull.


   This creates:

   - `id_ed25519_afm_analysis` (private key)
   - `id_ed25519_afm_analysis.pub` (public key)

2. Open the `.pub` file and copy its contents:

   ```bash
   cat id_ed25519_afm_analysis.pub
   ```

   You should see something like:

   ```text
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... deploy-key-afm-analysis
   ```

3. In GitHub:

   - Go to **your repository** → **Settings** → **Deploy keys** → **Add deploy key**
   - Paste the full public key line
   - Give it a title (e.g. `afm-analysis-deploy-key`)
   - Tick **Allow write access** only if you also want to push. For pull-only, leave it unchecked.
   - Save

4. You now have a key pair you can distribute (carefully):

   - Keep the **private key** secret.
   - The **public key** is already safe to share.

You can copy the private key file to multiple machines if you want them all to pull the same repo automatically.

---

## 2. Setup on Windows

### 2.1 Install PowerShell 7 (if not installed)

1. Go to the official PowerShell download page (search for “PowerShell 7 GitHub releases”).
2. Download the latest **PowerShell 7 (x64) MSI** for Windows.
3. Run the installer and accept the defaults.
4. After installation, start **PowerShell 7**:
   - Press `Win`, type `pwsh`, and hit Enter  
   or  
   - Use the PowerShell 7 shortcut created by the installer.

You should see something like:

```text
PowerShell 7.X.X
PS C:\Users\YourUser>
```

### 2.2 Install Git (if not installed)

1. Download “Git for Windows” (search for “git for windows download”).
2. Run the installer, keep defaults unless you know you want something else.
3. In PowerShell 7, verify:

   ```powershell
   git --version
   ```

   It should print something like `git version 2.xx.x`.

### 2.3 Copy the SSH key into `.ssh` folder

We assume:

- Your Windows username is `YourUser`
- You have the private key file called `id_ed25519_afm_analysis` on e.g. a USB stick or network drive.

1. Create the `.ssh` folder if it doesn’t exist:

   ```powershell
   New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
   ```
   
2. Copy your private and public key into that folder 

3. Ensure the permissions are reasonable (Windows is usually fine by default, but just in case):

   ```powershell
   icacls "$HOME\.ssh\id_ed25519_afm_analysis"
   ```

   Make sure it is only readable by you or by the users you trust on that machine.

### 2.4 Test the SSH key

1. Disable strict host key checking for the first test or accept it interactively.
2. Run and enter passphrase when promted:

   ```powershell
   ssh -i "$HOME\.ssh\id_ed25519_afm_analysis" -o IdentitiesOnly=yes git@github.com
   ```

   You should get something like:

   ```text
   Hi username! You've successfully authenticated, but GitHub does not provide shell access.
   Connection to github.com closed.
   ```

   If you see permission issues, you might be using the wrong key or the wrong repo URL.

---

## 3. Setup on Linux

### 3.1 Install PowerShell 7

Look up the instructions for your distribution (Ubuntu, Debian, Fedora, etc.) under “Install PowerShell on Linux”. In short:

- On Ubuntu:

  ```bash
   # Update the list of packages
   sudo apt-get update
   
   # Install pre-requisite packages.
   sudo apt-get install -y wget apt-transport-https software-properties-common
   
   # Get the version of Ubuntu
   source /etc/os-release
   
   # Download the Microsoft repository keys
   wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb
   
   # Register the Microsoft repository keys
   sudo dpkg -i packages-microsoft-prod.deb
   
   # Delete the Microsoft repository keys file
   rm packages-microsoft-prod.deb
   
   # Update the list of packages after we added packages.microsoft.com
   sudo apt-get update
   
   ###################################
   # Install PowerShell
   sudo apt-get install -y powershell
  ```

- Start PowerShell:

  ```bash
  pwsh
  ```

You should see a `PS` prompt instead of the usual `$`.

### 3.2 Install Git

On most Linux systems:

```bash
sudo apt-get update
sudo apt-get install git  # or corresponding package manager
```

Verify:

```bash
git --version
```

### 3.3 Copy the SSH key into `~/.ssh`

Assuming your private key is called `id_ed25519_afm_analysis`:

1. Create the `.ssh` directory if necessary:

   ```bash
   mkdir -p ~/.ssh
   ```

2. Copy the private and public key files into it. Folder might be hidden but can be accessed by /home/user/.ssh/


3. Set the correct permissions:

   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_ed25519_afm_analysis
   ```

### 3.4 Test the SSH key

```bash
ssh -i ~/.ssh/id_ed25519_afm_analysis -o IdentitiesOnly=yes git@github.com
```

You should get the same “You’ve successfully authenticated” message.

---

## 4. Using `auto-pull.ps1`

Place the script `auto-pull.ps1` somewhere on your Windows or Linux machines, e.g. in a folder `C:\Scripts` or `~/scripts`.

### 4.2 Run the script

**Windows:**

```powershell
pwsh "C:\path\to\auto-pull.ps1"
```

**Linux:**

```bash
pwsh /path/to/auto-pull.ps1
```

You can add `-HardReset` if you always want to force the local repo to match remote:

```bash
pwsh /path/to/auto-pull.ps1 -HardReset
```

---

## 5. Using the same key on multiple machines

- You can copy `id_ed25519_afm_analysis` to the `.ssh` folder of each machine.
- Each machine will then be able to **pull** (and optionally push) that specific repository.
- If one machine is compromised, you’ll need to **remove that deploy key from GitHub** and create a new one.