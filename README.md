# Install Kubernetes & KubeSphere on a Fresh Server

This guide provides a simple, all-in-one installation of Kubernetes using **MicroK8s** and **KubeSphere** 4.1.3 via Helm. It bypasses APT repository issues by using the Snap package for Kubernetes and the official Helm chart for KubeSphere.

---

## Prerequisites

* A fresh Ubuntu-based server (18.04, 20.04, or 22.04)
* `sudo` privileges
* Internet access
* Ports `8080`, `30880` (or custom) available for the KubeSphere console

---

## Components & Versions

| Component  | Version    | Install Method                       |
| ---------- | ---------- | ------------------------------------ |
| MicroK8s   | 1.29.15    | Snap (`--channel=1.29/stable`)       |
| Helm CLI   | Latest 3.x | Official install script              |
| KubeSphere | 4.1.3      | Helm chart `ks-core` (version 1.1.4) |

---

## Quickstart

1. **Clone this repository** and make the install script executable:

   ```bash
   git clone https://your-repo-url.git
   cd your-repo-url
   chmod +x install_kubesphere.sh
   ```

2. **Run the installer**:

   ```bash
   ./install_kubesphere.sh
   ```

3. **Access the KubeSphere console**:

   * Open your browser at `http://localhost:30880`
   * Login with:

     * **Username**: `admin`
     * **Password**: `P@88w0rd`
   * Remember to change the default password on first login.

---

## Script Explanation

1. **MicroK8s Installation**: Uses a single Snap package to install Kubernetes v1.29.15, including essential addons (DNS, storage, ingress, RBAC).
2. **Helm Installation**: Installs Helm CLI v3 for package management.
3. **KubeSphere Deployment**: Adds the `kubesphere` Helm repo and deploys the `ks-core` chart (v1.1.4) in the `kubesphere-system` namespace, waiting until all pods are running.
4. **Console Access**: Sets up port-forwarding from local port `30880` to the `ks-console` service on the cluster.

---

## Customization

* **Enable additional MicroK8s addons** by editing the `microk8s enable` line in the script (e.g., `metrics-server`, `dashboard`).
* **Change ports** by modifying the `port-forward` command.
* **Chart values**: Pass `--set key=value` flags to `helm install` to customize KubeSphere settings.

---

## Troubleshooting

* If the node never reaches `Ready`, check `microk8s status --wait-ready` and inspect system resources.
* For Helm errors, run `helm repo update` and `helm uninstall kubesphere -n kubesphere-system` to retry.
* Consult the official docs:

  * [MicroK8s Documentation](https://microk8s.io/docs)
  * [KubeSphere Helm Charts](https://charts.kubesphere.io/main)

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
