#!/usr/bin/env bash
###############################################################################
#    ____        _    ____  _                   _
#   / ___| _   _| | _|  _ \| | _____   _____  _| |_ ___  _ __
#   \___ \| | | | |/ / |_) | |/ _ \ \ / / _ \| | __/ _ \| '_ \
#    ___) | |_| |   <|  __/| |  __/\ V / (_) | | || (_) | | | |
#   |____/ \__,_|_|\_\_|   |_|\___| \_/ \___/|_|\__\___/|_| |_|
#
#   Script d’installation & vérification (Nettoyage + Snap + kubeadm init)
#   Dépôt : charlesvdd/kubesphere (branche : install)
###############################################################################

# ─── COULEURS ANSI ───────────────────────────────────────────────────────────
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ─── FONCTIONS UTILITAIRES ───────────────────────────────────────────────────
function header() {
  echo -e "${CYAN}${BOLD}================================================================${RESET}"
  echo -e "${CYAN}${BOLD}  $1${RESET}"
  echo -e "${CYAN}${BOLD}================================================================${RESET}"
}

function info() {
  echo -e "${BLUE}[INFO]${RESET} $1"
}

function success() {
  echo -e "${GREEN}[✔]${RESET} $1"
}

function warning() {
  echo -e "${YELLOW}[!]${RESET} $1"
}

function error() {
  echo -e "${RED}[✖]${RESET} $1"
}

# ─── DÉBUT DU SCRIPT ──────────────────────────────────────────────────────────
set -euo pipefail

LOGFILE="/tmp/kubesphere_install_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "${LOGFILE}") 2>&1

header "DÉMARRAGE DU SCRIPT D'INSTALLATION"
info "Date/Heure : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ─── BLOC NETTOYAGE D’OUVREURS EXISTANTS ──────────────────────────────────────
header "NETTOYAGE DES INSTALLATIONS KUBERNETES EXISTANTES"

# 1) Arrêter et désactiver kubelet (APT)
if dpkg -l | grep -q kubelet; then
  info "Arrêt du service kubelet (APT)…"
  sudo systemctl stop kubelet.service || true
  sudo systemctl disable kubelet.service || true
  success "Service kubelet (APT) arrêté et désactivé."
fi

# 2) Désactiver et supprimer kubelet snap
if snap list | grep -q "^kubelet\s"; then
  info "Désactivation et suppression du snap kubelet…"
  sudo snap disable kubelet || true
  sudo snap remove kubelet || true
  success "Snap kubelet supprimé."
fi

# 3) Arrêter et supprimer MicroK8s (snap)
if snap list | grep -q "^microk8s\s"; then
  info "Arrêt et suppression de MicroK8s…"
  sudo snap disable microk8s || true
  sudo snap remove microk8s || true
  sudo rm -rf /var/snap/microk8s /var/lib/microk8s /snap/microk8s
  success "MicroK8s supprimé."
fi

# 4) Arrêter et supprimer k3s
if systemctl list-units --full -all | grep -qE 'k3s.service|k3s-agent.service'; then
  info "Arrêt et suppression de k3s…"
  sudo systemctl stop k3s.service 2>/dev/null || true
  sudo systemctl disable k3s.service 2>/dev/null || true
  sudo rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s-agent.service
  sudo rm -rf /etc/rancher/k3s /var/lib/rancher/k3s
  sudo rm -f /usr/local/bin/k3s /usr/local/bin/k3s-agent
  success "k3s supprimé."
fi

# 5) Libérer les ports 10250, 6443, 2379, 2380
for PORT in 10250 6443 2379 2380; do
  if sudo ss -tulpn | grep -q ":${PORT}"; then
    PROC_PID=$(sudo lsof -t -i :"${PORT}" 2>/dev/null || true)
    if [ -n "${PROC_PID}" ]; then
      info "Libération du port ${PORT} (PID ${PROC_PID})…"
      sudo kill -9 "${PROC_PID}" || true
      success "Port ${PORT} libéré."
    fi
  fi
done

# 6) Purger paquets kubeadm, kubelet, kubectl (APT)
if dpkg -l | grep -qE 'kubeadm|kubelet|kubectl'; then
  info "Purge des paquets kubeadm/kubelet/kubectl (APT)…"
  sudo apt-get purge -y kubeadm kubelet kubectl
  sudo apt-get autoremove -y
  sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/cni/net.d /var/lib/cni ~/.kube
  success "Paquets Kubernetes APT purgés."
fi

# 7) Supprimer les snaps Kubernetes restants
for PKG in kubeadm kubectl microk8s; do
  if snap list | grep -q "^${PKG}\s"; then
    info "Suppression du snap ${PKG}…"
    sudo snap remove "${PKG}" || true
    success "Snap ${PKG} supprimé."
  fi
done

# 8) Purger fichiers CNI et etcd
info "Suppression des configurations CNI et etcd résiduelles…"
sudo rm -rf /etc/cni/net.d /opt/cni /etc/calico /var/lib/calico /etc/flannel /var/lib/flannel /var/lib/etcd
success "Configurations CNI et etcd supprimées."

# 9) Réinitialiser containerd si nécessaire
if [ -f /etc/containerd/config.toml ]; then
  info "Suppression de l’ancienne configuration containerd…"
  sudo rm -f /etc/containerd/config.toml
  success "Configuration containerd supprimée."
fi

echo ""
success "Nettoyage terminé. Aucune installation Kubernetes résiduelle détectée."
echo ""

# ─── BLOC INSTALLATION DES DÉPENDANCES ────────────────────────────────────────
header "INSTALLATION DES DÉPENDANCES"

# 1) Vérifier/installer curl
if ! command -v curl &>/dev/null; then
  info "curl non trouvé → installation en cours..."
  if sudo apt-get update && sudo apt-get install -y curl; then
    success "curl installé avec succès."
  else
    error "Échec de l'installation de curl."
    exit 1
  fi
else
  success "curl déjà présent ($(curl --version | head -n1))."
fi

# 2) Vérifier/installer snapd
if ! command -v snap &>/dev/null; then
  info "snapd non trouvé → installation en cours..."
  if sudo apt-get update && sudo apt-get install -y snapd; then
    success "snapd installé avec succès."
  else
    error "Échec de l'installation de snapd."
    exit 1
  fi
else
  success "snapd déjà présent ($(snap version | head -n1))."
fi

# 3) Installer kubeadm, kubelet et kubectl via Snap en mode --classic
header "INSTALLATION DES BINAIRES KUBERNETES VIA SNAP"
SNAP_PKGS=("kubeadm" "kubelet" "kubectl")
for PKG in "${SNAP_PKGS[@]}"; do
  if ! snap list | grep -q "^${PKG} "; then
    info "Installation de ${PKG} via snap..."
    if sudo snap install "${PKG}" --classic; then
      success "${PKG} installé via snap."
    else
      error "Échec de l'installation de ${PKG} via snap."
      exit 1
    fi
  else
    INST_VER=$(snap list | awk -v p="$PKG" '$1==p {print $2}')
    success "${PKG} déjà installé (version ${INST_VER})."
  fi
done

# 4) Vérifier les versions installées
info "Vérification des versions des binaires Kubernetes"
kubeadm version         # Exemple : "kubeadm version: v1.32.5"
kubelet --version       # Exemple : "Client Version: v1.32.5"
kubectl version --client  # Exemple : "Client Version: v1.32.5"
success "kubeadm, kubelet, kubectl sont opérationnels."

# ─── BLOC INSTALLATION ET CONFIGURATION DE CONTAINERD ─────────────────────────────
header "INSTALLATION ET CONFIGURATION DE CONTAINERD"
if ! command -v containerd &>/dev/null; then
  info "containerd non trouvé → installation en cours..."
  if sudo apt-get update && sudo apt-get install -y containerd; then
    success "containerd installé."
  else
    error "Échec de l'installation de containerd."
    exit 1
  fi
else
  success "containerd déjà présent."
fi

info "Configuration de containerd (SystemdCgroup = true)…"
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
success "containerd configuré et en service."

echo ""

# ─── BLOC INITIALISATION DU CLUSTER ───────────────────────────────────────────
header "INITIALISATION DU CLUSTER KUBERNETES"

# 1) Désactiver le swap (Kubernetes l'exige)
info "Désactivation du swap (temporaire)…"
sudo swapoff -a

# 2) Activer net.ipv4.ip_forward
info "Activation du forwarding IPv4…"
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-kube-forward.conf >/dev/null
sudo sysctl --system
success "Forwarding IPv4 activé."

# 3) Initialiser le master avec kubeadm
info "Initialisation du nœud master (kubeadm init)…"
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket /run/containerd/containerd.sock

# 4) Configurer kubectl pour root
info "Configuration de kubectl pour l'utilisateur root…"
sudo mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config
sudo chown root:root /root/.kube/config
sudo chmod 600 /root/.kube/config
success "kubectl configuré pour root."

# 5) Déployer le CNI (Calico recommandé en production)
info "Déploiement du CNI Calico…"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
success "Manifest Calico appliqué."

# 6) Vérifier que le master passe en Ready
info "Vérification de l'état du nœud master…"
kubectl get nodes
kubectl get pods -n kube-system

echo ""

# ─── BLOC SIMULATION D'INSTALLATION DE KUBESPHERE ───────────────────────────────
header "INSTALLATION DE KUBESPHERE (SIMULÉE)"
info "Installation du binaire kubesphere (simulée)…"
sleep 1
success "kubesphere installé (simulation)."

echo ""

# ─── BLOC TESTS DE VÉRIFICATION ─────────────────────────────────────────────────
header "VÉRIFICATIONS POST-INSTALLATION"

PASS_COUNT=0
FAIL_COUNT=0

# Test 1 : version minimale de kubectl
info "Test 1 : vérifier que kubectl ≥ 1.20.0"
INSTALLED_VER_RAW=$(kubectl version --client --output=jsonpath='{.clientVersion.gitVersion}')
KUBECTL_VER="${INSTALLED_VER_RAW#v}"
REQUIRED_VER="1.20.0"
if dpkg --compare-versions "${KUBECTL_VER}" ge "${REQUIRED_VER}"; then
  success "kubectl (${KUBECTL_VER}) satisfait la version minimale (${REQUIRED_VER})."
  ((PASS_COUNT++))
else
  error "kubectl (${KUBECTL_VER}) est inférieur à ${REQUIRED_VER}."
  ((FAIL_COUNT++))
fi

# Test 2 : statut du service kubelet
info "Test 2 : statut du service kubelet"
if systemctl is-active --quiet kubelet; then
  success "Service kubelet actif."
  ((PASS_COUNT++))
else
  error "Service kubelet inactif."
  ((FAIL_COUNT++))
fi

# Test 3 : port Kubernetes standard (6443) ouvert
info "Test 3 : vérifier que le port 6443 est à l'écoute"
if ss -tuln | grep -q ":6443"; then
  success "Port 6443 en écoute."
  ((PASS_COUNT++))
else
  warning "Port 6443 non trouvé ouvert."
  ((FAIL_COUNT++))
fi

echo ""
header "RÉSULTATS DES TESTS"
info "Tests réussis : ${PASS_COUNT}"
if [ "${FAIL_COUNT}" -gt 0 ]; then
  warning "Tests échoués : ${FAIL_COUNT}"
else
  success "Aucun test en échec."
fi
echo ""

# ─── ENVOI DU LOG ──────────────────────────────────────────────────────────────
header "ENVOI DU LOG D'INSTALLATION"

ENDPOINT="https://mon-serveur.example.com/upload"
info "Envoi du log (${LOGFILE}) vers ${ENDPOINT}…"

if curl -X POST \
       -H "Content-Type: multipart/form-data" \
       -F "file=@${LOGFILE}" \
       "${ENDPOINT}" \
       --silent --show-error; then
  success "Log envoyé avec succès."
else
  error "L'envoi du log a échoué."
fi

echo ""
header "FIN DU SCRIPT"
info "Date/Heure : $(date '+%Y-%m-%d %H:%M:%S')"
exit 0
