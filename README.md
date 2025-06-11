## Install Kubernetes & KubeSphere on a Fresh Server

This guide provides a simple, all-in-one installation of Kubernetes using MicroK8s and KubeSphere 4.1.3 via Helm. It bypasses APT repository issues by using the Snap package for Kubernetes and the official Helm chart for KubeSphere.

---

### Prerequisites

* A fresh Ubuntu-based server (18.04, 20.04, or 22.04)
* **sudo** privileges
* Internet access
* Ports **8080**, **30880** (or custom) available for the KubeSphere console

---

### Components & Versions

| Component  | Version    | Install Method                       |
| ---------- | ---------- | ------------------------------------ |
| MicroK8s   | 1.29.15    | Snap (`--channel=1.29/stable`)       |
| Helm CLI   | Latest 3.x | Official install script              |
| KubeSphere | 4.1.3      | Helm chart `ks-core` (version 1.1.4) |

---

### Quickstart

1. **Clone this repository** (or pull the correct branch if it already exists):

   ```bash
   git clone https://github.com/charlesvdd/kubesphere.git || cd kubesphere && git pull origin master
   ```

2. **Enter the directory and make the install script executable**:

   ```bash
   cd kubesphere
   chmod +x kubesphere-kickstarter.sh
   ```

3. **Run the installer** (use Bash to ensure the correct interpreter):

   ```bash
   bash kubesphere-kickstarter.sh
   ```

4. **Access the KubeSphere console**:

   * Open your browser at `http://<server-ip>:30880`
   * Login with:

     ```text
     Username: admin
     Password: P@88w0rd
     ```
   * **Tip:** Change the default password on first login.

---

### Script Explanation

* **MicroK8s Installation**: Uses a single Snap package to install Kubernetes v1.29.15, including essential addons (DNS, storage, ingress, RBAC).
* **Helm Installation**: Installs Helm CLI v3 for package management.
* **KubeSphere Deployment**: Adds the KubeSphere Helm repo and deploys the `ks-core` chart (v1.1.4) in the `kubesphere-system` namespace, waiting until all pods are running.
* **Console Access**: Sets up port-forwarding from local port 30880 to the `ks-console` service on the cluster.

---

### Customization

* **Additional MicroK8s addons**: Enable more addons by editing the `microk8s enable` line in the script (e.g., `metrics-server`, `dashboard`).
* **Ports**: Change ports by modifying the port-forward command in the script.
* **Chart values**: Pass `--set key=value` flags to `helm install` to customize KubeSphere settings.

---

### Troubleshooting

* **Node not Ready**: Check `microk8s status --wait-ready` and inspect system resources.
* **Helm errors**: Run `helm repo update` and `helm uninstall kubesphere -n kubesphere-system` to retry.
* **DNS issues**: Verify network/DNS settings if `Could not resolve host` appears.

**Useful links**:

* [MicroK8s Documentation](https://microk8s.io/docs)
* [KubeSphere Helm Charts](https://github.com/kubesphere/helm-charts)

---

### License

This project is licensed under the MIT License. See `LICENSE` for details.
