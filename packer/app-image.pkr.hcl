packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

source "amazon-ebs" "ubuntu_app" {
  ami_name = regex_replace(format("production-app-ami-%s-%s", formatdate("YYYYMMDD-hhmmss", timestamp()), timestamp()), "[^A-Za-z0-9()\\[\\] ./\\-_'@]", "")
  instance_type = "t3.micro"
  region        = var.aws_region

  # Source base image: Official Ubuntu 22.04 LTS
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = "ubuntu"
}
# Provision using your existing Ansible configurations + Vault password
build {
  name = "production-app-baker"
  sources = [
    "source.amazon-ebs.ubuntu_app"
  ]

  provisioner "ansible" {
    playbook_file    = "../ansible/site.yml"
    user             = "ubuntu"
    use_proxy        = false
    ansible_env_vars = ["ANSIBLE_HOST_KEY_CHECKING=False"]

    # This flags Packer to look for your vault password file locally
    extra_arguments  = [
      "--vault-password-file", "../ansible/.vault_pass"
    ]
  }
}
