# rapt

R + apt: A Python-free alternative to [bspm](https://github.com/Enchufa2/bspm) for [r2u](https://github.com/eddelbuettel/r2u) binary installs.

## What it does

Makes `install.packages("dplyr")` install `r-cran-dplyr` via apt instead of compiling from source. Fast binary installs with no Python in the stack.

## Architecture

```
R session  →  Unix socket  →  raptd (root)  →  apt install r-cran-*
```

A minimal C daemon (`raptd`) listens on `/run/raptd.sock` and executes apt commands on behalf of unprivileged users.

## Installation and Usage

### With .deb (recommended)

Install build dependencies as needed
```bash
sudo apt install debhelper r-base-dev
```

Clone repo and cd:
```bash
git clone https://github.com/cornball-ai/rapt.git
cd rapt/pkg
```

Build .deb and install:
```bash
# Build
dpkg-buildpackage -us -uc -b

# Install
sudo apt install ../rapt_0.1.0-1_amd64.deb
```

The .deb installs everything: daemon, systemd units, R package, and enables rapt system-wide via `/etc/R/profile.d/rapt.R`.

After installing the .deb, rapt is enabled automatically. Just use R normally:

```r
install.packages("dplyr")
#> Installing via apt: dplyr
```

### With the R package only (no daemon, no systemd)

Clone repo and install:
```bash
git clone https://github.com/cornball-ai/rapt.git
cd rapt/r-pkg/
R CMD INSTALL .
```

Or without cloning:
```r
remotes::install_github("cornball-ai/rapt", subdir = "r-pkg")
```

Then in R:
```r
rapt::enable()
install.packages("dplyr")  # now goes through apt via sudo
```

To make it permanent, add to `~/.Rprofile`:
```r
if (requireNamespace("rapt", quietly = TRUE)) rapt::enable()
```

#### Passwordless sudo for apt

Without the daemon, rapt falls back to `sudo apt`. To avoid password prompts, add a sudoers rule limited to R packages:

```bash
# /etc/sudoers.d/rapt
%users ALL=(root) NOPASSWD: /usr/bin/apt install -y r-cran-*
%users ALL=(root) NOPASSWD: /usr/bin/apt remove -y r-cran-*
%users ALL=(root) NOPASSWD: /usr/bin/apt install -y r-bioc-*
%users ALL=(root) NOPASSWD: /usr/bin/apt remove -y r-bioc-*
```

## Manual control

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

Options (set in `~/.Rprofile`, `/etc/R/Rprofile.site`, or a drop-in in `/etc/R/profile.d/`):

```r
# Allow sudo fallback when daemon unavailable (default: FALSE in non-interactive)
options(rapt.sudo = TRUE)

# Custom socket path (default: /run/raptd.sock)
options(rapt.socket = "/run/raptd.sock")
```

## Requirements

- Ubuntu with [r2u](https://github.com/eddelbuettel/r2u) configured
- R >= 4.0
- systemd (optional — for the daemon; without it, falls back to sudo/root)

## How it compares to bspm

| | bspm | rapt |
|---|---|---|
| Backend | Python D-Bus → PackageKit | C daemon → apt |
| Dependencies | Python, dbus-python, PackageKit | libc |
| Socket | D-Bus system bus | Unix domain socket |
| Lines of code | ~1500 | ~500 |

## License

MIT
