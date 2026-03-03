#!/bin/bash
# Detect whether we have a wired connection.
# Sets AP_MODE so the onboarding UI knows to show the Wi-Fi form.
if ip -4 route show default 2>/dev/null | grep -qv 'wl'; then
  echo "AP_MODE=false"
else
  echo "AP_MODE=true"
fi