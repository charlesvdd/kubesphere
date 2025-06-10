#!/usr/bin/env bash
# install_kubesphere.sh
# Script d’installation de MicroK8s (v1.29.15) et KubeSphere 4.1.3 via Helm (chart ks-core v1.1.4)

set -euo pipefail

echo "🔄 1. Installation de MicroK8s via Snap (v1.29.15)…"
sudo snap install microk8s --classic --channel=1.29/stable

echo "🔄 Ajout de l’utilisateur courant au groupe 'microk8s'…"
sudo usermod -aG microk8s "$USER"
echo "   ⚠️ Vous devrez vous déconnecter/reconnecter pour que les droits prennent effet."

echo "🔄 Configuration de kubeconfig…"
sudo microk8s config > ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config

echo "🔄 Activation des modules MicroK8s essentiels (dns, storage, ingress, rbac)…"
microk8s enable dns storage ingress rbac

echo "⏳ Attente que le nœud soit Ready…"
until microk8s kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  echo "   …en attente"
  sleep 5
done
echo "✅ MicroK8s est opérationnel."

echo "🔄 2. Installation de Helm 3…"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "🔄 3. Déploiement de KubeSphere 4.1.3 via Helm chart ks-core v1.1.4…"
NAMESPACE="kubesphere-system"
RELEASE="kubesphere"
CHART="ks-core"
VERSION="1.1.4"

microk8s kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | microk8s kubectl apply -f -

helm repo add kubesphere https://charts.kubesphere.io/main
helm repo update

helm install "$RELEASE" kubesphere/"$CHART" \
  --namespace "$NAMESPACE" \
  --version "$VERSION" \
  --wait

echo "✅ KubeSphere 4.1.3 est déployé."

echo "🔄 4. Port-forward pour accéder à la console KubeSphere…"
microk8s kubectl -n "$NAMESPACE" port-forward svc/ks-console 30880:80 &

echo -e "\n✅ Port-forward établi : http://localhost:30880"
echo "   Connexion → admin / P@88w0rd (pensez à changer le mot de passe)."
echo "🎉 Installation terminée !"
