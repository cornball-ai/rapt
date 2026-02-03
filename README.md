# rapt

R + apt: A Python-free alternative to [bspm](https://github.com/Enchufa2/bspm) for [r2u](https://github.com/eddelbuettel/r2u) binary installs.

## What it does

Makes `install.packages("dplyr")` install `r-cran-dplyr` via apt instead of compiling from source. Fast binary installs with no Python in the stack.

## Architecture

```
R session  →  Unix socket  →  raptd (root)  →  apt-get install r-cran-*
```

A minimal C daemon (`raptd`) listens on `/run/raptd.sock` and executes apt commands on behalf of unprivileged users.

## Installation

### From .deb (recommended)

```bash
# Build
sudo apt install debhelper r-base-dev  # as needed
cd pkg
dpkg-buildpackage -us -uc -b

# Install
sudo apt install ../rapt_0.1.0-1_amd64.deb
```

The .deb installs everything: daemon, systemd units, R package, and enables rapt system-wide.

### R package only (with sudo fallback)

```bash
R CMD INSTALL r-pkg/
```

Without the daemon, rapt falls back to `sudo apt-get` in interactive sessions.

## Usage

After installing the .deb, rapt is enabled automatically. Just use R normally:
```r
install.packages("dplyr")
#> Installing via apt: dplyr
```

### Manual control

```r
library(rapt)

# Check status
manager()
#> $daemon_available
#> [1] TRUE
#> $socket_path
#> [1] "/run/raptd.sock"
#> $enabled
#> [1] TRUE

# Direct system package management
install_sys("ggplot2")
remove_sys("ggplot2")

# List available system packages
head(available_sys())
#> [1] "a]4" "abc" "abcrf" "abd" "abess" "abn"

# Disable/enable hook
disable()
install.packages("dplyr")  # Now uses CRAN
enable()
install.packages("dplyr")  # Back to apt
```

## Configuration

Options (set in `~/.Rprofile` or `/etc/R/Rprofile.site`):

```r
# Allow sudo fallback when daemon unavailable (default: FALSE in non-interactive)
options(rapt.sudo = TRUE)

# Custom socket path (default: /run/raptd.sock)
options(rapt.socket = "/run/raptd.sock")
```

## Requirements

- Ubuntu with [r2u](https://github.com/eddelbuettel/r2u) configured
- systemd
- R >= 4.0

## How it compares to bspm

| | bspm | rapt |
|---|---|---|
| Backend | Python D-Bus → PackageKit | C daemon → apt-get |
| Dependencies | Python, dbus-python, PackageKit | libc, systemd |
| Socket | D-Bus system bus | Unix domain socket |
| Lines of code | ~1500 | ~500 |

## License

MIT
