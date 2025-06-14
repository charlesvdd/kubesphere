🚀 Kubernetes 1.28 Installation with containerd (Ready for KubeSphere 4.x)
This repository contains an automated script to install Kubernetes v1.28.0 on Ubuntu 22.04 LTS, using containerd as the runtime, with all best practices to prepare for the installation of KubeSphere 4.1.3 via Helm.

📄 Main File
setup-kubesphere.sh → Installs Kubernetes, configures containerd, installs Flannel, and prepares the cluster.
✅ What the Script Does
Step	Details
✅ Checks for root execution	Refuses to run as a non-root user
✅ Installs containerd	With SystemdCgroup = true configuration
✅ Configures Kubernetes	Official v1.28 repository + kubeadm, kubelet, kubectl in fixed version
✅ Initializes the cluster	Via kubeadm init with pod CIDR 10.244.0.0/16 for CNI compatibility
✅ Installs Flannel CNI	Compatible with the used pod CIDR
✅ Configures kubectl	Automatic copy of kubeconfig for the user
✅ Checks node status	Loops until the node is Ready
▶️ Launch the Installation
1. Clone the Branch
Copier
git clone -b Kubernetes/conteneraid/1.28.0 https://github.com/charlesvdd/kubesphere.git
cd kubesphere
2. Make the Script Executable
Copier
chmod +x setup-kubesphere.sh
3. Run the Script
Copier
./setup-kubesphere.sh
This version includes instructions on how to make the script executable and run it locally.
