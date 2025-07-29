# JumpCloud CLI (jc-cli)

A simple, interactive, menu-driven CLI tool built with `bash` for managing users, groups, and applications via the [JumpCloud API v2](https://docs.jumpcloud.com/api/v2/).

---

## 🚀 Features

- Add user to group  
- Remove user from group  
- List all users  
- List all groups  
- Set / update API key  
- Manage system metadata:
  - List all systems
  - View metadata of a specific system
  - Add metadata to a system
  - Remove metadata from a system
- Application management:
  - List all applications
  - View application details
- Create import jobs (for IdM-integrated apps)

---

## ⚙️ Installation

### Prerequisites

- Linux or WSL terminal  
- Bash shell  
- `curl`, `jq` installed  
- Git installed

### Clone and Setup

```bash
git clone https://github.com/<yourusername>/jc-cli.git
cd jc-cli
chmod +x jc-cli.sh install.sh
./install.sh
```
After Setup run
```bash
jc-cli
```
