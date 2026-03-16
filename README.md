# holo-node-iso

Welcome to the Holo Node! This operating system image allows you to turn your hardware (like a HoloPort or a standard PC) into a dedicated edge node. It automatically installs a customized, secure operating system that boots directly into the Holo node stack.

Whether you want to host applications on the edge or run automated wind-tunnel tests, this guide will walk you through the entire setup process.

---

## Table of Contents

1. [What can you do with a Holo Node?](#what-can-you-do-with-a-holo-node)
2. [Why You Can Relax: Our Security First Approach](#why-you-can-relax-our-security-first-approach)
3. [Complete Node Setup Guide](#complete-node-setup-guide)
   * [Part 1: Flashing and Booting](#part-1-flashing-and-booting)
   * [Part 2: Generating an SSH Key](#part-2-generating-an-ssh-key)
   * [Part 3: Configuring Your Node & AI Agent](#part-3-configuring-your-node--ai-agent)
4. [Managing Your Node](#managing-your-node)
5. [Developer & Build Documentation](#developer--build-documentation)

---

## What can you do with a Holo Node?

Once your node is installed and running, you can operate it in different modes depending on your goals:

* **Edge Node Mode:** Run and host decentralized applications directly on your hardware at the edge of the network. 
* **Wind Tunnel Mode:** Use your node as a dedicated testing environment to run performance, stress, and wind-tunnel tests for your own apps before deploying them widely.
* **OpenClaw AI Agent:** Both modes allow you to enable the OpenClaw AI agent, which you can connect to your preferred AI model and control remotely via chat platforms like Telegram.

---

## Why You Can Relax: Our Security First Approach

Running a node on your local network might sound intimidating, but we have built the Holo Node with extreme security precautions so you can operate it with total peace of mind:

* **Immutable Operating System:** The base OS (Fedora CoreOS) is locked down. Core system files cannot be easily altered by malicious actors.
* **No Passwords:** Traditional password logins are completely disabled over the network. The only way to access the system remotely is via the highly encrypted SSH key you generate on your own computer.
* **Root Login Disabled:** Administrator (root) network login is blocked by default. 
* **Automatic Updates:** The node automatically pulls background security patches and nightly container image refreshes, so you are never left running outdated, vulnerable software.

---

## Complete Node Setup Guide

This guide is written for everyone. Even if you aren't highly technical, following these steps from start to finish will get your node running and securely connected to your own personal AI assistant.

### Part 1: Flashing and Booting

1.  **Download the Installer:** Download the latest edge node installer image (`.iso` file) from our GitHub Releases. *(Make sure to download the `.iso` file, not the source code folder).*
2.  **Flash to a USB Drive:** You need a USB stick with at least 8GB of space. Use a free tool like [balenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/). Open the tool, select the downloaded `.iso` image, select your USB drive, and click Flash. Wait for it to complete.
3.  **Boot the Device:** Insert the flashed USB stick into your hardware (e.g., your HoloPort or PC). Connect a monitor, a keyboard, and an ethernet cable connected to your internet router. Turn the device on and press `F11` (or your system's boot menu key) repeatedly to boot from the USB drive.
4.  **Automatic Installation:** The system will automatically install the operating system. No manual interaction is required here. **Important:** When the installation finishes, a password will be displayed on the screen. **Write this password down.** You will need it later. Remove the USB stick and let the system reboot.
5.  **Find the IP Address:** Once rebooted, the monitor will display an IP address assigned by your router (it usually looks like `192.168.x.x`). Keep this number handy.
6.  **Open the Setup Interface:** On a separate laptop or PC connected to the same WiFi/network, open a web browser and type in that IP address followed by `:8080`. 
    * Example: `http://192.168.1.50:8080`
    * The node will automatically redirect you to the onboarding setup page.

### Part 2: Generating an SSH Key

To securely connect your computer to your new node, you need to generate an "SSH Key." It acts as a highly secure digital handshake.

**For Windows Users:**
1.  Click your Start menu, type **PowerShell**, and open it.
2.  Type the following command (replace with your actual email) and press Enter:
    `ssh-keygen -t ed25519 -C "your_email@example.com"`
3.  The system will ask where to save the key. Press **Enter** to accept the default location.
4.  It will ask for a passphrase. Leave it blank and press **Enter** twice.
5.  Type this command to view your new public key:
    `cat ~/.ssh/id_ed25519.pub`
6.  A long line of text starting with `ssh-ed25519` will appear. Highlight and copy this entire line.

**For Mac / Linux Users:**
1.  Open the **Terminal** application.
2.  Type the following command (replace with your actual email) and press Enter:
    `ssh-keygen -t ed25519 -C "your_email@example.com"`
3.  Press **Enter** to accept the default file location.
4.  Press **Enter** twice to skip creating a passphrase.
5.  Type this command to view your public key:
    `cat ~/.ssh/id_ed25519.pub`
6.  Copy the entire output string that begins with `ssh-ed25519`.

### Part 3: Configuring Your Node & AI Agent

Now that you have your SSH key, return to the setup page in your web browser.

1. **Paste your SSH Key:** Paste the key you just copied into the *SSH Public Key* field.
2. **Choose your Mode:** Give your node a name, and select either **Edge Node Mode** (for hosting apps) or **Wind Tunnel Mode** (for testing apps).
3. **Choose Your AI Agent:** You can power your OpenClaw AI agent using several different providers. Choose the one that best fits your privacy needs and budget:
   * **Option A: Ollama (Default, Local, and Private)**
     Ollama is the default choice because it runs entirely locally on your hardware. Your data remains strictly private and never leaves your network. It is highly recommended for security and privacy. 
   * **Option B: Google Gemini API (Cloud-based)**
     Google's AI offers a "No-Billing" Free Tier, which is great for prototyping but has strict usage limitations. If you add billing information, it becomes a paid service with higher quotas. To use it, get an API key from the [Google Cloud Console](https://console.cloud.google.com/) and paste it into the *Gemini API* field.
   * **Option C: Anthropic Claude (Cloud-based)**
     A powerful premium cloud model. You will need to create an account at the [Anthropic Console](https://console.anthropic.com/), fund it, generate an API key, and paste it into the configuration field.
   * **Option D: OpenAI / ChatGPT (Cloud-based)**
     The industry-standard cloud model. You will need an active, funded account at the [OpenAI Developer Platform](https://platform.openai.com/). Generate an API key and paste it into the configuration field.
   * **Option E: OpenRouter (Cloud Aggregator)**
     OpenRouter is an aggregator that lets you access dozens of different AI models (including paid and open-source models) using a single API key. Get your key from [OpenRouter.ai](https://openrouter.ai/) and paste it into the configuration field.

4. **Connect Your Chat Interface:**
   Your AI agent needs a way to talk to you. You can connect it to over 15 different messaging platforms. 

   **The Default: Telegram**
   Telegram is our recommended chat interface because it requires no complex network setup. *Note: You must ensure the Telegram CLI (Command Line Interface) is enabled for it to work properly.*
   * Open the Telegram app and search for **BotFather**.
   * Send `/newbot` and follow the prompts to name your bot (the username must end in `_bot`).
   * Copy the **Bot Token** provided and paste it into the *Bot Token* field on the onboarding page.
   * Search for **userinfobot**, send `/start`, and copy your numeric ID. Paste this into the *Allowed User IDs* field to ensure your bot only talks to you.
   * *Bonus:* Once running, you can manage your AI directly in Telegram! Type `/models` to see available providers, or `/new` to clear the conversation history and start fresh.

   **Alternative Chat Options:**
   If you prefer not to use Telegram, the underlying ZeroClaw architecture supports many other platforms. They are categorized below by setup difficulty:

   * **Easy Setup (No public IP or port forwarding required):**
     These channels use background polling or websockets and work out of the box, just like Telegram.
     * **Discord:** Requires a Bot Token.
     * **Slack:** Requires a Bot Token.
     * **Matrix:** Highly secure. Supports End-to-End Encryption (E2EE).
     * **WhatsApp (Web Mode):** Connects via a QR-code style session.
     * **Signal:** Connects via a local HTTP bridge.
     * **iMessage:** Connects locally via an AppleScript bridge.
     * **Others:** Mattermost, Email (IMAP/SMTP), IRC, DingTalk, QQ, and Nostr.

   * **Advanced Setup (Requires a public IP / Webhook callback):**
     These channels require your node to have a public-facing HTTPS address so the chat service can send data back to you.
     * **WhatsApp (Cloud API Mode):** Requires a verified Meta developer account.
     * **Nextcloud Talk:** Requires a dedicated `/nextcloud-talk` webhook endpoint.
     * **Lark / Feishu (Webhook Mode):** Requires an app ID and callback URL.
     * **Linq:** Requires an API token and a `/linq` webhook endpoint.

   *Security Note: No matter which channel you choose, you must configure the "Allowlist" (e.g., `allowed_users`, `allowed_numbers`, or `allowed_contacts`) with your specific username or ID. If left blank, the bot will deny all incoming messages.*

5. **Finish Setup:** Submit the onboarding form. Your node is now fully configured and your AI is ready to chat!

---

## Managing Your Node

Once onboarding is complete, you can monitor and adjust your node's settings at any time. 

Simply open your web browser and navigate back to your node's IP address:
* `http://192.168.1.50:8080`

The system will recognize that you have already onboarded and will automatically redirect you to your management dashboard. From this dashboard, you can view system health, deploy apps to the edge, trigger wind-tunnel tests, and update your AI agent configurations. 

---

## Developer & Build Documentation

*Note for contributors: If you are looking to modify the underlying Fedora CoreOS image, compile the Butane configurations, or test the GitHub Actions pipeline, please refer to our detailed developer documentation.*

* **[Building Locally & Architecture (`docs/development.md`)](docs/development.md):** Instructions on using `butane` and `coreos-installer`, boot flow explanations, and systemd unit configs.
* **[Advanced Channel Configs (`docs/channels.md`)](docs/channels.md):** Detailed TOML configuration syntax for setting up Discord, Matrix, Signal, Webhooks, and other chat providers via ZeroClaw.