packer {
  required_plugins {
    googlecompute = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "project" {
  type    = string
  default = "dspj-315716"
}

variable "base_image_family" {
  type    = string
  default = "ubuntu-2004-lts"
}

variable "base_image_project" {
  type    = string
  default = "ubuntu-os-cloud"
}

source "googlecompute" "base_image" {
  project_id              = var.project
  source_image_family     = var.base_image_family
  source_image_project_id = [var.base_image_project]
  ssh_username            = "packer"
  zone                    = "us-central1-a"
  account_file            = "credentials.json"
}

build {
  source "source.googlecompute.base_image" {
    # Here Packer will use the provided image_name instead of defaulting it.
    # Note that fields cannot be overwritten, in other words, you cannot
    # set the 'image_name' field in the top-level source block and here at the
    # same time
    image_name = "base-image"
  }

  provisioner "shell" {
    script = "base.sh"
  }

  provisioner "shell" {

    environment_vars = [
      "FOO=hello world",
    ]
    inline = [
      "echo Adding file to Docker Container",
      "echo \"FOO is $FOO\" > example.txt",
    ]
  }
}