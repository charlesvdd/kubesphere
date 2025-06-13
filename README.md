# 🌐 KubeSphere Kubernetes Setup (Branch: containerd)

> Installation de Kubernetes 1.28.0 avec containerd (runtime officiel) + Kubeadm.

## ✅ Ce que fait ce script

- Installe `containerd` (runtime recommandé)
- Installe `kubeadm`, `kubelet`, `kubectl`
- Initialise un cluster Kubernetes en standalone
- Configure `Flannel` comme CNI
- Génère des logs dans `logs/install.log`

## ⚙️ Prérequis

- Un VPS avec Ubuntu 20.04 ou 22.04
- Accès root
- 4+ vCPU, 8+ Go RAM conseillés

## 🚀 Usage

```bash
cd /root/containerd

# Téléchargement depuis GitHub avec le bon nom
curl -O https://raw.githubusercontent.com/charlesvdd/kubesphere/containerd/containerd-install.sh

# Donne les droits et lance
chmod +x containerd-install.sh
./containerd-install.sh
