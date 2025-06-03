Kubernetes est un système open source conçu pour automatiser le déploiement, la mise à l'échelle et la gestion des applications conteneurisées. Il a été initialement développé par Google et est maintenant maintenu par la Cloud Native Computing Foundation. 

Kubernetes permet de gérer des clusters d'hôtes exécutant des conteneurs Docker, facilitant ainsi la gestion des applications distribuées et des microservices. Voici quelques caractéristiques clés de Kubernetes :

1. **Orchestration de conteneurs** : Kubernetes aide à orchestrer les conteneurs sur plusieurs hôtes, en s'assurant que les applications fonctionnent comme prévu.
2. **Mise à l'échelle automatique** : Il peut automatiquement mettre à l'échelle les applications en fonction de l'utilisation des ressources ou d'autres métriques.
3. **Auto-réparation** : Kubernetes redémarre les conteneurs qui échouent, remplace les conteneurs, tue les conteneurs qui ne répondent pas aux contrôles de santé définis par l'utilisateur, et ne les annonce pas aux clients tant qu'ils ne sont pas prêts à les servir.
4. **Gestion des services** : Il offre des mécanismes de découverte de services et d'équilibrage de charge pour les applications conteneurisées.
5. **Gestion des configurations et des secrets** : Kubernetes permet de gérer les configurations des applications et les informations sensibles de manière sécurisée.


KubeSphere, d'autre part, est une plateforme de gestion de conteneurs open source construite sur Kubernetes. Elle fournit une interface utilisateur graphique et un ensemble d'outils pour faciliter la gestion des clusters Kubernetes. Voici quelques caractéristiques de KubeSphere :

1. **Interface utilisateur intuitive** : KubeSphere offre une interface utilisateur graphique qui simplifie la gestion des ressources Kubernetes.
2. **Gestion multi-clusters** : Elle permet de gérer plusieurs clusters Kubernetes à partir d'une seule interface.
3. **Intégration d'outils DevOps** : KubeSphere intègre divers outils DevOps pour le CI/CD, la surveillance, la journalisation, et plus encore.
4. **Gestion des applications** : Elle fournit des outils pour le déploiement, la mise à l'échelle et la gestion des applications sur Kubernetes.
5. **Sécurité et gestion des accès** : KubeSphere offre des fonctionnalités avancées pour la gestion des accès et la sécurité des applications.
6. 

https://youtu.be/YxZ1YUv0CYs?si=QiiiDbkbYaFnuBpJ

Ensemble, Kubernetes et KubeSphere offrent une solution puissante pour la gestion des applications conteneurisées, rendant plus accessible la complexité de Kubernetes grâce à une interface utilisateur et des outils supplémentaires.

## Github distribution

[GitHub - kubesphere/kubesphere: The container platform tailored for Kubernetes multi-cloud, datacenter, and edge management ⎈ 🖥 ☁️](https://github.com/kubesphere/kubesphere)

### Fonctionnalités

1. **Orchestration de conteneurs** : Gestion automatisée du déploiement, de la mise à l'échelle et de l'exploitation des applications conteneurisées.
2. **Service Discovery et Load Balancing** : Kubernetes peut exposer un conteneur en utilisant le nom DNS ou sa propre adresse IP. S'il y a beaucoup de trafic, Kubernetes peut équilibrer la charge et distribuer le trafic réseau pour que le déploiement soit stable.
3. **Orchestration de stockage** : Montage automatique d'un système de stockage choisi, tel que des stockage locaux, des fournisseurs de cloud public, etc.
4. **Mise à l'échelle automatique** : Mise à l'échelle des applications en fonction de leur utilisation ou d'autres métriques.
5. **Auto-réparation** : Redémarrage des conteneurs défaillants, remplacement et destruction des conteneurs en cas de défaillance, et gestion des conteneurs en fonction des contrôles de santé définis par l'utilisateur.
6. **Gestion des configurations et des secrets** : Gestion des informations sensibles, telles que les mots de passe, les tokens OAuth, et les clés SSH.
7. **Gestion des déploiements et des rollbacks** : Kubernetes permet de déployer des modifications de manière progressive et de revenir en arrière en cas de problème.

### Avantages

- **Portabilité** : Fonctionne avec différents environnements cloud et sur site.
- **Extensibilité** : Peut être étendu avec une grande variété d'outils et de plugins.
- **Communauté et support** : Large communauté et support étendu de la part des principaux fournisseurs de cloud.
- **Efficacité des ressources** : Optimisation de l'utilisation des ressources grâce à l'orchestration intelligente des conteneurs.
- 
### Fonctionnalités

1. **Interface utilisateur graphique** : Interface intuitive pour la gestion des clusters Kubernetes.
2. **Gestion multi-clusters** : Capacité à gérer plusieurs clusters Kubernetes à partir d'une seule interface.
3. **Intégration DevOps** : Outils intégrés pour le CI/CD, la surveillance, la journalisation, et plus encore.
4. **Gestion des applications** : Outils pour le déploiement, la mise à l'échelle et la gestion des applications sur Kubernetes.
5. **Sécurité et gestion des accès** : Fonctionnalités avancées pour la gestion des accès et la sécurité des applications.
6. **Observabilité** : Tableaux de bord et outils de surveillance pour suivre l'état et les performances des applications et des clusters.
7. **Gestion des ressources** : Outils pour gérer les ressources de calcul, de stockage et de réseau.
