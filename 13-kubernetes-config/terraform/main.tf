terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token		= var.yc_token
  cloud_id	= var.yc_cloud_id
  zone		= var.yc_region
  folder_id	= var.yc_folder_id
}


resource "yandex_compute_image" "my_image" {
  description	= "Test image"
  source_family	= "ubuntu-2004-lts"
  folder_id	= var.yc_folder_id
  min_disk_size	= 10
  os_type	= "linux"
}


locals {
  instance = {
    default	= 0
    prod	= 2
    stage	= 1
  }
}

resource "yandex_compute_instance" "master" {
  name = "cp-vm-${count.index}-${terraform.workspace}"
  zone = "ru-central1-a"

  resources {
    cores  = 4
    memory = 8
  }

  boot_disk {
    initialize_params {
      image_id	= "${yandex_compute_image.my_image.id}"
      size	= 30
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet10.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file("~/.ssh/id_rsa.pub")}"
  }

#  connection {
#      type        = "ssh"
#      host        = self.public_ip
#      user        = "dpopov"
#      private_key = file("~/.ssh/id_rsa")
#      timeout     = "4m"
#   }
  count 	= local.instance[terraform.workspace]
}


locals {
  id = toset([
  "0",
  "1",
  "2",
  ])
}


resource "yandex_compute_instance" "node" {

  for_each	= local.id
  name		= "node-${each.key}-${terraform.workspace}"
  
  lifecycle {
    create_before_destroy = true
  }
  
  resources {
    cores	= 2
    memory	= 4
  }
  
  boot_disk {
    initialize_params {
      image_id	= "${yandex_compute_image.my_image.id}"
      size = 50
    }
  }

  network_interface {
    subnet_id	= yandex_vpc_subnet.subnet10.id
    nat		= true
  }
  
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

}
  

resource "yandex_vpc_network" "test_network" {
  name = "test-net"
}

resource "yandex_vpc_subnet" "subnet10" {
  v4_cidr_blocks = ["10.0.0.0/8"]
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.test_network.id}"
}


// Create SA
resource "yandex_iam_service_account" "sa" {
  folder_id = "${var.yc_folder_id}"
  name      = "tf-test-sa"
}

// Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = "${var.yc_folder_id}"
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

// Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

// Use keys to create bucket
resource "yandex_storage_bucket" "stage732-1235gwosn" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = "bigbucket"
}
