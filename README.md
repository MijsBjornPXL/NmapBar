# 🧭 NmapBar – Interactive Nmap Progress UI for PowerShell

### Real-time ASCII / ANSI progress interface for Nmap scans

**NmapBar** is a PowerShell wrapper around **Nmap** that provides a clean, real-time console UI with progress bars, smooth color gradients, and a countdown timer (ETA).

It enhances the standard Nmap experience by visualizing scan progress while keeping the full Nmap output intact and readable once the scan finishes.

<br>

## Features

- Live ASCII progress bars:
  - Main Progress (average)
  - SYN Scan
  - Service Scan
  - NSE Scan
- Smooth color gradient on the growing arrow (`=====>`)
  - 0% → red
  - intermediate → orange / yellow
  - 100% → green
- Countdown timer (ETA)
  - Monotonically decreasing (never counts up)
- Fast UI updates
  - Uses `--stats-every 250ms`
  - UI keep-alive refresh
- Stable, drift-free rendering
  - Absolute cursor positioning
- Clean final output
  - Full Nmap results shown only after scan completion
  - Open ports highlighted

<br>

## Preview

Main Progress [=========================> ] 53% Running. 53%, 2m14s
SYN Scan [===============================> ] 82%
Service Scan [===============> ] 41%
NSE Scan [> ] 2%


The `=====>` arrow gradually changes color from red to green as progress increases.

<br>

## Requirements

- PowerShell 7+ (recommended)
- Nmap installed  
  https://nmap.org/download.html
- ANSI-compatible terminal
  - Windows Terminal (recommended)
  - VS Code terminal

<br>

## Installation

powershell
git clone https://github.com/<your-username>/nmapbar.git
cd nmapbar
<br>
Usage
Simple scan

Balanced scan suitable for most situations.

.\nmapbar.ps1 -Mode simple -Target 192.168.1.1

Complete scan

More extensive and slower scan.

.\nmapbar.ps1 -Mode complete -Target 10.0.14.5

Custom Nmap path

If Nmap is not in your PATH.

.\nmapbar.ps1 -Mode simple -Target 192.168.1.1 `
  -NmapPath "C:\Program Files (x86)\Nmap\nmap.exe"

<br>
Scan Modes
simple

Uses the following Nmap flags:

-sV -sC -n

complete

Uses the following Nmap flags:

-sS -A -p- -n -T4


Both modes include:

--stats-every 250ms


for responsive progress updates.

<br>
How It Works

Nmap runs as a background process with frequent status updates

Output is parsed in real-time to extract progress percentages

Progress is visualized using ANSI escape sequences

ETA (countdown) is estimated based on:

elapsed time

current progress rate

The lowest calculated ETA is retained to ensure the timer never increases

<br>
Color & UI Design

ANSI 256-color mode is used for smooth gradients

Only the filled portion of the bar (=====>) is colored to prevent layout issues

Labels and percentages use subtle, readable colors

Open ports are highlighted in green in the final output

<br>
Limitations

ETA is an estimate and depends on Nmap output frequency

Requires a terminal with ANSI support

Very quiet scans (e.g. long NSE phases) may reduce ETA accuracy

<br>
Roadmap / Ideas

Full gradient across the entire bar

Spinner animation during idle moments

JSON / XML output parsing

Linux / macOS Bash version

Configuration file support (YAML / JSON)

<br>
Contributing

Pull requests are welcome.
Feel free to open issues for bugs, ideas, or improvements.

<br>
License

MIT License

<br>
Author

Bjorn Mijs
IT / Network / Security
