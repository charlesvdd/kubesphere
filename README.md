# 🚀 Installation Kubernetes 1.28.0 avec Containerd (préparation pour KubeSphere 4.x)

Ce script permet d’installer un cluster **Kubernetes 1.28.0** sur **Ubuntu 22.04 LTS**, avec `containerd` comme runtime et une configuration prête à recevoir **KubeSphere v4.1.3** (via Helm).

> 🔧 Branche : `Kubernetes/conteneraid/1.28.0`  
> 📄 Script principal : `setup-kubesphere.sh`

---

## 📋 Prérequis

- ✅ Ubuntu Server 22.04 LTS (recommandé sur un VPS avec **4 CPU / 8 Go RAM** minimum)
- ✅ Accès root (`sudo` autorisé)
- ✅ Port 6443 (K8s), 10250, 30000-32767 ouverts
- ✅ Connexion Internet active

---

## 📦 Contenu du script

Le script installe et configure automatiquement :

| Composant     | Version         | Description                          |
|---------------|-----------------|--------------------------------------|
| Kubernetes    | `1.28.0`        | Version stable recommandée           |
| containerd    | latest (via apt)| Runtime léger pour K8s               |
| kubeadm       | `1.28.0-00`     | Outil d'initialisation du cluster    |
| kubectl       | `1.28.0-00`     | CLI pour Kubernetes                  |
| kubelet       | `1.28.0-00`     | Agent sur chaque nœud                |
| CNI Flannel   | latest          | Réseau Pod (`10.244.0.0/16`)         |

⚙️ Auto-évaluation intégrée pour chaque étape avec codes couleur :
- 🟢 OK : étape réussie
- 🔴 ERREUR : arrêt immédiat avec log

---

## ▶️ Exécution

### 1. Cloner la branche

```bash
git clone -b Kubernetes/conteneraid/1.28.0 https://github.com/charlesvdd/kubesphere.git
cd kubesphere

2. Rendre le script exécutable
bash
Copier
Modifier
chmod +x setup-kubesphere.sh
3. Lancer le script
bash
Copier
Modifier
sudo ./setup-kubesphere.sh
🕒 L’installation prend 3 à 6 minutes.
