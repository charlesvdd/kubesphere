# 🚀 Installation Kubernetes 1.28 avec containerd (prêt pour KubeSphere 4.x)

Ce dépôt contient un script automatisé pour installer **Kubernetes v1.28.0** sur **Ubuntu 22.04 LTS**, en utilisant **containerd** comme runtime, avec toutes les bonnes pratiques pour préparer l'installation de **KubeSphere 4.1.3** via Helm.

---

## 📄 Fichier principal

- `setup-kubesphere.sh` → installe Kubernetes, configure containerd, installe Flannel et prépare le cluster

---

## ✅ Ce que fait le script

| Étape                         | Détails                                                                 |
|------------------------------|-------------------------------------------------------------------------|
| ✅ Vérifie l'exécution en root | Refuse de s'exécuter en tant qu'utilisateur non root                   |
| ✅ Installe containerd        | Avec configuration `SystemdCgroup = true`                              |
| ✅ Configure Kubernetes       | Dépôt officiel v1.28 + kubeadm, kubelet, kubectl en version figée      |
| ✅ Initialise le cluster      | Via `kubeadm init` avec pod CIDR `10.244.0.0/16` pour compatibilité CNI |
| ✅ Installe CNI Flannel       | Compatible avec le pod CIDR utilisé                                    |
| ✅ Configure `kubectl`        | Copie automatique du `kubeconfig` pour l'utilisateur                   |
| ✅ Vérifie l’état du nœud     | Boucle jusqu’à ce que le nœud soit `Ready`                             |

---

## ▶️ Lancer l'installation

### 1. Cloner la branche

```bash
git clone -b Kubernetes/conteneraid/1.28.0 https://github.com/charlesvdd/kubesphere.git
cd kubesphere
