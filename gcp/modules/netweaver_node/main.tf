# netweaver deployment in GCP
# official documentation: https://cloud.google.com/solutions/sap/docs/netweaver-ha-planning-guide

resource "google_compute_disk" "netweaver-software" {
  count = var.netweaver_count
  name  = "${terraform.workspace}-nw-installation-sw-${count.index}"
  type  = "pd-standard"
  size  = 60
  zone  = element(var.compute_zones, count.index)
}

# temporary HA solution to create the static routes, eventually this routes must be created by the RA gcp-vpc-move-route
resource "google_compute_route" "nw-route" {
  name                   = "nw-route"
  count                  = var.netweaver_count > 0 ? 1 : 0
  dest_range             = "${element(var.virtual_host_ips, 0)}/32"
  network                = var.network_name
  next_hop_instance      = google_compute_instance.netweaver.0.name
  next_hop_instance_zone = element(var.compute_zones, 0)
  priority               = 1000
}

resource "google_compute_instance" "netweaver" {
  machine_type = var.machine_type
  name         = "${terraform.workspace}-netweaver${var.netweaver_count > 1 ? "0${count.index + 1}" : ""}"
  count        = var.netweaver_count
  zone         = element(var.compute_zones, count.index)

  can_ip_forward = true

  network_interface {
    subnetwork = var.network_subnet_name
    network_ip = element(var.host_ips, count.index)

    access_config {
      nat_ip = ""
    }
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  boot_disk {
    initialize_params {
      image = var.netweaver_image
    }

    auto_delete = true
  }

  attached_disk {
    source      = element(google_compute_disk.netweaver-software.*.self_link, count.index)
    device_name = element(google_compute_disk.netweaver-software.*.name, count.index)
    mode        = "READ_WRITE"
  }

  metadata = {
    sshKeys = "root:${file(var.public_key_location)}"
  }

  service_account {
    scopes = ["compute-rw", "storage-rw", "logging-write", "monitoring-write", "service-control", "service-management"]
  }
}
