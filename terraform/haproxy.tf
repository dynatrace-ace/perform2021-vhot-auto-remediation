/*
   GCP LINUX HOST DEPLOYMENT
*/

resource "google_compute_address" "haproxy_static" {
  name = "ipv4-address-haproxy-${random_id.instance_id.hex}"
}

resource "google_compute_firewall" "haproxy_allow_http" {
  name    = "haproxy-${random_id.instance_id.hex}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  target_tags = ["haproxy-${random_id.instance_id.hex}"]
}

# A single Google Cloud Engine instance
resource "google_compute_instance" "haproxy-vm" {
  name         = "haproxy-vm-${random_id.instance_id.hex}"
  machine_type = var.instance_size
  zone         = var.gcloud_zone

  boot_disk {
    initialize_params {
      image = var.gce_image_name # OS version
      size  = var.gce_disk_size  # size of the disk in GB
    }
  }

  network_interface {
    network = "default"

    access_config {
      # Include this section to give the VM an external ip address
      nat_ip = google_compute_address.haproxy_static.address
    }
  }

  metadata = {
    sshKeys = "${var.gce_username}:${tls_private_key.acebox_key.public_key_openssh}"
  }

  tags = ["haproxy-${random_id.instance_id.hex}"]

  connection {
    host        = self.network_interface.0.access_config.0.nat_ip
    type        = "ssh"
    user        = var.gce_username
    private_key = tls_private_key.acebox_key.private_key_pem
  }

  ## Add easyTravel binary to home dir
  provisioner "file" {
    source      = "${path.module}/haproxy/install_haproxy.sh"
    destination = "~/install_haproxy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/*.sh",
      "sudo ~/install_haproxy.sh"
    ]
  }

}