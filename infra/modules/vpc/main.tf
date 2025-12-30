resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# 1. VPC Network
resource "google_compute_network" "main" {
  name                            = var.network_name
  auto_create_subnetworks         = false # 這是關鍵，我們要自定義 Subnet
  mtu                             = 1460
  delete_default_routes_on_create = false

  depends_on = [google_project_service.compute]
}

# 2. Subnet with Secondary Ranges for GKE
resource "google_compute_subnetwork" "private" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id

  # 私有 Google Access (GKE Private Cluster 必備)
  private_ip_google_access = true

  # GKE 專用的次要 IP 範圍
  secondary_ip_range {
    range_name    = var.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.services_range_name
    ip_cidr_range = var.services_cidr
  }
}

# 3. Cloud Router (為了 NAT)
resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.main.id
}

# 4. Cloud NAT (讓私有 Subnet 可以連網際網路，例如 pull docker images)
resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
