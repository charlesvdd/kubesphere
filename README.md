# KubeSphere Kickstarter

This repository provides a one-stop script to quickly set up a vanilla Kubernetes cluster (v1.29.13) and install KubeSphere v4.1.3 on Ubuntu.

## Repository Structure

- **kubesphere-kickstarter.sh**: Main installation script. Must be run as root.

## Prerequisites

- Ubuntu 20.04+ or compatible Debian-based distribution
- Minimum 2 CPU cores, 4 GB RAM
- Internet connectivity to download packages and manifests
- Sudo or root privileges

## Supported Versions

- **Kubernetes**: upstream v1.29.13
- **KubeSphere**: v4.1.3
- **Network Plugin**: Calico (default). You may replace with Flannel, Weave, etc.

## Usage

1. **Clone the repository**

   ```bash
   git clone https://github.com/charlesvdd/kubesphere.git
   cd kubesphere
   ```

2. **Make the script executable**

   ```bash
   chmod +x kubesphere-kickstarter.sh
   ```

3. **Run the script as root**

   ```bash
   sudo ./kubesphere-kickstarter.sh
   ```

   The script will:
   - Check for root privileges
   - Install kubeadm, kubelet, and kubectl v1.29.13
   - Initialize the control plane with a Calico network (CIDR 192.168.0.0/16)
   - Deploy KubeSphere v4.1.3
   - Wait up to 10 minutes for all KubeSphere pods to be ready

4. **Verify installation**

   ```bash
   kubectl get nodes             # Check cluster nodes
   kubectl get pods -n kubesphere-system  # Check KubeSphere pods
   kubectl get svc -n kubesphere-system | grep kubesphere-console
   ```

5. **Access the KubeSphere Console**

   Forward the service port or expose via LoadBalancer/Ingress:

   ```bash
   kubectl port-forward -n kubesphere-system svc/kubesphere-console 30880:80
   ```

   Then open your browser at <http://localhost:30880>.

## Customization

- **Change Kubernetes version**: edit the `K8S_VERSION` variable in the script (must stay within v1.21–v1.30).
- **Use different network plugin**: replace the Calico manifest URL in the script (step 4).
- **Modify Pod CIDR**: adjust the `POD_NETWORK_CIDR` variable.

## Troubleshooting

- If the script fails to find packages, ensure the Google GPG key and APT repo were added correctly.
- Check logs of failing pods:

  ```bash
  kubectl -n kubesphere-system logs -l app=kubesphere-console
  ```

- For network issues, verify IP ranges and networking add-on status.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
