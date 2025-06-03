#!/usr/bin/env bash
###############################################################################
#    ____        _    ____  _                   _
#   / ___| _   _| | _|  _ \| | _____   _____  _| |_ ___  _ __
#   \___ \| | | | |/ / |_) | |/ _ \ \ / / _ \| | __/ _ \| '_ \
#    ___) | |_| |   <|  __/| |  __/\ V / (_) | | || (_) | | | |
#   |____/ \__,_|_|\_\_|   |_|\___| \_/ \___/|_|\__\___/|_| |_|
#
#   Script d’installation & vérification (avec Snap + kubeadm init)
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
kubeadm version         # Exemple : "kubeadm version: v1.24.x"
kubelet --version       # Exemple : "Client Version: v1.24.x"
kubectl version --client  # Exemple : "Client Version: v1.24.x"
success "kubeadm, kubelet, kubectl sont opératoires."

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

# ─── BLOC INIT CLUSTER ─────────────────────────────────────────────────────────
header "INITIALISATION DU CLUSTER KUBERNETES"

# 1) Désactiver le swap (Kubernetes l'exige)
info "Désactivation du swap (temporaire)…"
sudo swapoff -a

# 2) Initialiser le master avec kubeadm
info "Initialisation du nœud master (kubeadm init)…"
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket /run/containerd/containerd.sock

# 3) Configurer kubectl pour root
info "Configuration de kubectl pour l'utilisateur root…"
sudo mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config
sudo chown root:root /root/.kube/config
sudo chmod 600 /root/.kube/config
success "kubectl configuré pour root."

# 4) Déployer le CNI (Calico recommandé en production)
info "Déploiement du CNI Calico…"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
success "Manifest Calico appliqué."

# 5) Vérifier que le master passe en Ready
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
