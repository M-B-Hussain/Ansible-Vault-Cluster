# Automated Immutable Infrastructure Cluster with Ansible Vault

This repository contains the Infrastructure-as-Code (IaC) configuration to automatically provision, configure, and secure a multi-node, load-balanced web application cluster. Using Vagrant and Ansible, the environment demonstrates high-availability deployment patterns, local hostname mapping, and cryptographic secret isolation.

---

## System Architecture

The environment simulates a professional multi-tier deployment architecture contained completely within a private virtual network (`192.168.56.0/24`).


  * Public Gateway (Port 80)

    * Forwards traffic directly to the proxy frontend

  * Frontend Tier (lb01 | 192.168.56.10)

    * Engine: Nginx Reverse Proxy

    * Upstream Cluster Configuration: myapp pool mapping

    * Target Routing Strategy: Round-Robin Load Balancing

    * Equally alternates distribution profiles to available backend hosts

  * Backend Application Tier (webservers group)

    * Node 01 (app01 | 192.168.56.11)

      * Engine: Apache HTTP Daemon (apache2)

      * Serving Element: Dynamic Jinja2 index.html file

      * Local Security Asset: Protected app_config.txt (Injected securely from Ansible Vault variable db_password)

    * Node 02 (app02 | 192.168.56.12)

      * Engine: Apache HTTP Daemon (apache2)

      * Serving Element: Dynamic Jinja2 index.html file

      * Local Security Asset: Protected app_config.txt (Injected securely from Ansible Vault variable db_password)

### Architectural Components:
1. **Control Node (Host Machine):** Executes Ansible playbooks, handles decryption operations in-memory via Ansible Vault, and manages orchestration lifecycle.
2. **Load Balancer Layer (`lb01`):** Runs an upstream-proxied Nginx server distributing inbound connection handshakes across downstream services.
3. **Application Layer (`app01` / `app02`):** Redundant standalone Apache HTTP backend environments processing HTTP requests independently.

---

## Milestones Achieved

Through step-by-step optimization and debugging, the following engineering milestones were reached:

* **✅ Automated Infrastructure Orchestration:** Successfully separated structural execution blocks into decoupled plays targeting independent node hostgroups seamlessly (`webservers` and `loadbalancers`).
* **✅ Corrected Nginx State & Startup Dependency:** Resolved systemd service dependency loops by implementing explicit package initialization routines (`state: started`, `enabled: yes`), allowing configurations to be applied safely without crashing inactive daemons.
* **✅ Validated Upstream Target Resolution:** Realigned naming mismatches within proxy configurations (`myapp` routing mappings) and integrated automated dynamic local hostname registration routines inside `/etc/hosts` to ensure 100% network reachability.
* **✅ Cryptographic Secret Isolation (Zero-Trust Variable Storage):** Integrated **Ansible Vault (AES256 standard)** to fully encrypt environmental passwords (`vars.yml`) at rest, mitigating security risks of committing plain-text variables to code repositories like GitHub.

---

## 🛠️ Repository File Structure

```text
.
├── site.yml                 # Master automation playbook containing configuration plays
├── vars.yml                 # Encrypted Ansible Vault variable file containing secrets
├── nginx.conf.j2            # Jinja2 template file for Nginx Load Balancer settings
├── index.html.j2            # Dynamic webpage template for Apache backends
└── .vault_pass              # Local hidden password tracking file
└── rotate-vault.sh          # Create new passwords whenever you want to keep it a secret

```

---

## Deployment & Operational Guide

### Prerequisites

Ensure your local host machine has Ansible installed:

```bash
sudo apt update && sudo apt install ansible -y

```

### Start Vagrant VMs

Before running Ansible playbooks make sure the Vagrant virtual machines are running so the control node can reach the guests over the host-only network. Start all VMs with:

```bash
vagrant up
# or start specific VMs:
vagrant up lb01 app01 app02
```

Verify the machines are up and reachable:

```bash
vagrant status
vagrant ssh app01
# or test SSH directly with the Vagrant key:
ssh -i .vagrant/machines/app01/virtualbox/private_key vagrant@192.168.56.11
```

Once the VMs are confirmed running, proceed to run the playbook as described below.

### 1. View or Modify Protected Secrets

The variable storage containing sensitive application details (`db_password`) is cryptographically protected. To view or edit it without removing security properties, run:

```bash
# To safely view the secrets file
ansible-vault view vars.yml

# To edit the secrets file inline
ansible-vault edit vars.yml

```

### 2. Automated Secrets Rotation (Vault Re-keying)

To rotate operational credentials within `vars.yml` without interrupting live node states or requiring interactive terminal typing, use the automated re-key workflow script `rotate-vault.sh`.

#### Ensure the automation script has execution permissions:

   ```bash
   chmod +x rotate-vault.sh
   ```
Generate or write your new password into a temporary file named .vaultpass_new in the project root directory.

#### Trigger the script from your terminal:

```bash
./rotate-vault.sh
```
### 3. Manual Execution (Interactive Mode)

To trigger the deployment automation cluster and provide your decryption credentials manually at the command prompt:

```bash
ansible-playbook site.yml --ask-vault-pass

```

### 4. Automated Execution (CI/CD / Hands-Free Mode)

To run the automated deployment pipeline without manual terminal interactive steps, read the passphrase string directly via an isolated file pointer:

```bash
ansible-playbook site.yml --vault-password-file .vault_pass

```

### 5. Verifying Load Balancer Multi-Node Distribution

To confirm that Nginx is balancing traffic evenly between both backend targets in real time, run a standard HTTP request loop against the load balancer IP:



#### Option A: Target "Server" (Simplest)

```bash
for i in {1..6}; do curl -s http://192.168.56.10 | grep -i "Server"; done
```
#### Option B: Target "app" (Matches hostnames)

```bash
for i in {1..6}; do curl -s http://192.168.56.10 | grep -i "app"; done
```
*Expected output should cycle cleanly, showing responses alternating between `app01` and `app02`.*

#### Option C: View the Whole Page (No grep at all)

If you want to see exactly what Nginx is sending back without filtering anything out, drop the grep entirely:

```bash
for i in {1..3}; do curl -s http://192.168.56.10; echo "----------------"; done
```