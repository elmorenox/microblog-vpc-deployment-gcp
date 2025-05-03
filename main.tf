# main.tf
provider "google" {
  project     = var.project_id
  region      = var.region
}

# VPC Network
resource "google_compute_network" "custom_vpc" {
  name                    = "custom-vpc"
  auto_create_subnetworks = false
}


# Public Subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.custom_vpc.id
  private_ip_google_access = true
}

# Private Subnet
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.custom_vpc.id
  private_ip_google_access = true
}

# Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = "nat-router"
  region  = var.region
  network = google_compute_network.custom_vpc.id
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "cloud-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}


# Jenkins Firewall Rule
resource "google_compute_firewall" "jenkins_fw" {
  name    = "jenkins-firewall"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins"]
}

# Web Server Firewall Rule
resource "google_compute_firewall" "web_fw" {
  name    = "webserver-firewall"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# App Server Firewall Rule
resource "google_compute_firewall" "app_fw" {
  name    = "appserver-firewall"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "5000"]
  }

  source_tags = ["web-server"]
  target_tags = ["app-server"]
}

# Monitoring Firewall Rule
resource "google_compute_firewall" "monitoring_fw" {
  name    = "monitoring-firewall"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "9090", "3000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["monitoring"]
}

# External IP for Jenkins VM
resource "google_compute_address" "jenkins_ip" {
  name   = "jenkins-ip"
  region = var.region
}

# External IP for Web Server VM
resource "google_compute_address" "web_server_ip" {
  name   = "web-server-ip"
  region = var.region
}

# External IP for Monitoring VM
resource "google_compute_address" "monitoring_ip" {
  name   = "monitoring-ip"
  region = var.region
}

# Compute Instances (VMs)

# Jenkins VM
resource "google_compute_instance" "jenkins" {
  name         = "jenkins"
  machine_type = "e2-medium"
  zone         = var.availability_zone
  tags         = ["jenkins"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {
      nat_ip = google_compute_address.jenkins_ip.address
    }
  }

  metadata_startup_script = templatefile("scripts/jenkins_setup.sh", {
    private_key_content = file(var.private_key_path)
  })

  service_account {
    email  = var.service_email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_compute_subnetwork.public_subnet
  ]
}

# Web Server VM with static private IP
resource "google_compute_instance" "web_server" {
  name         = "web-server"
  machine_type = "e2-small"  # Similar to t3.micro
  zone         = var.availability_zone
  tags         = ["web-server"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.public_subnet.id
    network_ip = "10.0.1.100"
    access_config {
      nat_ip = google_compute_address.web_server_ip.address
    }
  }

  metadata_startup_script = templatefile("scripts/web_server_setup.sh", {
    app_server_ip = google_compute_instance.app_server.network_interface[0].network_ip
    private_key_content = file(var.private_key_path)
  })

  service_account {
    email  = var.service_email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_compute_instance.app_server
  ]
}

# App Server VM with static private IP
resource "google_compute_instance" "app_server" {
  name         = "app-server"
  machine_type = "e2-small"  # Similar to t3.micro
  zone         = var.availability_zone
  tags         = ["app-server"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.private_subnet.id
    network_ip = "10.0.2.100"
  }

  metadata_startup_script = templatefile("scripts/app_server_setup.sh", {
    start_app_script_content = file("scripts/start_app.sh")
  })

  service_account {
    email  = var.service_email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_compute_subnetwork.private_subnet,
    google_compute_router_nat.nat
  ]
}

# Monitoring VM
resource "google_compute_instance" "monitoring" {
  name         = "monitoring"
  machine_type = "e2-small"
  zone         = var.availability_zone
  tags         = ["monitoring"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {
      nat_ip = google_compute_address.monitoring_ip.address
    }
  }

  metadata_startup_script = templatefile("scripts/monitoring_setup.sh", {
    app_server_ip = google_compute_instance.app_server.network_interface[0].network_ip
  })

  service_account {
    email  = var.service_email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_compute_instance.app_server
  ]
}