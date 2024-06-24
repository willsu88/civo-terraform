terraform {
  required_providers {
    civo = {
      source = "civo/civo"
    }
  }
}

provider "civo" {
  token = "<YOUR API KEY>"
  region = "FRA1" # Replace with your preferred region
}

# Fetch default network
data "civo_network" "default_network" {
  label = "default"
}

# # Create a Reserved IP
resource "civo_reserved_ip" "test_ip" {
    name = "testing_ip" 
}

# Create an instance
resource "civo_instance" "example_instance" {
  hostname         = "example-instance"
  size             = "g3.xsmall"
  network_id       = data.civo_network.default_network.id
  region           = "FRA1"
  disk_image = "debian-10"
  reserved_ipv4 = civo_reserved_ip.test_ip.ip # set the reserved ip
}

# Create a volume
resource "civo_volume" "example_volume" {
  name      = "example-volume"
  size_gb   = 10
  region    = "FRA1"
  network_id = data.civo_network.default_network.id
}

# Attach the volume to the instance
resource "civo_volume_attachment" "example_attachment" {
  volume_id   = civo_volume.example_volume.id
  instance_id = civo_instance.example_instance.id
}

# Create a firewall
# resource "civo_firewall" "my-firewall" {
#     name = "my-firewall"
#     protocol = "tcp"
#     start_port = "6443"
#     end_port = "6443"
#     cidr = ["0.0.0.0/0"]
#     direction = "ingress"
#     label = "kubernetes-api-server"
#     action = "allow"
# }

resource "civo_firewall" "my-firewall" {
  name                 = "my-firewall"
  network_id           = data.civo_network.default_network.id
  create_default_rules = false
  ingress_rule {
    label      = "tcp"
    protocol   = "tcp"
    port_range = "6443"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }

  egress_rule {
    label      = "all"
    protocol   = "tcp"
    port_range = "1-65535"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }
}

resource "civo_kubernetes_cluster" "my-cluster" {
    name = "my-cluster"
    applications = "loki,prometheus-operator,kong-ingress-controller"
    firewall_id = civo_firewall.my-firewall.id
    pools {
        size = "g4s.kube.medium"
        node_count = 2
    }
}

output "kubeconfig" {
  value     = civo_kubernetes_cluster.my-cluster.kubeconfig
  sensitive = true
}
