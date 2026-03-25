# holo-node-iso

Welcome to the Holo Node! This operating system image allows you to turn your hardware (like a HoloPort or a standard PC) into a dedicated edge node. It automatically installs a customized, secure operating system that boots directly into the Holo node stack.

Whether you want to host applications on the edge, secure a private Moss group, or run automated wind-tunnel tests, this guide will walk you through the entire setup process.

---

## Table of Contents

1. [Why Run an Edge Node? (The "Always-On" Advantage)](#why-run-an-edge-node-the-always-on-advantage)
2. [What can you do with a Holo Node?](#what-can-you-do-with-a-holo-node)
3. [Why You Can Relax: Our Security First Approach](#why-you-can-relax-our-security-first-approach)
4. [Complete Node Setup Guide](#complete-node-setup-guide)
   * [Part 1: Flashing and Booting](#part-1-flashing-and-booting)
   * [Part 2: Generating an SSH Key](#part-2-generating-an-ssh-key)
   * [Part 3: Configuring Your Node](#part-3-configuring-your-node)
5. [Managing Your Node](#managing-your-node)
6. [Developer & Build Documentation](#developer--build-documentation)

---

## 🤔 Why Run an Edge Node? (The "Always-On" Advantage)

In an era of centralized cloud computing, our digital lives are often placed in a shockingly low number of baskets. When massive data centers experience outages or change their terms of service, your ability to communicate and collaborate can vanish instantly. Running an Edge Node shifts the power dynamics of the internet back to you.

Here is why you need a dedicated Edge Node for your peer-to-peer applications (like those in your Moss group):

**Solving the Peer-to-Peer Sync Problem:** In a true decentralized app, at least two people need to be online at the same time to share and sync data. If you add a file and go offline before a teammate logs on, that data is temporarily unavailable. An Edge Node acts as a dedicated, 24/7 member of your group. It holds an encrypted copy of the group's data, ensuring anyone who comes online can instantly sync up with the latest information.

**True Resilience When the Cloud Breaks:** Major outages at hyperscalers (like AWS or Cloudflare) can bring your business or personal communications to a grinding halt. An Edge Node provides a decentralized, redundant pathway to stay in touch. It ensures you have a private, resilient channel to reach your team or family when mainstream services go dark.

**Total Data Sovereignty & Privacy:** Mainstream apps require you to route your data through their central servers, making your information vulnerable to hacks, surveillance, or algorithmic compression. With an Edge Node, your data is end-to-end encrypted and exists only with the people who create it.

**Perfect for:**

* **Investment & Crypto Clubs:** Share analysis and track portfolios with the mathematical certainty that only members have access.
* **Off-Grid Expedition Planners:** Share sensitive GPS coordinates and emergency protocols without creating a permanent, trackable record on a commercial server.
* **Mastermind & Start-up Groups:** Keep strategic conversations, business plans, and candid feedback strictly confidential.

---

## 🛠️ What can you do with a Holo Node?

Once your node is installed and running, you can operate it in different modes depending on your goals:

* **Edge Node Mode:** Run and host decentralized applications directly on your hardware at the edge of the network. This acts as the always-on backbone for your peer-to-peer Moss hApps.
* **Wind Tunnel Mode:** Use your node as a dedicated testing environment to run performance, stress, and wind-tunnel tests for your own apps before deploying them widely.

---

## 🛡️ Why You Can Relax: Our Security First Approach

Running a node on your local network might sound intimidating, but we have built the Holo Node with extreme security precautions so you can operate it with total peace of mind:

* **Immutable Operating System:** The base OS (Fedora CoreOS) is locked down. Core system files cannot be easily altered by malicious actors.
* **No Passwords:** Traditional password logins are completely disabled over the network. The only way to access the system remotely is via the highly encrypted SSH key you generate on your own computer.
* **Root Login Disabled:** Administrator (root) network login is blocked by default.
* **Restricted sudo:** The holo user has restricted sudo privileges exclusively for `systemctl`, `podman`, and `journalctl`.
* **Automatic Updates:** The node automatically pulls background security patches and nightly container image refreshes, so you are never left running outdated, vulnerable software.

---

## 🚀 Complete Node Setup Guide

This guide is written for everyone. Even if you aren't highly technical, following these steps from start to finish will get your node running and securely connected to your own personal AI assistant.

### Part 1: Flashing and Booting

1. **Download the Installer:** Download the latest edge node installer image (`.iso` file) from our [GitHub Releases](../../releases). *(Make sure to download the `.iso` file, not the source code folder).*
2. **Flash to a USB Drive:** You need a USB stick with at least 8GB of space. Use a free tool like [balenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/). Open the tool, select the downloaded `.iso` image, select your USB drive, and click **Flash**. Wait for it to complete.
3. **Boot the Device:** Insert the flashed USB stick into your hardware (e.g., your HoloPort or PC). Connect a monitor, a keyboard, and an ethernet cable connected to your internet router. Turn the device on and press **F11** (or your system's boot menu key) repeatedly to boot from the USB drive.
4. **Automatic Installation:** The system will automatically install the operating system. No manual interaction is required here.

   > **Important:** When the installation finishes, a password will be displayed on the screen. **Write this password down.** You will need it later. Remove the USB stick and let the system reboot.

5. **Find the IP Address:** Once rebooted, the monitor will display an IP address assigned by your router (it usually looks like `192.168.x.x`). Keep this number handy.
6. **Open the Setup Interface:** On a separate laptop or PC connected to the same WiFi/network, open a web browser and type in that IP address followed by `:8080`.

   Example: `http://192.168.1.50:8080`

   The node will automatically redirect you to the onboarding setup page.

### Part 2: Generating an SSH Key

To securely connect your computer to your new node, you need to generate an "SSH Key." It acts as a highly secure digital handshake.

#### For Windows Users:

1. Click your **Start** menu, type **PowerShell**, and open it.
2. Type the following command (replace with your actual email) and press **Enter**:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
3. The system will ask where to save the key. Press **Enter** to accept the default location.
4. It will ask for a passphrase. Leave it blank and press **Enter** twice.
5. Type this command to view your new public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
6. A long line of text starting with `ssh-ed25519` will appear. Highlight and **copy this entire line**.

#### For Mac / Linux Users:

1. Open the **Terminal** application.
2. Type the following command (replace with your actual email) and press **Enter**:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
3. Press **Enter** to accept the default file location.
4. Press **Enter** twice to skip creating a passphrase.
5. Type this command to view your public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
6. Copy the entire output string that begins with `ssh-ed25519`.

### Part 3: Configuring Your Node

Now that you have your SSH key, return to the setup page in your web browser.

1. **Paste your SSH Key:** Paste the key you just copied into the **SSH Public Key** field.
2. **Choose your Mode:** Give your node a name, and select either **Edge Node Mode** (for hosting apps) or **Wind Tunnel Mode** (for testing apps).
3. **Finish Setup:** Submit the onboarding form. Your node is now fully configured and your AI is ready to chat!

---

## 💻 Managing Your Node

Once onboarding is complete, you can monitor and adjust your node's settings at any time. Simply open your web browser and navigate back to your node's IP address (e.g., `http://192.168.1.50:8080`).

The system will recognize that you have already onboarded and will automatically redirect you to your management dashboard. From this dashboard, you can:

* View system health
* Deploy apps to the edge
* Trigger wind-tunnel tests
* Update your AI agent configurations

---

## 🧑‍💻 Developer & Build Documentation

> **Note for contributors:** If you are looking to modify the underlying Fedora CoreOS image, compile the Butane configurations, or test the GitHub Actions pipeline, please refer to our detailed developer documentation.

* **Building Locally & Architecture** ([docs/development.md](docs/development.md)): Instructions on using `butane` and `coreos-installer`, boot flow explanations, and systemd unit configs.
