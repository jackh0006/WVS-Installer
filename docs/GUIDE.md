# The super simple guide

This guide assumes you have never used a terminal. Follow it one line at a time.
Nothing here can break your computer.

---

## What you need before you start

1. A **Linux computer** (Ubuntu, Debian, Mint, Fedora, Arch…).
2. A **Windows VPS** — a Windows computer in a data centre that you can log in to.
3. Three things from your VPS provider:
   * the **address** (looks like `203.0.113.10` or `myvps.example.com`),
   * the **username** (often `Admin` or `Administrator`),
   * the **password**.

If you do not have these, ask your VPS provider. This installer cannot guess them.

---

## Step 1 — Open the black window

Press these three keys together:

```text
Ctrl + Alt + T
```

A black window opens. It is called a **terminal**. It is not dangerous. You type
in it, press Enter, and it does what you asked.

---

## Step 2 — Get the installer

Type this line exactly, then press **Enter**:

```bash
git clone https://github.com/jackh0006/WVS-Installer.git
```

Then type this line and press **Enter**:

```bash
cd WVS-Installer
```

> **No `git`?** Run `sudo apt install git` first, or download the release file
> and use the next step instead.

> **Already have the file?** If you downloaded `vps-setup.sh` to your Downloads
> folder, type:
> ```bash
> cd ~/Downloads
> chmod +x vps-setup.sh
> ./vps-setup.sh
> ```
> and skip to Step 4.

---

## Step 3 — Start the installer

Type this and press **Enter**:

```bash
./vps-setup.sh
```

You will see a friendly screen:

```text
==============================================================
  Windows VPS - easy one-word setup   (version 2.0.0)
==============================================================

Three short questions, then I do everything myself.

1/3  VPS address (IP or hostname):
```

---

## Step 4 — Answer three questions

### Question 1

```text
1/3  VPS address (IP or hostname):
```

Type the address your provider gave you. Then press **Enter**.

### Question 2

```text
2/3  Username [Admin]:
```

If your username is `Admin`, just press **Enter**. Otherwise type it and press
**Enter**.

### Question 3

```text
3/3  Password for Admin (it will not be shown):
```

Type the password. **Nothing will appear on the screen** — no stars, no dots.
That is normal and it is safer this way. Press **Enter**.

It asks you to type it once more. Do the same again.

> If you see `press Enter to keep the saved one`, the installer already knows the
> password. Just press **Enter**.

---

## Step 5 — Let it work

It will print six short steps:

```text
Step 1/6  Checking this computer...
Step 2/6  Administrator rights (asked once)...
Step 3/6  Installing what is needed...
Step 4/6  Saving your settings...
Step 5/6  Creating the 'vps' command...
Step 6/6  Checking the result...
          settings: OK
          connection test: OK
```

At Step 2 it asks for **your own computer's password**. This is the password you
use to log in to Linux. It is only used to install software, and it is never
saved. Type it and press **Enter**.

At the end you will see:

```text
==============================================================
  All done!

  Open a terminal and type:   vps
==============================================================
```

---

## Step 6 — Connect

Type:

```bash
vps
```

Press **Enter**.

The Windows desktop opens, fullscreen. That is it. You are done forever.

Next time you turn on the computer:

```text
Open terminal  ->  type vps  ->  press Enter  ->  Windows
```

---

## What the commands mean

You only need one:

| Type this | What happens |
|-----------|--------------|
| `vps` | opens your Windows desktop |
| `vps help` | shows all the small extra commands |
| `vps test` | checks whether the VPS can be reached |
| `vps setup` | changes the address, user or password |
| `vps` then `Ctrl+Alt+Enter` | leaves or enters fullscreen |

---

## If something looks wrong

| What you see | What to do |
|--------------|------------|
| `vps: command not found` | Close the terminal, open a new one, try again. Still stuck? Run `vps-setup.sh` again. |
| The screen is small in the middle | Press `Ctrl + Alt + Enter`. |
| `Credentials rejected` / wrong password | Run `vps setup` and type the password again carefully. Use the local Windows account, not a Microsoft account. |
| Black screen after logging in | Wait 10 seconds. If it stays black, press `Ctrl + Alt + End`, open Task Manager, restart Explorer. |
| Nothing connects | Run `vps test`. It tells you whether the network or the VPS is the problem. |
| It worked before, now it does not | Your VPS may be off, or its IP changed. Check your provider's control panel, then run `vps setup`. |

More detail: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## How to remove everything

```bash
vps-setup.sh --uninstall
```

Or, from the folder you cloned:

```bash
./vps-setup.sh --uninstall
```

It removes everything it added. Your other files are not touched.

---

## Is it safe?

Yes, and you can check for yourself:

* it is one text file you can read,
* it never sends your password anywhere except to the VPS you chose,
* it stores the password in the system keyring, protected by your login,
* it keeps a backup of every file it replaces,
* it has no telemetry and no accounts.

The full explanation is in [HOW-IT-WORKS.md](HOW-IT-WORKS.md) and
[SECURITY.md](../SECURITY.md).
