terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}

resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"
  zone                      = "ru-central1-a"


  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8earpjmhevh8h6ug5o"
      type = "network-hdd"
      size = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
  
  metadata = {
    user-data = "${file("./meta.txt")}"
  }

  scheduling_policy {
    preemptible = true
  }

}

# save public ip to hosts file
resource "local_file" "ip" {
    filename  = "./deploy_nginx/hosts"
    content = <<-EOT
    [nginx]
    ${yandex_compute_instance.vm-1.network_interface.0.nat_ip_address}
    EOT
}

# run nginx playbook
resource "null_resource" "vm-1" {
  depends_on = [
    local_file.ip
  ]

  # need to wait ssh initialization
  provisioner "remote-exec" {
      connection {
        host        = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
        type        = "ssh"
        user        = "egushchin"
      }
      inline = ["echo 'connected!'"]
  }  

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u egushchin -i ./deploy_nginx/hosts --private-key ${var.private_key_path} ${var.playbook_path_nginx}"
  }
}
