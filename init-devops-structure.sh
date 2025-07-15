#!/bin/bash

set -e

echo "Creating DevOps project structure..."

# Top-level directories
mkdir -p project-root/{manifests/{jenkins,monitoring},helm/my-app,helm/my-app/templates,tofu,scripts}

# Create placeholder files
touch project-root/Jenkinsfile

# Namespace manifest
cat > project-root/manifests/namespaces.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: infra
---
apiVersion: v1
kind: Namespace
metadata:
  name: apps
EOF

# Example jenkins deployment placeholder (only needed if deploying Jenkins in Kubernetes)
touch project-root/manifests/jenkins/jenkins-deployment.yaml
touch project-root/manifests/jenkins/jenkins-service.yaml

# Tofu files
touch project-root/tofu/{main.tf,variables.tf,outputs.tf}

# Helm chart template
touch project-root/helm/my-app/templates/deployment.yaml

# Example scripts
touch project-root/scripts/{deploy.sh,run-tests.sh}

echo "Done! Your project structure is ready under 'project-root/'"
