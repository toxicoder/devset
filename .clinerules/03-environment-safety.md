# Environment & Shell Safety

> **Purpose**: Safe, reliable command execution in the ezrepo development environment

---

## Core Principles

- **Safety-first**: Default to non-destructive operations; require approval for destructive actions
- **Container-aware**: Commands must work within Ubuntu 24.04 container constraints
- **Shell-agnostic**: Commands must be compatible with Zsh and Oh My Zsh
- **Multi-arch aware**: Commands must work across x86_64, ARM64, and other architectures
- **Verify-first**: Always verify command output before proceeding
- **Minimal-privilege**: Use `sudo` only when absolutely necessary

---

## Shell Compatibility

All commands must be compatible with **Zsh** (default shell) and **Oh My Zsh** plugins.

**Key considerations:**

- Use `#!/bin/zsh` in scripts
- Zsh supports glob qualifiers like `(q)` - avoid or use standard globbing
- History expansion enabled by default - use `setopt NO_HIST_APPEND` if needed
- `%` sequences expanded in prompt - escape with `\%` in scripts

**Recommended Oh My Zsh plugins:**

```zsh
plugins=(git docker sudo history zsh-syntax-highlighting)
```

---

## Container Environment Guidelines

This is a **multi-arch Ubuntu 24.04 container**. Key constraints:

- **No host GUI**: Cannot use GUI applications - use `code` for VS Code, `vim`/`nano` for editors
- **Container filesystem**: Changes to `/` may not persist; use `/home/alx` for work
- **Limited system services**: systemd, cron may not be available
- **No host network**: Network isolation applies; use Docker networks

**Common limitations:**

- GUI applications: ❌ Not available → Use terminal-based editors
- Systemd: ❌ Not available → Use direct service commands or cron
- Docker daemon: ✅ Available (DinD) → Use Docker CLI from container

**Package Management:**

```bash
apt-get update
apt-get install -y --no-install-recommends <package>
apt-get clean && rm -rf /var/lib/apt/lists/*
```

---

## Docker-in-Docker Operations

The environment supports **Docker-in-Docker (DinD)** operations.

**Safe Docker Commands:**

```bash
docker ps && docker ps -a && docker images
docker inspect <container_or_image>
docker logs <container>
docker stats
docker volume ls && docker network ls
```

**Commands Requiring Approval:**

- Container removal: `docker rm -f` - destroys data
- Image removal: `docker rmi` - affects shared images
- System prune: `docker system prune` - destructive

**Docker Compose:**

```bash
# Safe
docker-compose ps
docker-compose logs -f

# Consider approval
docker-compose down

# Requires approval
docker-compose down -v
```

---

## Command Categories & Approval Requirements

| Category                  | Examples                             | Approval    |
| :------------------------ | :----------------------------------- | :---------- |
| **Read-only**             | `ls`, `cat`, `grep`, `docker ps`     | ❌ No       |
| **Informational**         | `docker inspect`, `df -h`, `free -m` | ❌ No       |
| **Non-destructive write** | `touch`, `echo`, `mkdir`             | ❌ No       |
| **Container lifecycle**   | `docker start`, `docker stop`        | ⚠️ Consider |
| **Destructive**           | `docker rm`, `rm -rf`, `docker rmi`  | ✅ Yes      |
| **System modification**   | `apt install`, `apt remove`          | ✅ Yes      |
| **Network change**        | `ufw enable`, firewall rules         | ✅ Yes      |

---

## Pre-Execution Checklist

Before executing any command, verify:

1. **Command understanding**: Do I know what this command does?
2. **Target scope**: What files, containers, or services will be affected?
3. **Reversibility**: Can this operation be undone? How?
4. **Dependencies**: Will this break existing functionality?

---

## Error Handling

**Error detection:**

```bash
command && echo "Success" || echo "Failed with code $?"

if ! command; then
  echo "Command failed: $?"
  exit 1
fi

set -o pipefail
command1 | command2 | command3
```

**Error Codes:**

| Error               | Code  | Recovery                    |
| :------------------ | :---- | :-------------------------- |
| Command not found   | 127   | Check PATH, install package |
| Permission denied   | 126,1 | Use sudo, check permissions |
| Container not found | 1     | Verify container name       |
| Image not found     | 1     | Pull image first            |
| Network error       | 7,56  | Check connectivity, retry   |

---

## Verification Checklist

After executing any command, verify:

- **Exit status**: `echo $?` (0 = success)
- **Expected output**: Does output match expectations?
- **Side effects**: What files, containers, or services changed?

**Quick reference:**

```bash
echo "Exit code: $?"
ls -lh /path/to/created/file
docker ps -a --filter "name=<container_name>"
dpkg -l | grep <package_name>
```

---

## Quick Reference

**Safe commands:**

```bash
uname -a && cat /etc/os-release && df -h && free -m
docker info && docker ps && docker images
ls -lh && find . -name "*.txt" -type f
grep -r "pattern" . --include="*.ts"
```

**Commands requiring approval:**

```bash
docker rm -f <container> && docker rmi <image>
rm -rf <path>
apt-get remove <package>
```
