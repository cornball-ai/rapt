# Security Policy

## Overview

rapt consists of a privileged C daemon (`raptd`) that executes apt commands on behalf of unprivileged users. This design requires careful security consideration.

## Architecture

```
User R session  →  Unix socket  →  raptd (root)  →  apt
```

The daemon runs as root and accepts commands from any local user via a world-readable Unix socket at `/run/raptd.sock`.

## Security Model

### What rapt trusts

- **Local users**: Any user who can connect to the socket can install/remove packages
- **Configured apt repositories**: Packages are installed from whatever repos are configured in `/etc/apt/sources.list*`
- **Package name validation**: Only `[a-zA-Z0-9._]` characters are allowed

### What rapt does NOT trust

- **User input beyond validation**: All package names are strictly validated before being passed to apt
- **Shell expansion**: Commands are executed via direct `execve()`, never through a shell

## Known Limitations

1. **No user authentication**: Any local user can install packages. This is by design (matches bspm behavior) but means a compromised local account can install arbitrary packages from configured repos.

2. **Repo trust**: rapt does not verify packages come from r2u specifically. A malicious apt repo added to the system could serve packages with valid names.

3. **Remove capability**: The `remove` command allows any user to remove r-cran-* packages. Consider whether this is appropriate for your environment.

## Hardening Options

### Restrict socket access to a group

Edit `/lib/systemd/system/raptd.socket`:

```ini
[Socket]
SocketMode=0660
SocketGroup=r-users
```

Then add authorized users to the `r-users` group.

### Disable remove command

Modify the daemon to reject `remove` commands if your environment doesn't need this capability.

### Audit logging

All commands are logged to syslog. Monitor with:

```bash
journalctl -u raptd.service
```

## Reporting Vulnerabilities

Please report security vulnerabilities privately via GitHub's security advisory feature or email troy@cornball.ai.

Do not open public issues for security vulnerabilities.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
