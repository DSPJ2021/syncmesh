terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.5.0"
    }
  }
}

provider "google" {
  credentials = file("credentials.json")

  project = var.project
  region  = local.nodes[0].region
  zone    = local.nodes[0].location
}

locals {
  name_prefix = "experiment-syncmesh-${var.instance_scenario}"
  scenario    = "syncmesh"
}

resource "tls_private_key" "orchestrator_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  deployment_keys = [{
    user        = "orchestrator"
    keymaterial = tls_private_key.orchestrator_key.public_key_openssh
  }]
  ssh_keys = join("\n", [for key in concat(var.ssh_keys, local.deployment_keys) : "${key.user}:${key.keymaterial}"])
}

# resource "google_compute_project_metadata" "my_ssh_key" {
#   metadata = {
#     ssh-keys = local.ssh_keys
#   }
# }



locals {
  # Zones: https://cloud.google.com/compute/docs/regions-zones
  nodes = local.nodes_selection[var.instance_scenario]
  # This is an array with all location the nodes will be deployed in. 
  # The first element will exclusivly host client, servers and the orchestrator.
  nodes_selection = {
    "only-1" = [
      {
        region   = "us-central1"
        location = "us-central1-a",
        number   = 0
      },
      {
        region   = "us-central1"
        location = "us-central1-a",
        number   = 1
      },
    ]
    "without-latency-3" : [
      {
        region   = "us-central1"
        location = "us-central1-a",
        number   = 0
      },
      {
        region   = "us-central1"
        location = "us-central1-a",
        number   = 1
      },
      {
        region   = "us-central1"
        location = "us-central1-a",
        number   = 2
      },
      {
        region   = "us-central1"
        location = "us-central1-a",
        number   = 3
      },
    ],
    "with-latency-3"  = concat(local.node_increments.first3),
    "with-latency-6"  = concat(local.node_increments.first3, local.node_increments.second3),
    "with-latency-9"  = concat(local.node_increments.first3, local.node_increments.second3, local.node_increments.third3),
    "with-latency-12" = concat(local.node_increments.first3, local.node_increments.second3, local.node_increments.third3, local.node_increments.fourth3),
  }
  node_increments = {
    "first3" = [{
      region   = "us-central1"
      location = "us-central1-a",
      number   = 0
      },
      # TODO reset to
      #{
      #  region   = "northamerica-northeast1"
      #  location = "northamerica-northeast1-a",
      #  number   = 3
      #},
      {
        region   = "australia-southeast1"
        location = "australia-southeast1-c",
        number   = 1
      },
      {
        region   = "asia-east1"
        location = "asia-east1-a"
        number   = 2
      },
      {
        region   = "europe-west6"
        location = "europe-west6-a"
        number   = 3
      },
    ],
    "second3" : [
      {
        region   = "australia-southeast2"
        location = "australia-southeast2-c",
        number   = 4
      },
      {
        region   = "southamerica-east1"
        location = "southamerica-east1-c"
        number   = 5
      },
      {
        region   = "asia-south2"
        location = "asia-south2-c"
        number   = 6
      },
    ],
    "third3" = [
      {
        region   = "asia-northeast2"
        location = "asia-northeast2-b",
        number   = 7
      },
      {
        region   = "europe-central2"
        location = "europe-central2-a",
        number   = 8
      },
      {
        region   = "us-west1"
        location = "us-west1-a",
        number   = 9
      },
    ],
    "fourth3" = [
      {
        region   = "asia-southeast2"
        location = "asia-southeast2-a",
        number   = 10
      },
      {
        region   = "europe-west1"
        location = "europe-west1-b",
        number   = 11
      },
      {
        region   = "us-east1"
        location = "us-east1-b",
        number   = 12
      }
    ]
  }
}

resource "google_compute_subnetwork" "subnet_with_logging" {
  for_each = {
    for index, vm in local.nodes :
    index => vm
  }
  name          = "${local.name_prefix}-subnetwork-${each.value.number}"
  ip_cidr_range = "10.${each.value.number}.0.0/16"
  region        = each.value.region
  network       = google_compute_network.vpc_network.id



  #  log_config {
  #
  #    aggregation_interval = "INTERVAL_5_SEC"
  #    flow_sampling        = 1
  #    metadata             = "INCLUDE_ALL_METADATA"
  #  }
}

resource "google_compute_network" "vpc_network" {
  name                    = "${local.name_prefix}-network"
  auto_create_subnetworks = false

}

# Add Internet Access to VMs without public IP
resource "google_compute_router" "router" {
  for_each = {
    for index, vm in local.nodes :
    index => vm
  }
  name    = "${local.name_prefix}-router-${each.value.number}"
  region  = each.value.region
  network = google_compute_network.vpc_network.id

  bgp {
    asn = 64512 + each.value.number
  }
}

resource "google_compute_router_nat" "nat" {
  for_each = {
    for index, vm in length(regexall("with-latency", var.instance_scenario)) > 0 ? local.nodes : slice(local.nodes, 0, 1) :
    index => vm
  }
  name                               = "${local.name_prefix}-router-nat-${each.value.number}"
  region                             = each.value.region
  router                             = google_compute_router.router[each.value.number].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  #  log_config {
  #    enable = false
  #    filter = "ERRORS_ONLY"
  #  }
}



data "google_compute_image" "container_optimized_image" {
  # Use a container optimized image
  # See a list of all images : https://console.cloud.google.com/compute/images
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}




resource "google_compute_instance" "nodes" {
  for_each = {
    # Ignore first, because it's the basic test infrastructure
    for index, vm in slice(local.nodes, 1, length(local.nodes)) :
    index => vm
  }
  name         = "${local.name_prefix}-node-instance-${each.value.number}"
  machine_type = var.machine_type

  tags = ["demo-vm-instance"]
  metadata = {
    ssh-keys = local.ssh_keys
  }
  zone                      = each.value.location
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.container_optimized_image.self_link
    }
  }

  network_interface {
    network_ip = "10.${each.value.number}.0.1${each.value.number}"
    subnetwork = google_compute_subnetwork.subnet_with_logging[each.value.number].name
    dynamic "access_config" {
      for_each = var.public_access ? ["active"] : []
      content {}
    }
  }
  service_account {
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

  metadata_startup_script = templatefile("${path.module}/setup_scripts/node-startup-${local.scenario}.tpl", { id = each.value.number, mongo_version = var.test_mongo_version, faasd_version = var.test_faasd_version })
  depends_on              = [google_compute_router_nat.nat]
}

resource "google_compute_instance" "client" {
  name                      = "${local.name_prefix}-client-instance"
  machine_type              = var.machine_type
  allow_stopping_for_update = true

  tags = ["demo-vm-instance"]
  metadata = {
    ssh-keys = local.ssh_keys
  }


  boot_disk {
    initialize_params {
      image = data.google_compute_image.container_optimized_image.self_link
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_with_logging[0].name
    network_ip = "10.0.0.2"
    dynamic "access_config" {
      for_each = var.public_access ? ["active"] : []
      content {}
    }
  }
  service_account {
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }
  metadata_startup_script = templatefile("${path.module}/setup_scripts/client-startup.tpl", { instances = google_compute_instance.nodes, testscript = file("${path.module}/test_scripts/client-${local.scenario}.py"), mongo_version = var.test_mongo_version })
}

resource "google_compute_instance" "test-orchestrator" {
  name                      = "${local.name_prefix}-test-orchestrator"
  machine_type              = var.machine_type
  allow_stopping_for_update = true

  tags = ["demo-vm-instance"]
  metadata = {
    ssh-keys = local.ssh_keys
  }


  boot_disk {
    initialize_params {
      image = data.google_compute_image.container_optimized_image.self_link
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_with_logging[0].name
    network_ip = "10.0.0.255"
    #    dynamic "access_config" {
    #      for_each = var.public_access ? ["active"] : []
    #      content {}
    #    }
    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

  metadata_startup_script = templatefile("${path.module}/setup_scripts/test-orchestrator.tpl", {
    nodes       = google_compute_instance.nodes,
    client      = google_compute_instance.client,
    private_key = tls_private_key.orchestrator_key.private_key_pem,
    seperator   = var.seperator_request_ip,
    scenario    = local.scenario,
    repetitions = var.test_client_repetitions,
    sleep_time  = var.test_sleep_time,
    pre_time    = var.test_pre_time,
    testscript  = file("${path.module}/test_scripts/test.sh")
  })

}


resource "google_compute_firewall" "ssh-rule" {
  name    = "${local.name_prefix}-rule-ssh"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  dynamic "allow" {
    for_each = var.public_access ? ["8080", "27017"] : []
    content {
      protocol = "tcp"
      ports    = [allow.value]
    }
  }

  target_tags   = ["demo-vm-instance"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "traffic-rule" {
  name    = "${local.name_prefix}-rule"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  target_tags   = ["demo-vm-instance"]
  source_ranges = ["10.0.0.0/8"]
}

resource "google_storage_bucket" "bucket" {
  name          = "${local.name_prefix}-log-bucket"
  project       = var.project
  location      = local.nodes[0].region
  force_destroy = true
}

# Not working for delete step
resource "local_file" "external_addresses" {
  content  = templatefile("${path.module}/ips.tpl", { instances = google_compute_instance.nodes })
  filename = "${path.module}/nodes.txt"
}

resource "local_file" "orchestrator_address" {
  content  = google_compute_instance.test-orchestrator.network_interface.0.access_config.0.nat_ip
  filename = "${path.module}/orchestrator.txt"
}

resource "local_file" "cert" {
  content         = tls_private_key.orchestrator_key.private_key_pem
  filename        = "orchestrator.pem"
  file_permission = "600"
}


# For Advanced Logging:
# https://registry.terraform.io/modules/terraform-google-modules/cloud-operations/google/latest


module "output_log_nodes" {
  for_each = {
    # Ignore first, because it's the basic test infrastructure
    for index, vm in slice(local.nodes, 1, length(local.nodes)) :
    index => vm
  }
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 2.0"
  # skip_download            = false
  service_account_key_file = "credentials.json"


  platform = "linux"

  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "compute instances get-serial-port-output ${local.name_prefix}-node-instance-${each.value.number} --project ${var.project} --zone ${each.value.location} > /tmp/logoutput/${local.name_prefix}-node-instance-${each.value.number}.log"
  module_depends_on = [
    google_compute_instance.nodes
  ]
}

module "output_log_orchestrator" {

  source  = "terraform-google-modules/gcloud/google"
  version = "~> 2.0"
  # skip_download            = false
  service_account_key_file = "credentials.json"


  platform = "linux"

  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "compute instances get-serial-port-output ${local.name_prefix}-test-orchestrator --project ${var.project} --zone ${local.nodes[0].location} > /tmp/logoutput/${local.name_prefix}-test-orchestrator.log"
  module_depends_on = [
    google_compute_instance.test-orchestrator
  ]
}

module "output_log_client" {

  source  = "terraform-google-modules/gcloud/google"
  version = "~> 2.0"
  # skip_download            = false
  service_account_key_file = "credentials.json"


  platform = "linux"

  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "compute instances get-serial-port-output ${local.name_prefix}-client-instance --project ${var.project} --zone ${local.nodes[0].location} > /tmp/logoutput/${local.name_prefix}-client-instance.log"
  module_depends_on = [
    google_compute_instance.test-orchestrator
  ]
}
