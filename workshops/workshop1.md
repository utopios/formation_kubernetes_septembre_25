## Atelier 1

Sujet :
Vous venez de créer un cluster Kubernetes. Votre mission est de prendre en main `kubectl` et de déployer un premier Pod.

Travail attendu :

1. Créez un namespace `lab`.
2. Déployez un Pod **Ghost Blog** (`ghost:5-alpine`) dans ce namespace.
3. Vérifiez son état (`kubectl get pods`, `describe`).
4. Testez l’accès local avec `kubectl port-forward`.
