# rapt: R + apt

A Python-free alternative to bspm. Bridges `install.packages()` to apt for lightning-fast binary installs from r2u.

## Goal

Replace bspm's Python D-Bus service with a minimal C daemon + pure R package, enabling `install.packages()` to use r2u's apt binaries without any Python dependency.

## Architecture

```
┌─────────────────┐      Unix socket      ┌──────────────────┐
│  R session      │ ──────────────────────▶│  raptd (C)       │
│  (user)         │   "install dplyr"     │  (root, systemd) │
└─────────────────┘                        └────────┬─────────┘
                                                    │
                                                    ▼
                                              apt install
                                              r-cran-dplyr
```

## Components

### 1. C Daemon: `raptd`

Location: `daemon/`

**Files to create:**
- `daemon/raptd.c` — main daemon (~300 lines)
- `daemon/Makefile`
- `daemon/raptd.socket` — systemd socket unit
- `daemon/raptd.service` — systemd service unit

**Daemon requirements:**
- Listen on `/run/raptd.sock`
- Accept newline-delimited commands: `install <pkg> [pkg2 ...]` or `remove <pkg> [pkg2 ...]`
- Validate package names: only `[a-zA-Z0-9._]` allowed
- Map R names to deb names: `dplyr` → `r-cran-dplyr` (lowercase)
- Fork/exec: `apt-get install -y r-cran-<pkg>`
- Return stdout/stderr and exit code to client
- Handle concurrent connections (fork per connection)
- Log to syslog

**Security considerations:**
- Validate all input strictly
- Run as dedicated `raptd` user with apt privileges (or root)
- Socket permissions: mode 0666 so any user can connect
- No shell expansion — exec directly

### 2. R Package: `rapt`

Location: `r-pkg/`

**Structure:**
```
r-pkg/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── socket.R      # Low-level socket communication
│   ├── manager.R     # install_sys(), remove_sys(), available_sys()
│   ├── integration.R # enable(), disable() — hook install.packages()
│   └── fallback.R    # sudo fallback when daemon unavailable
├── man/
└── tests/
```

**Key functions:**

```r
# Connect to daemon, send command, return result
rapt_call(cmd, pkgs)

# Public API (mirrors bspm)
install_sys(pkgs)
remove_sys(pkgs
available_sys()

# Hook into install.packages()
enable()
disable()
```

**Fallback behavior:**
1. Try socket at `/run/raptd.sock`
2. If unavailable + interactive + has sudo → use `sudo apt-get`
3. If unavailable + non-interactive + `options(rapt.sudo = TRUE)` → use sudo
4. Otherwise fail with informative message

### 3. Debian Packaging

Location: `debian/`

**Files:**
- `debian/control`
- `debian/rules`
- `debian/rapt.install`
- `debian/rapt.postinst` — enable systemd units, install R package
- `debian/rapt.postrm`

**Package name:** `rapt`

**Contains:**
- `/usr/bin/raptd` — the daemon
- `/lib/systemd/system/raptd.socket` — socket unit
- `/lib/systemd/system/raptd.service` — service unit
- `/usr/lib/R/site-library/rapt/` — the R package

**Dependencies:** libc6, systemd, apt, r-base-core

## Implementation Order

### Phase 1: Minimal Daemon
1. [ ] Write `daemon/raptd.c` with basic socket listener
2. [ ] Implement command parsing (install/remove)
3. [ ] Implement input validation
4. [ ] Implement apt-get execution with output capture
5. [ ] Write Makefile
6. [ ] Test manually: `echo "install Rcpp" | nc -U /run/raptd.sock`

### Phase 2: Systemd Integration
1. [ ] Write `raptd.socket` unit
2. [ ] Write `raptd.service` unit
3. [ ] Test socket activation
4. [ ] Verify permissions work for non-root users

### Phase 3: R Package Core
1. [ ] Create package skeleton with DESCRIPTION, NAMESPACE
2. [ ] Implement `socket.R` — raw socket communication
3. [ ] Implement `manager.R` — install_sys/remove_sys/available_sys
4. [ ] Write basic tests

### Phase 4: R Package Integration
1. [ ] Implement `integration.R` — hook install.packages()
2. [ ] Implement `fallback.R` — sudo fallback
3. [ ] Test full flow: `install.packages("dplyr")` via daemon
4. [ ] Document

### Phase 5: Debian Package
1. [ ] Create debian/ directory
2. [ ] Write control, rules, install files
3. [ ] Write postinst/postrm scripts (enable systemd, install R pkg)
4. [ ] Build and test .deb
5. [ ] Test fresh install: `sudo apt install ./rapt_*.deb`

### Phase 6: Testing & Hardening
1. [ ] Test concurrent installs
2. [ ] Test malformed input
3. [ ] Test large dependency chains (tidyverse)
4. [ ] Test in Docker container (root mode)
5. [ ] Test on Ubuntu focal, jammy, noble
6. [ ] Fuzz the daemon input

## Technical Notes

### Socket Protocol

Simple line-based text protocol:

**Request:**
```
<command> <pkg1> [pkg2] [pkg3] ...
```

**Response:**
```
STATUS <exit_code>
<stdout/stderr from apt>
```

### Package Name Mapping

```c
// In daemon
void map_pkg_name(const char *r_name, char *deb_name, size_t len) {
    snprintf(deb_name, len, "r-cran-%s", r_name);
    for (char *p = deb_name + 7; *p; p++)
        *p = tolower(*p);
}
```

### R Socket Code

```r
rapt_call <- function(cmd, pkgs) {
  sock <- socketConnection(
    host = NULL,
    port = NULL,
    server = FALSE,
    blocking = TRUE,
    open = "r+",
    # Unix socket path
    socket = "/run/raptd.sock"
  )
  on.exit(close(sock))

  # Note: base R socketConnection doesn't support Unix sockets
  # Need to use raw socket via C or external tool
  # See fallback options below
}
```

**Problem:** Base R `socketConnection()` doesn't support Unix domain sockets.

**Solutions:**
1. Write small C function using `.Call()` to handle Unix socket
2. Use `socketConnection()` with TCP on localhost (requires daemon to listen on TCP)
3. Shell out to `nc` or `socat` (hacky but works)
4. Use `curl` with `--unix-socket` if available

**Recommendation:** Option 1 — small C wrapper in the R package for Unix socket support. ~50 lines of C.

### Checking Available Packages

```r
available_sys <- function() {
  # Parse apt-cache to find r-cran-* packages
  out <- system2("apt-cache", c("pkgnames", "r-cran-"), stdout = TRUE)
  # Strip prefix, return as matrix matching available.packages() format
}
```

This doesn't need the daemon — can run as regular user.

## Files to Create

```
rapt/
├── CLAUDE.md              # This file
├── daemon/
│   ├── raptd.c
│   ├── Makefile
│   ├── raptd.socket
│   └── raptd.service
├── r-pkg/
│   ├── DESCRIPTION
│   ├── NAMESPACE
│   ├── R/
│   │   ├── socket.R
│   │   ├── manager.R
│   │   ├── integration.R
│   │   └── fallback.R
│   ├── src/
│   │   └── unix_socket.c  # C code for Unix socket support
│   ├── man/
│   └── tests/
│       └── testthat/
└── debian/
    ├── control
    ├── rules
    ├── changelog
    ├── compat
    ├── rapt.install
    ├── rapt.postinst
    └── rapt.postrm
```

## Success Criteria

1. `install.packages("dplyr")` installs via apt with no Python anywhere in the stack
2. Works for non-root user on Ubuntu desktop without sudo password
3. Falls back gracefully when daemon unavailable
4. Passes R CMD check with no warnings
5. Daemon handles malformed input safely
6. Concurrent installs don't corrupt state

## References

- bspm source: https://github.com/Enchufa2/bspm
- r2u: https://github.com/eddelbuettel/r2u
- systemd socket activation: https://0pointer.de/blog/projects/socket-activation.html
- Writing R extensions (C interface): https://cran.r-project.org/doc/manuals/R-exts.html
