# Raw Label Printer Setup for macOS

A one-file script that sets up a label printer (Zebra and similar) on macOS so label code — **ZPL, EPL or CPCL** — goes straight to the printer.

Recent versions of macOS no longer allow "raw" printers (`lpadmin -m raw` fails with *"Raw queues are no longer supported on macOS"*). Without a raw printer, label code sent by shipping or warehouse software either never arrives or prints as lines of text such as `^XA^FO32,20^A0N…`. This script creates a printer that behaves like the old raw printers.

## What it does

1. **Gets admin rights.** It works from a standard account too: it asks for an admin account's name and password.
2. **Finds the printer.** It lists printers connected by USB, or you can enter a network printer's IP address (port 9100).
3. **Asks the label language:** ZPL, EPL, CPCL or other.
4. **Asks for the printer name** your software prints to (default `label`). It keeps the name of an existing printer for the same device, and offers to remove duplicates.
5. **Creates the printer** with a pass-through setup, so label code isn't converted. This works even when the software prints without `-o raw`, or with a mistyped option such as `-o -raw`.
6. **Prints a test label** the same way most label software does, and walks you through printer checks if nothing comes out.

## Usage

1. Download `label-printer-setup.command`.
2. Open **Terminal**, type `bash ` (with a space), drag the file into the window, and press **Return**.
3. Follow the steps on screen.

To run it by double-clicking instead, make it executable once:

```
chmod +x label-printer-setup.command
```

macOS may block a downloaded script the first time. If it does, right-click the file and choose **Open**.

## Useful commands

| Task | Command |
|---|---|
| List printers | `lpstat -p` |
| Show where each printer points | `lpstat -v` |
| See stuck jobs | `lpstat -o` |
| Clear stuck jobs | `cancel -a <printer-name>` |
| Remove a printer | `sudo lpadmin -x <printer-name>` |

## Requirements

- macOS with CUPS (built in)
- An admin account on the Mac

---

Designed and developed by Slimane Hassani
