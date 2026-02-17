# Setup ubunut VPS or the docker Installation Playbook

This Ansible playbook installs Docker CE (Community Edition) on Ubuntu machines without Docker Compose, as it's designed for use with Docker Swarm.

## Prerequisites

- Ansible installed on your control machine (non VSP)
- SSH access to target Ubuntu server (VPS) via ssh key
- Sudo privileges on target server

## Usage

### Option 1: GitHub Actions (recommended)

Use the **Setup VPS** workflow from the GitHub Actions UI (`workflow_dispatch`).

Before running, add the following GitHub secrets in **Settings > Secrets and variables > Actions > Secrets**:

| Secret | Description |
|---|---|
| `ROOT_SSH_PRIVATE_KEY` | SSH private key for root access |
| `ROOT_SSH_PUBLIC_KEY` | SSH public key to authorize for root |

Then go to **Actions > Setup VPS > Run workflow** and provide the VPS IP and SSH port.

### Option 2: Run locally

```sh
ansible-playbook -i "<VPS_IP>," setup_vps/ansible/install-docker.yml \
  -u root --private-key ~/.ssh/id_rsa \
  --extra-vars "ssh_port=<SSH_PORT> root_public_key='$(cat ~/.ssh/id_rsa.pub)'"
```

Replace `<VPS_IP>` and `<SSH_PORT>` with your actual values.

## Help information

### Install Ansible on MacOS

```sh
brew install ansible
```