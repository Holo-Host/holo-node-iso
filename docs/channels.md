
# OpenClaw / ZeroClaw Channel Configuration Reference

This document is the canonical reference for advanced channel configuration in the OpenClaw/ZeroClaw backend.

All channel settings live under `channels_config` in your `~/.zeroclaw/config.toml` file. Each channel is enabled by creating its corresponding sub-table.

----------

## Quick Troubleshooting: Setup passes but no reply?

If your channel appears connected but does not respond, check these common issues in order:

-   **Allowlist mismatch:** `allowed_users` (or equivalent) does not include the sender or is empty.
    
-   **Wrong room target:** The bot is not joined to the configured `room_id` or alias target room.
    
-   **Token mismatch:** The token is valid but belongs to another account.
    
-   **E2EE identity gap:** Keys were not shared to the bot device, so encrypted events cannot be decrypted.
    
-   **Stale state:** The config changed but the daemon was not restarted.
    

----------

## Per-Channel Config Examples

### 1. Telegram (Polling)

Ini, TOML

```
[channels_config.telegram]
bot_token = "123456:telegram-token"
allowed_users = ["*"]             # Replace "*" with specific user IDs in production
stream_mode = "off"               # optional: off | partial
draft_update_interval_ms = 1000   # optional: edit throttle for partial streaming
mention_only = false              # optional: require @mention in groups
interrupt_on_new_message = false  # optional: cancel in-flight same-sender same-chat request

```

### 2. Discord (Websocket)

Ini, TOML

```
[channels_config.discord]
bot_token = "discord-bot-token"
guild_id = "123456789012345678"   # optional
allowed_users = ["*"]
listen_to_bots = false
mention_only = false

```

### 3. Slack (Events API / Token)

Ini, TOML

```
[channels_config.slack]
bot_token = "xoxb-..."
app_token = "xapp-..."             # optional
channel_id = "C1234567890"         # optional: single channel; omit or "*" for all
allowed_users = ["*"]

```

### 4. Matrix (Sync API - Supports E2EE)

Ini, TOML

```
[channels_config.matrix]
homeserver = "https://matrix.example.com"
access_token = "syt_..."
user_id = "@zeroclaw:matrix.example.com"   # optional, recommended for E2EE
device_id = "DEVICEID123"                  # optional, recommended for E2EE
room_id = "!room:matrix.example.com"       # or room alias (#ops:matrix.example.com)
allowed_users = ["*"]

```

### 5. Signal (Local HTTP Bridge)

Ini, TOML

```
[channels_config.signal]
http_url = "http://127.0.0.1:8686"
account = "+1234567890"
group_id = "dm"                    # optional: "dm" / group id / omitted
allowed_from = ["*"]
ignore_attachments = false
ignore_stories = true

```

### 6. WhatsApp

**Cloud API Mode** _(Requires Webhook & Public HTTPS)_

Ini, TOML

```
[channels_config.whatsapp]
access_token = "EAAB..."
phone_number_id = "123456789012345"
verify_token = "your-verify-token"
app_secret = "your-app-secret"     # optional but recommended
allowed_numbers = ["*"]

```

**Web Mode (Websocket / QR Flow)** _(Requires `--features whatsapp-web` build flag)_

Ini, TOML

```
[channels_config.whatsapp]
session_path = "~/.zeroclaw/state/whatsapp-web/session.db"
pair_phone = "15551234567"         # optional; omit to use QR flow
pair_code = ""                     # optional custom pair code
allowed_numbers = ["*"]

```

### 7. Email (IMAP/SMTP)

Ini, TOML

```
[channels_config.email]
imap_host = "imap.example.com"
imap_port = 993
imap_folder = "INBOX"
smtp_host = "smtp.example.com"
smtp_port = 465
smtp_tls = true
username = "bot@example.com"
password = "email-password"
from_address = "bot@example.com"
poll_interval_secs = 60
allowed_senders = ["*"]

```

### 8. Lark / Feishu (Websocket or Webhook)

Ini, TOML

```
[channels_config.feishu]
app_id = "cli_xxx"
app_secret = "xxx"
encrypt_key = ""                    # optional
verification_token = ""             # optional
allowed_users = ["*"]
receive_mode = "websocket"          # or "webhook"
port = 8081                         # required for webhook mode

```

### 9. Nostr (Websocket / Relays)

Ini, TOML

```
[channels_config.nostr]
private_key = "nsec1..."                   # hex or nsec bech32
# relays = ["wss://relay.damus.io", "wss://nos.lol"]
allowed_pubkeys = ["hex-or-npub"]          # empty = deny all, "*" = allow all

```

> **Note:** For other niche integrations like iMessage, Nextcloud Talk, Linq, DingTalk, QQ, and IRC, please refer to the extended ZeroClaw source documentation.