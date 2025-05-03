# outputs.tf
output "jenkins_public_ip" {
  description = "The public IP address of the Jenkins server"
  value       = google_compute_address.jenkins_ip.address
}

output "web_server_public_ip" {
  description = "The public IP address of the Web Server"
  value       = google_compute_address.web_server_ip.address
}

output "app_server_private_ip" {
  description = "The private IP address of the Application Server (only accessible from within the VPC)"
  value       = google_compute_instance.app_server.network_interface[0].network_ip
}

output "monitoring_public_ip" {
  description = "The public IP address of the Monitoring server"
  value       = google_compute_address.monitoring_ip.address
}

output "jenkins_initial_password_cmd" {
  description = "Command to get Jenkins initial admin password"
  value       = "SSH to the Jenkins server and run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}

output "web_app_url" {
  description = "URL to access the web application (through the Web Server)"
  value       = "http://${google_compute_address.web_server_ip.address}"
}

output "monitoring_grafana_url" {
  description = "URL to access Grafana monitoring dashboard"
  value       = "http://${google_compute_address.monitoring_ip.address}:3000"
}

output "monitoring_prometheus_url" {
  description = "URL to access Prometheus monitoring"
  value       = "http://${google_compute_address.monitoring_ip.address}:9090"
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${google_compute_address.jenkins_ip.address}:8080"
}