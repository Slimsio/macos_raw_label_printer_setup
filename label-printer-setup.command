#!/bin/bash
# ------------------------------------------------------------
#  Raw Label Printer Setup for macOS
#
#  Adds a USB or network label printer (Zebra, etc.) that
#  passes label code (ZPL, EPL, CPCL, ...) straight to the
#  printer — the replacement for the "raw" printers that
#  macOS no longer allows.
#
#  Designed and developed by Slimane Hassani
# ------------------------------------------------------------

say()  { printf "\n\033[1m%s\033[0m\n" "$1"; }
ok()   { printf "  \033[32m✔ %s\033[0m\n" "$1"; }
warn() { printf "  \033[33m! %s\033[0m\n" "$1"; }
ask()  { local a; read -r -p "  $1 [Y/n] " a; [[ -z "$a" || "$a" =~ ^[Yy] ]]; }
pick() { # pick <max> -> sets PICK
  local n
  while :; do
    read -r -p "  Choose a number: " n
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$1" ]; then PICK=$n; return; fi
  done
}

# ---------- Step 1: admin rights ----------
if [ "$(id -u)" -ne 0 ]; then
  clear
  echo "==========================================="
  echo "     Raw Label Printer Setup for macOS"
  echo "==========================================="
  say "Step 1 — Admin rights"
  ME="$(id -un)"
  TMPSCRIPT="/tmp/label-printer-setup.$$.sh"
  cp "$0" "$TMPSCRIPT" && chmod 755 "$TMPSCRIPT"

  if dseditgroup -o checkmember -m "$ME" admin >/dev/null 2>&1; then
    echo "  Type this Mac's password and press Return (the typing stays invisible)."
    sudo bash "$TMPSCRIPT"; status=$?
    rm -f "$TMPSCRIPT"; exit $status
  fi

  echo "  The account \"$ME\" is not an administrator on this Mac."
  echo "  Enter the name and password of an ADMIN account on this Mac."
  while :; do
    read -r -p "  Admin account name (short name): " ADMIN
    [ -z "$ADMIN" ] && continue
    if ! dseditgroup -o checkmember -m "$ADMIN" admin >/dev/null 2>&1; then
      warn "\"$ADMIN\" is not an admin account on this Mac."; continue
    fi
    echo "  Type the password for \"$ADMIN\". It may be asked TWICE (typing stays invisible)."
    su "$ADMIN" -c "sudo bash '$TMPSCRIPT'"; status=$?
    [ $status -eq 0 ] && { rm -f "$TMPSCRIPT"; exit 0; }
    warn "Could not get admin rights (wrong password?)."
    ask "Try again?" || { rm -f "$TMPSCRIPT"; exit 1; }
  done
fi

# ---------- From here on we run as root ----------
ok "Admin rights OK"

# ---------- Step 2: find the printer ----------
say "Step 2 — Choose the label printer"
while :; do
  URIS=()
  while IFS= read -r line; do
    [ -n "$line" ] && URIS+=("$line")
  done < <(lpinfo -v 2>/dev/null | awk '$1=="direct" && $2 ~ /^usb:\/\// {print $2}')

  if [ ${#URIS[@]} -gt 0 ]; then
    echo "  Printers connected by USB:"
    for i in "${!URIS[@]}"; do
      label=$(echo "${URIS[$i]}" | sed -E 's#^usb://##; s#\?.*$##; s#%20# #g; s#/# #g')
      echo "    $((i+1))) $label"
    done
  else
    warn "No USB printer found."
  fi
  N=${#URIS[@]}
  echo "    $((N+1))) Network printer (enter its IP address)"
  echo "    $((N+2))) Search USB again"
  pick $((N+2))

  if [ "$PICK" -le "$N" ]; then
    URI="${URIS[$((PICK-1))]}"; break
  elif [ "$PICK" -eq $((N+1)) ]; then
    read -r -p "  Printer IP address (e.g. 192.168.1.50): " IP
    if [[ "$IP" =~ ^[A-Za-z0-9.-]+$ ]]; then
      read -r -p "  Port [9100]: " PORT; PORT=${PORT:-9100}
      URI="socket://$IP:$PORT"; break
    fi
    warn "That address doesn't look right."
  else
    echo "    • Make sure the printer is ON and connected to THIS Mac (try another USB port)."
  fi
done

if [[ "$URI" == usb://* ]]; then
  MODEL=$(echo "$URI" | sed -E 's#^usb://##; s#\?.*$##; s#%20# #g; s#/# #g')
else
  MODEL="$URI"
fi
ok "Printer: $MODEL"

# ---------- Step 3: label language ----------
say "Step 3 — Label language"
echo "  Which label language does your software send to this printer?"
echo "    1) ZPL   (most Zebra printers, shipping labels — most common)"
echo "    2) EPL   (older Zebra printers, e.g. LP/TLP 2844)"
echo "    3) CPCL  (Zebra mobile printers)"
echo "    4) Other / not sure"
pick 4
case $PICK in
  1) LANG_NAME="ZPL";   DRIVER="drv:///sample.drv/zebra.ppd" ;;
  2) LANG_NAME="EPL";   DRIVER="drv:///sample.drv/zebraep2.ppd" ;;
  3) LANG_NAME="CPCL";  DRIVER="drv:///sample.drv/zebracpl.ppd" ;;
  4) LANG_NAME="Other"; DRIVER="drv:///sample.drv/zebra.ppd" ;;
esac
if ! lpinfo -m 2>/dev/null | grep -q "^${DRIVER} "; then
  DRIVER="drv:///sample.drv/zebra.ppd"
fi
ok "Label language: $LANG_NAME"

# ---------- Step 4: printer name ----------
say "Step 4 — Printer name"
# Existing printers that point to the same device (ignoring the serial part)
BASE="${URI%%\?*}"
OLD_NAMES=()
while IFS= read -r line; do
  name=$(echo "$line" | sed -E 's/^device for ([^:]+): .*/\1/')
  dev=$(echo "$line"  | sed -E 's/^device for [^:]+: //')
  [ "${dev%%\?*}" = "$BASE" ] && OLD_NAMES+=("$name")
done < <(lpstat -v 2>/dev/null)

DEFAULT="label"
if [ ${#OLD_NAMES[@]} -gt 0 ]; then
  echo "  Printers already set up for this device:"
  for n in "${OLD_NAMES[@]}"; do echo "    • $n"; done
  DEFAULT="${OLD_NAMES[0]}"
fi
echo "  Use the printer name your software prints to."
while :; do
  read -r -p "  Printer name [$DEFAULT]: " QUEUE
  [ -z "$QUEUE" ] && QUEUE="$DEFAULT"
  [[ "$QUEUE" =~ ^[A-Za-z0-9_.-]{1,127}$ ]] && break
  warn "Use only letters, numbers, - _ or . (no spaces)."
done
ok "Printer name: $QUEUE"

for name in "${OLD_NAMES[@]}"; do
  [ "$name" = "$QUEUE" ] && continue
  echo "  Other printer for this device: $name"
  if ask "Remove it?"; then
    cancel -a "$name" 2>/dev/null
    lpadmin -x "$name" && ok "Removed $name"
  fi
done

# ---------- Step 5: create the printer ----------
say "Step 5 — Setting up the printer"
lpadmin -p "$QUEUE" -E -v "$URI" -m "$DRIVER" 2>&1 | grep -vi "deprecated"

# Pass label code straight through to the printer, even when the
# software doesn't use "-o raw" (otherwise the code prints as text).
PPD="/private/etc/cups/ppd/$QUEUE.ppd"
if [ -f "$PPD" ] && ! grep -q 'text/plain 0 -' "$PPD"; then
  RAWPPD=$(mktemp /tmp/label-raw.XXXXXX)
  cp "$PPD" "$RAWPPD"
  echo '*cupsFilter: "text/plain 0 -"' >> "$RAWPPD"
  echo '*cupsFilter: "application/octet-stream 0 -"' >> "$RAWPPD"
  lpadmin -p "$QUEUE" -P "$RAWPPD" 2>&1 | grep -vi "deprecated"
  rm -f "$RAWPPD"
fi

if lpstat -p "$QUEUE" >/dev/null 2>&1; then
  cancel -a "$QUEUE" 2>/dev/null
  cupsenable "$QUEUE" 2>/dev/null
  cupsaccept "$QUEUE" 2>/dev/null
  ok "Printer ready: $QUEUE"
else
  warn "The printer could not be added. Take a photo of this window to get help."
  read -r -p "  Press Return to close."; exit 1
fi

# ---------- Step 6: test label ----------
say "Step 6 — Test label"
HOSTNAME_TXT="$(scutil --get ComputerName 2>/dev/null)"
TESTFILE=$(mktemp /tmp/label-test.XXXXXX)
case $LANG_NAME in
  ZPL)  printf '^XA^FO40,50^A0N,45,45^FDTEST - LABEL PRINTER OK^FS^FO40,110^A0N,30,30^FD%s^FS^XZ' "$HOSTNAME_TXT" > "$TESTFILE" ;;
  EPL)  printf '\nN\nA40,50,0,4,1,1,N,"TEST - LABEL PRINTER OK"\nA40,110,0,3,1,1,N,"%s"\nP1\n' "$HOSTNAME_TXT" > "$TESTFILE" ;;
  CPCL) printf '! 0 200 200 210 1\r\nTEXT 4 0 30 40 TEST - LABEL PRINTER OK\r\nTEXT 7 0 30 110 %s\r\nFORM\r\nPRINT\r\n' "$HOSTNAME_TXT" > "$TESTFILE" ;;
  *)    rm -f "$TESTFILE"; TESTFILE="" ;;
esac

if [ -z "$TESTFILE" ]; then
  echo "  No built-in test for this label language."
  echo "  Print a label from your software to check it."
else
  while :; do
    # Printed without "-o raw", like most label software does
    lpr -P "$QUEUE" "$TESTFILE" >/dev/null
    echo "  The label should show the words TEST - LABEL PRINTER OK,"
    echo "  NOT lines of code."
    read -r -p "  Did a correct TEST label print? [y/n] " a
    [[ "$a" =~ ^[Yy] ]] && { ok "Test label printed"; break; }
    warn "No correct label. Check:"
    echo "    • Press the printer's feed button — a blank label should come out."
    echo "    • Check the label roll and that the cover is fully closed."
    echo "    • Recalibrate the printer (Zebra: hold feed until the light flashes twice)."
    echo "    • If it printed garbled text, the printer may use another label language."
    read -r -p "  Press Return to test again, or type s to skip: " a
    [ "$a" = "s" ] && break
  done
  rm -f "$TESTFILE"
fi

say "All done ✔  Your software can now print to \"$QUEUE\"."
read -r -p "  Press Return to close this window."
exit 0
