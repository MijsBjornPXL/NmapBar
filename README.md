# NmapBar – Interactive Nmap Progress UI for PowerShell

### Real-time ASCII / ANSI Progress Interface for Nmap

Visualize Nmap scans with live progress bars, smooth color gradients, and a countdown timer.

Simple, fast, hassle-free! (No API-keys required!)

This PowerShell script wraps Nmap and provides a clean, real-time console UI while a scan is running. It parses Nmap timing output, displays multiple progress bars (Main / SYN / Service / NSE), and shows the full Nmap results only after the scan completes.
<br>

## Features

- Displays live ASCII progress bars:
- Smooth color gradient on the growing arrow (=====>)
- Countdown timer (ETA)
- Stable, flicker-free rendering
- Clean final output


## Requirements

- PowerShell 7.x (recommended)
- Nmap installed
- ANSI-compatible terminal (for colors and cursor control)


## Dependencies

- Nmap: Network scanning engine

<br>

- PowerShell: Make sure PowerShell 7+ is installed.
<br>
<br>

## Installation Instructions

Clone the repository or download the script:

```bash
git clone https://github.com/MijsBjornPXL/nmapbar.git
cd nmapbar
```

## Run the script:

After installing the requirements, you can run the script directly from PowerShell.

**_Example Simple Scan:_**

```powershell
.\nmapbar.ps1 -Mode simple -Target 192.168.1.1
```

**_Example Complete Scan:_**

```powershell
.\nmapbar.ps1 -Mode complete -Target 10.0.14.5
```

**_Custom Nmap Path:_**

```powershell
.\nmapbar.ps1 -Mode simple -Target 192.168.1.1 `
  -NmapPath "C:\Program Files (x86)\Nmap\nmap.exe"
```

### Scan Modes

The script supports two scan modes:

simple

Uses: -sV -sC -n

Balanced scan suitable for most situations

complete

Uses: -sS -A -p- -n -T4

More extensive and slower scan

**_Both modes include:_**

```css
--stats-every 250ms
```

<br>

## Example Output

Live Progress UI:

```plaintext
Main Progress [=========================>            ]  53%  Running. 53%, 2m14s
SYN Scan      [===============================>     ]  82%
Service Scan  [===============>                     ]  41%
NSE Scan      [>                                    ]   2%
```

The =====> arrow gradually changes color from red to green as progress increases.
<br>

Final Nmap Output:

```plaintext
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
443/tcp  open  https
```

<br>



## Troubleshooting

If you encounter issues while running the script, ensure that:

 - Nmap is installed and accessible
 - You are using PowerShell 7 or newer
 - Your terminal supports ANSI escape sequences
 - If Nmap is not in PATH, use the -NmapPath parameter

## License

This project is licensed under the MIT License - see the LICENSE file for details.


