#!/usr/bin/env bash
set -euo pipefail

K8S_VERSION="1.28.0-00"
CNI_PLUGIN="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
COLOR_RESET="\e[0m"
COLOR_OK="\e[32m"
COLOR_ERR="\e[31m"
COLOR_INFO="\e[34m"

log_success() { echo -e "${COLOR_OK}[OK]${COLOR_RESET} $1"; }
log_error() { echo -e "${COLOR_ERR}[ERROR]${COLOR_RESET} $1"; exit 1; }
log_info() { echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $1"; }

check_step() {
  "$@" && log_success "$*" || log_error "$*"
}

# Check root
if [ "$EUID" -ne 0 ]; then
  log_error "This script must be run as root."
fi
log_success "The script is running as root."

# Kernel modules
log_info "Enabling required kernel modules..."
check_step modprobe overlay
check_step modprobe br_netfilter

log_info "Configuring sysctl for Kubernetes..."
tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
check_step sysctl --system

# Install containerd
log_info "Installing containerd..."
check_step apt-get update
check_step apt-get install -y containerd

log_info "Configuring containerd..."
check_step mkdir -p /etc/containerd
check_step rm -f /etc/containerd/config.toml
check_step containerd config default | tee /etc/containerd/config.toml > /dev/null
check_step sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
check_step systemctl daemon-reexec
check_step systemctl restart containerd
check_step systemctl enable containerd

# Add Kubernetes repository
log_info "Adding Kubernetes 1.28 repository..."
check_step curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

check_step apt-get update
check_step apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}
check_step apt-mark hold kubelet kubeadm kubectl

# Initialize the cluster
log_info "Initializing Kubernetes cluster..."
check_step kubeadm init --kubernetes-version=1.28.0 --pod-network-cidr=10.244.0.0/16

# User configuration
log_info "Configuring kubectl for the user..."
mkdir -p $HOME/.kube
check_step cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
check_step chown $(id -u):$(id -g) $HOME/.kube/config

# CNI Networking (Flannel)
log_info "Installing Flannel network..."
check_step kubectl apply -f "${CNI_PLUGIN}"

# Node verification
log_info "Checking node status..."
until kubectl get nodes 2>/dev/null | grep -q ' Ready '; do
  echo -n "." && sleep 3
done
log_success "The master node is in 'Ready' state!"
