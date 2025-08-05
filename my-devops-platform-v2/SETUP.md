# DevOps Platform Setup Guide

This document outlines an integrated, professional workflow for setting up a local DevOps platform.
**Architecture:**
1.  **Minikube:** Acts as our local cloud provider, creating a bare Kubernetes cluster.
2.  **OpenTofu:** Provisions and manages all infrastructure resources inside Kubernetes, including namespaces and Helm chart releases for our applications.
3.  **Helm:** The package format used by OpenTofu to install applications.
4.  **Jenkins:** Runs a "seed job" to automatically generate CI/CD pipelines for applications.

---

## 1. Initial Infrastructure Setup

### 1.1. Start the Kubernetes Cluster

This is the only manual step to create the base infrastructure.

```bash
minikube start
```

### 1.2. Create Project Directory

All platform configuration code will be stored here.

```bash
mkdir my-devops-platform
cd my-devops-platform
```

### 1.3. Define Jenkins Helm Configuration

This step must be done **before** running `tofu apply`. Create the directory and the `helm/values/jenkins-values.yaml` file in your `my-devops-platform` project.

```bash
mkdir -p helm/values
```

Now create the `helm/values/jenkins-values.yaml` file with the following content:
```yaml
# helm/values/jenkins-values.yaml
controller:
  installPlugins:
    - kubernetes
    - workflow-aggregator
    - git
    - configuration-as-code
    # Add this plugin for the seed job
    - job-dsl
  persistence:
    enabled: true
    storageClass: "standard"
    size: "8Gi"

agent:
  kubernetes:
    name: kubernetes
    namespace: infra
    jenkinsUrl: [http://jenkins.infra.svc.cluster.local:8080](http://jenkins.infra.svc.cluster.local:8080)
    credentialsId: kubernetes-jenkins-agent
    podTemplates:
      maven-agent:
        label: jenkins-maven-agent
        namespace: apps
        volumes:
        - hostPathVolume:
            path: /var/run/docker.sock
            hostPathType: ""
            name: docker-sock
        containers:
        - name: jnlp
          image: jenkins/inbound-agent:latest-jdk17
          workingDir: /home/jenkins/agent
          alwaysPullImage: true
        - name: maven
          image: maven:3.9.6-eclipse-temurin-17
          command: cat
          ttyEnabled: true
          alwaysPullImage: true
        - name: docker
          image: docker:20.10.17
          command: cat
          ttyEnabled: true
          alwaysPullImage: true
          volumeMounts:
          - mountPath: /var/run/docker.sock
            name: docker-sock
            readOnly: false
        - name: helm
          image: alpine/helm:3.9.0
          command: cat
          ttyEnabled: true
          alwaysPullImage: true
```

### 1.4. Define All Infrastructure Resources in OpenTofu

Now, create the `main.tf` file in your project root. It will define our namespaces and application installations, and it can now correctly reference the `jenkins-values.yaml` file you just created.

```hcl
# main.tf

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }
  }
}

# Configure the Kubernetes provider to talk to our running Minikube cluster.
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# Configure the Helm provider to use the same Kubernetes context.
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

# --- Base Namespaces ---
resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
  }
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

# --- Helm Releases (Application Installations) ---

# Install Prometheus using the helm_release resource.
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "[https://prometheus-community.github.io/helm-charts](https://prometheus-community.github.io/helm-charts)"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  # Ensure the namespace exists before trying to install.
  depends_on = [kubernetes_namespace.infra]
}

# Install Jenkins using the helm_release resource.
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "[https://charts.jenkins.io](https://charts.jenkins.io)"
  chart      = "jenkins"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  # Load the configuration from our values file.
  values = [
    file("${path.module}/helm/values/jenkins-values.yaml")
  ]

  # Ensure the namespace exists first.
  depends_on = [kubernetes_namespace.infra]
}
```

### 1.5. Provision All Infrastructure with OpenTofu

Now, a single command will set up our namespaces AND install Prometheus and Jenkins.

```bash
# Initialize the OpenTofu providers
tofu init

# Apply the configuration to create all resources
tofu apply --auto-approve
```

**Verification:** Check that the namespaces and all pods in the `infra` namespace are created and running. This may take a few minutes.

```bash
kubectl get namespaces
kubectl get pods --namespace infra --watch
```

---

## 2. Access and Configure Jenkins

### 2.1. Access Jenkins UI & Get Admin Password

1.  **Forward the port to access the UI.** In a dedicated terminal, run:
    ```bash
    kubectl port-forward svc/jenkins 8080:8080 -n infra
    ```
2.  **Get the auto-generated admin password.** In another terminal, run:
    ```bash
    kubectl get secret jenkins -n infra -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
    ```
3.  Open a web browser to `http://localhost:8080`. Log in with the username `admin` and the password you just retrieved.

### 2.2. Create Kubernetes Service Account for Jenkins

This step gives Jenkins the permissions it needs to deploy applications. Create `kubernetes/jenkins-sa/service-account.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-agent
  namespace: apps
```

And `kubernetes/jenkins-sa/role-binding.yaml`:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-agent-role
  namespace: apps
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-agent-rolebinding
  namespace: apps
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins-agent-role
subjects:
- kind: ServiceAccount
  name: jenkins-agent
  namespace: apps
```

Apply them:
```bash
kubectl apply -f kubernetes/jenkins-sa/
```

### 2.3. Add Kubernetes Credentials to Jenkins

1. Go to your Jenkins UI.
2. Navigate to **Manage Jenkins** > **Credentials**.
3. Click **(global)** domain, then **Add Credentials**.
4. Fill out the form:
   * **Kind**: `Kubernetes Service Account`.
   * **ID**: `kubernetes-jenkins-agent`.
   * **Description**: `Service account to deploy to the apps namespace`.
5. Click **OK**.

---

## 3. Define the Platform's Automation Logic

### 3.1. Create a Generic Application Helm Chart

In your `my-devops-platform` repository, create a reusable Helm chart for deploying applications.

```bash
helm create helm/charts/generic-app
```

Add Prometheus annotations to `helm/charts/generic-app/values.yaml`:
```yaml
# ...
service:
  type: ClusterIP
  port: 8080
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
# ...
```

### 3.2. Create the Job DSL Script

This script generates the `build` and `deploy` pipelines. In your `my-devops-platform` repo, create `dsl/seed.groovy`:

```groovy
// dsl/seed.groovy
def repoUrl = binding.getVariable('REPO_URL')
def repoName = repoUrl.tokenize('/').last().tokenize('.').first()
def platformRepoUrl = '[https://github.com/your-username/my-devops-platform.git](https://github.com/your-username/my-devops-platform.git)' // <-- IMPORTANT: CHANGE THIS

folder(repoName) {
    description("Pipelines for ${repoName}")
}

// --- Generate the BUILD job ---
pipelineJob("${repoName}/build-${repoName}") {
    description("Builds and creates a Docker image for ${repoName}")
    definition {
        cps {
            script("""
                pipeline {
                    agent { label 'jenkins-maven-agent' }
                    environment {
                        DOCKER_REGISTRY = "localhost:5000"
                        IMAGE_NAME = "${repoName}"
                    }
                    stages {
                        stage('Checkout Code') { steps { git branch: 'main', url: '${repoUrl}' } }
                        stage('Run Build & Tests') {
                            steps {
                                container('maven') { sh 'if [ -f mvnw ]; then ./mvnw clean install; else mvn clean install; fi' }
                            }
                        }
                        stage('Build and Push Docker Image') {
                            steps {
                                container('docker') {
                                    sh "docker build -t \${IMAGE_NAME}:\${BUILD_ID} ."
                                    sh "docker tag \${IMAGE_NAME}:\${BUILD_ID} \${DOCKER_REGISTRY}/\${IMAGE_NAME}:\${BUILD_ID}"
                                    sh "docker push \${DOCKER_REGISTRY}/\${IMAGE_NAME}:\${BUILD_ID}"
                                }
                            }
                        }
                    }
                }
            """.stripIndent())
            sandbox()
        }
    }
}

// --- Generate the DEPLOY job ---
pipelineJob("${repoName}/deploy-${repoName}") {
    description("Deploys a specific version of ${repoName}")
    parameters { stringParam('IMAGE_TAG', '', 'The Docker image tag (build number) to deploy') }
    definition {
        cps {
            script("""
                pipeline {
                    agent { label 'jenkins-maven-agent' }
                    environment {
                        HELM_CHART_PATH = "helm/charts/generic-app"
                        HELM_RELEASE_NAME = "${repoName}"
                        DOCKER_REGISTRY = "localhost:5000"
                        IMAGE_NAME = "${repoName}"
                    }
                    stages {
                        stage('Deploy to Kubernetes') {
                            steps {
                                container('helm') {
                                    git url: '${platformRepoUrl}', branch: 'main'
                                    sh 'helm upgrade --install \${HELM_RELEASE_NAME} ./\${HELM_CHART_PATH} --namespace apps --set image.repository="\${DOCKER_REGISTRY}/\${IMAGE_NAME}" --set image.tag="\${params.IMAGE_TAG}" --set image.pullPolicy=Always'
                                }
                            }
                        }
                    }
                }
            """.stripIndent())
            sandbox()
        }
    }
}
```

---

## 4. Create the Seed Job and Onboard an Application

### 4.1. Enable the Minikube Docker Registry

The DSL script pushes images to Minikube's internal registry. Enable it:
```bash
minikube addons enable registry
```

### 4.2. Create the Seed Job in Jenkins

1.  Go to your Jenkins UI.
2.  Click **New Item** > `seed-job` > **Freestyle project** > **OK**.
3.  **Configure the Seed Job:**
    * Check **This project is parameterized**.
    * **Add Parameter** > **String Parameter**.
        * Name: `REPO_URL`
        * Description: `The Git URL of the application to onboard (e.g., https://github.com/marlonpg/sample-java-api.git)`
    * **Source Code Management** > **Git**.
        * Repository URL: Enter the URL to *your* `my-devops-platform` repository. **(Commit and push your changes first!)**
    * **Build Steps** > **Add build step** > **Process Job DSLs**.
        * Select **Look on Filesystem**.
        * DSL Scripts: `dsl/seed.groovy`.
    * Click **Save**.

### 4.3. Onboard the Application

1.  Run the `seed-job` with the `REPO_URL` parameter pointing to your Java application's repository.
2.  A new folder `sample-java-api` will be created with `build` and `deploy` jobs.
3.  Run the `build` job. Note the build number (e.g., `#1`).
4.  Run the `deploy` job with the `IMAGE_TAG` parameter set to the build number.

---

## 5. Automated Testing for OpenTofu Code

To meet the requirement for testing infrastructure code, we will create a CI pipeline for our OpenTofu files.

1.  **Add a `tofu` container to your `helm/values/jenkins-values.yaml`** inside the `maven-agent` pod template:
    ```yaml
        # ... inside containers list ...
        - name: tofu
          image: ghcr.io/opentofu/opentofu:1.6.0
          command: cat
          ttyEnabled: true
          alwaysPullImage: true
    ```
2.  **Run `tofu apply` again** to apply the configuration change to your Jenkins Helm release.
3.  **Create a `Jenkinsfile` in the root of your `my-devops-platform` repository:**
    ```groovy
    // Jenkinsfile for the platform repository
    pipeline {
        agent { label 'jenkins-maven-agent' }

        stages {
            stage('Validate OpenTofu Code') {
                steps {
                    // Use the new tofu container
                    container('tofu') {
                        // Standard CI steps for Terraform/OpenTofu
                        sh 'tofu init -backend=false'
                        sh 'tofu validate'
                        sh 'tofu plan'
                    }
                }
            }
        }
    }
    ```
4.  **Create an Organization Folder in Jenkins**, pointing it at your GitHub username/organization. It will now automatically discover your `my-devops-platform` repository and create a CI job that runs these Tofu checks on every commit.
