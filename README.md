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
6. [Verifying Wind Tunnel Mode](#verifying-wind-tunnel-mode)
7. [Troubleshooting](#troubleshooting)
8. [Developer & Build Documentation](#developer--build-documentation)

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
* **Wind Tunnel Mode:** Use your node as a dedicated stress-testing participant in the Holochain network. The node registers itself as a Nomad client and runs continuous performance tests.

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

5. **Open the Setup Interface:** On a separate laptop or PC connected to the same WiFi/network, open a web browser and go to:

   `http://holo.local:8080`

   The node advertises itself on your local network via mDNS, so you do not need to look up its IP address. The node will automatically redirect you to the onboarding setup page.

   > **Fallback:** If `holo.local` does not resolve (some corporate networks block mDNS), the monitor will display the node's IP address assigned by your router (usually `192.168.x.x`). Use `http://<node-ip>:8080` instead.

   > **Note:** After onboarding, if you chose a custom node name during setup, the local address may change to `http://<node-name>.local:8080`.

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

Once onboarding is complete, you can monitor and adjust your node's settings at any time. Simply open your web browser and navigate to `http://holo.local:8080` (or `http://<node-name>.local:8080` if you set a custom name during onboarding). If mDNS is unavailable on your network, use the node's IP address instead (e.g., `http://192.168.1.50:8080`).

The system will recognize that you have already onboarded and will automatically redirect you to your management dashboard. From this dashboard, you can:

* View system health
* Deploy apps to the edge
* Trigger wind-tunnel tests
* Update your AI agent configurations

---

## 🌬️ Verifying Wind Tunnel Mode

When your node is set up in Wind Tunnel mode, it registers itself as a Nomad client with the Holochain test network. You can confirm it is active and reporting correctly in two ways.

### Check the public status dashboard

Visit **[https://wind-tunnel-runner-status.holochain.org/](https://wind-tunnel-runner-status.holochain.org/)** in any browser.

Your node will appear listed under the name **`nomad-client-<your-node-name>`**. For example, if you named your node `rob-test-1` during setup, look for `nomad-client-rob-test-1` in the list. If your node appears there and shows as active, everything is working correctly.

### Check the service on the node directly

SSH into your node and run:

```bash
# Check the service is active
systemctl status wind-tunnel.service

# View the last 50 lines of logs
journalctl -u wind-tunnel.service -n 50
```

In the logs, look for lines containing `node registration complete` — that confirms the node has successfully connected to the Holochain test network.

---

## 🔧 Troubleshooting

### "I ran `podman ps` over SSH and see no containers"

This is expected behaviour and does **not** mean something is broken.

The node runs containers as a system-level service (under root), not as the `holo` user. When you SSH in as `holo` and run plain `podman ps`, you are only seeing containers in the `holo` user's own rootless Podman namespace — which will always be empty.

To see the system containers, always use `sudo`:

```bash
sudo podman ps
```

You should see the `wind-tunnel` (or `edgenode`) container listed as `Up`. The `holo` user has the necessary `sudo` permissions for `podman` built in, so this command will work without any extra configuration.

### "My node doesn't appear on the Wind Tunnel status dashboard"

First, confirm the container is actually running:

```bash
sudo podman ps
systemctl status wind-tunnel.service
```

If the service shows `active (running)` and `sudo podman ps` shows the `wind-tunnel` container, check the logs for the registration confirmation:

```bash
journalctl -u wind-tunnel.service -n 50
```

Look for `node registration complete`. If you see it, your node is connected — wait a minute or two and refresh the dashboard. If you do **not** see it, check for network connectivity issues (the node needs outbound internet access on the port used by Nomad).

Also double-check the name you are searching for on the dashboard. The dashboard name is always **`nomad-client-`** followed by whatever you entered as your node name during setup. A node named `my-node` will appear as `nomad-client-my-node`.

### "The wind-tunnel service failed to start"

Run the following to get detailed error output:

```bash
systemctl status wind-tunnel.service
journalctl -u wind-tunnel.service -n 100
```

Common causes:
- **Image not yet pulled** — the container image may still be downloading on first boot. Wait a minute and try `systemctl restart wind-tunnel.service`.
- **edgenode service still running** — both modes share network ports and cannot run simultaneously. Stop edgenode first: `systemctl stop edgenode.service`, then `systemctl start wind-tunnel.service`.
- **Network not available** — confirm the node has internet access before the container can register.

### "Container doesn't restart after reboot / power cycle"

If the wind-tunnel or edgenode container was running before a reboot but is missing afterward:

```bash
sudo podman ps
systemctl status wind-tunnel.service   # or edgenode.service
grep -A2 '\[Install\]' /etc/containers/systemd/*.container
```

Use `sudo podman ps` — containers run as rootful system services, not in the `holo` user's Podman namespace.

Only the active hardware mode should have an `[Install]` section in its `.container` file. If both do, update node-manager to the latest release (which fixes Quadlet autostart). The ISO ensures `network-online.target` is active at boot so containers can pull images and register once node-manager has written the correct Quadlet files.

Immediate workaround:

```bash
sudo systemctl daemon-reload
sudo systemctl restart wind-tunnel.service   # or edgenode.service
```

### "I need to switch modes after setup"

From the management dashboard (`http://<node-ip>:8080`), use the Hardware Mode selector to switch between EdgeNode and Wind Tunnel. Alternatively, over SSH:

```bash
# Switch to Wind Tunnel
systemctl stop edgenode.service
systemctl start wind-tunnel.service

# Switch back to EdgeNode
systemctl stop wind-tunnel.service
systemctl start edgenode.service
```

---

## 🧑‍💻 Developer & Build Documentation

> **Note for contributors:** If you are looking to modify the underlying Fedora CoreOS image, compile the Butane configurations, or test the GitHub Actions pipeline, please refer to our detailed developer documentation.

* **Building Locally & Architecture** ([docs/development.md](docs/development.md)): Instructions on using `butane` and `coreos-installer`, boot flow explanations, and systemd unit configs.
