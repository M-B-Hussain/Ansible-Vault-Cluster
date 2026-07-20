# Automated Immutable Infrastructure Cluster with Ansible Vault

This repository contains Infrastructure-as-Code (IaC) and automation to provision, configure, and secure a multi-node, load‑balanced web application cluster on AWS. It uses Terraform to create AWS resources and Ansible (with Ansible Vault) to provision and configure instances. The project demonstrates high-availability deployment patterns, private/public subnet isolation, and encrypted secret management.

---

## System Architecture

The deployment targets AWS and organizes resources across public and private subnets inside an AWS VPC.

  * Public Application Load Balancer (ALB)

    * Public entry point for HTTP traffic (port 80) and forwards requests to the private application fleet.

  * Application Fleet (Auto Scaling Group)

    * Back-end application nodes run from a Launch Template (AMI built externally or provided via the `target_ami_id` Terraform variable).

    * Instances are placed in private subnets and receive traffic exclusively from the ALB via a dedicated security group.

    * Autoscaling configuration controls desired/min/max instance count and handles replacement/rollout behavior.

  * Configuration & Secrets

    * Ansible (invoked from a control host that can reach the VPC — e.g., a bastion or CI runner with VPC access) configures Apache and deploys templated content.

    * Secrets (like `db_password`) are stored encryptically in `vars.yml` and decrypted at runtime using Ansible Vault.

### Architectural Components:
1. **Control Node (Operator/CI Runner):** Runs Terraform to provision AWS resources and runs Ansible to configure instances. The control node must have network access to the target VPC (bastion, VPN, or AWS Systems Manager).
2. **ALB (Application Load Balancer):** Public-facing HTTP entrypoint created by Terraform and configured to forward to the application Target Group.
3. **Auto Scaling Group & Launch Template:** Manages the lifecycle of the application nodes using the supplied AMI and instance type.

---

## Milestones Achieved

Through step-by-step optimization and debugging, the following engineering milestones were reached:

* **✅ Automated Infrastructure Orchestration:** Successfully separated structural execution blocks into decoupled plays targeting independent node hostgroups seamlessly (`webservers` and `loadbalancers`).
* **✅ Corrected Nginx State & Startup Dependency:** Resolved systemd service dependency loops by implementing explicit package initialization routines (`state: started`, `enabled: yes`), allowing configurations to be applied safely without crashing inactive daemons.
* **✅ Validated Upstream Target Resolution:** Realigned naming mismatches within proxy configurations (`myapp` routing mappings) and integrated automated dynamic local hostname registration routines inside `/etc/hosts` to ensure 100% network reachability.
* **✅ Cryptographic Secret Isolation (Zero-Trust Variable Storage):** Integrated **Ansible Vault (AES256 standard)** to fully encrypt environmental passwords (`vars.yml`) at rest, mitigating security risks of committing plain-text variables to code repositories like GitHub.

---

## Deployment & Operational Guide

### Prerequisites

Ensure the control host (your laptop or CI runner) has the following installed and configured:

- Terraform (>= 1.5.0)
- AWS CLI configured with credentials that can create the required resources (aws configure)
- Ansible (2.9+ recommended)
- Optional: jq (useful for parsing CLI output)

Also ensure your AWS_PROFILE and AWS_REGION are set if you use a named profile. Example:

```bash
export AWS_PROFILE=default
export AWS_REGION=eu-central-1
```

### 1. Provision AWS Infrastructure (Terraform)

The Terraform code in the `terraform/` directory creates the VPC, subnets, ALB, target group, security groups and an Auto Scaling Group using a Launch Template.

1. Change into the terraform directory:

```bash
cd terraform
```

2. Initialize Terraform and install providers:

```bash
terraform init
```

3. Plan and apply. You must provide the AMI ID to use for the Launch Template via the `target_ami_id` variable. Example (replace with your AMI):

```bash
terraform plan 
terraform apply 
```

Alternatively create a `terraform.tfvars` file with values for `aws_region` and `target_ami_id` and run `terraform apply`.

Note: If your control machine cannot reach private subnets, the Ansible provisioning step must be executed from a host that has network access to the VPC (bastion host, CI runner inside the VPC, or via AWS SSM).

### 2. Finding the Load Balancer (ALB) endpoint

After a successful apply, the ALB DNS name is visible in the AWS Console under EC2 > Load Balancers. To get it via AWS CLI run:

```bash
aws elbv2 describe-load-balancers --names production-app-alb --query 'LoadBalancers[0].DNSName' --output text --region ${AWS_REGION}
```

Use the returned DNS name to test HTTP traffic.

### 3. Running Ansible to configure instances

The repository's Ansible playbook (`site.yml`) expects target hosts in an inventory under the `webservers` group. Because the Auto Scaling Group places instances into private subnets without public IPs, run Ansible from a control host that has network access to the private IPs (bastion host, VPN, or CI runner).

Create a simple `inventory.ini` with the private IPs of the instances. You can obtain the private IPs via the AWS CLI (filter by tag `Name=asg-app-node`) or by adding Terraform outputs to the configuration.

Example inventory.ini (replace with actual private IPs and key path):

```ini
[webservers]
10.0.1.12 ansible_user=ubuntu ansible_private_key_file=~/.ssh/mykey.pem
10.0.2.15 ansible_user=ubuntu ansible_private_key_file=~/.ssh/mykey.pem
```

Run the playbook (interactive vault pass):

```bash
ansible-playbook -i inventory.ini site.yml --ask-vault-pass
```

Or, to run non-interactively using a vault password file (ensure this file is stored securely and not committed):

```bash
ansible-playbook -i inventory.ini site.yml --vault-password-file .vault_pass
```

### 4. Managing secrets (Ansible Vault)

To view or edit the encrypted `vars.yml`:

```bash
ansible-vault view vars.yml
ansible-vault edit vars.yml
```

To rotate the vault password using the provided `rotate-vault.sh` script, ensure it is executable:

```bash
chmod +x rotate-vault.sh
./rotate-vault.sh
```

(Review the script before running to ensure it meets your operational policies.)

### 5. Verifying the deployment

Once the ALB DNS is known, verify HTTP responses using curl:

```bash
curl http://<ALB_DNS_NAME>
```

You can run repeated requests to confirm responses are served by different backend instances (the ALB will forward to the target group behind the scenes).

### Notes & Best Practices

- Do not commit `.vault_pass` or other secret material to version control. Keep vault password files in a secure store.
- The `target_ami_id` should reference a hardened image with the expected OS and SSH user (e.g., `ubuntu`) so Ansible can connect successfully.
- For fully hands-free provisioning, consider adding Terraform outputs for instance private IPs and ALB DNS, then generate an inventory automatically for Ansible or use AWS SSM to run Ansible without SSH access.
