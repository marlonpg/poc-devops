# DevOps Platform Setup Guide

This document outlines the step-by-step commands to set up a local DevOps platform using Minikube, Helm, Prometheus, Grafana, and Jenkins with a centralized Seed Job architecture.

## 1. Initial Setup

### 1.1. Create Project Directory

All configuration files will be stored here.

```bash
mkdir my-devops-platform
cd my-devops-platform
```

### 1.2. Create Kubernetes Namespaces

Logically separate infrastructure components from deployed applications.

```bash
# Create the 'infra' namespace for tools like Jenkins, Prometheus, etc.
kubectl create namespace infra

# Create the 'apps' namespace for your applications
kubectl create namespace apps

# Verify that the namespaces were created
kubectl get namespaces
```

## 2. Monitoring Stack: Prometheus & Grafana

### 2.1. Add Helm Repository

Add the community repository that contains the monitoring stack chart.

```bash
helm repo add prometheus-community [https://prometheus-community.github.io/helm-charts](https://prometheus-community.github.io/helm-charts)
helm repo update
```

### 2.2. Install the Chart

Install the `kube-prometheus-stack` chart, which bundles Prometheus, Grafana, and other necessary components into the `infra` namespace.

```bash
helm install prometheus prometheus-community/kube-prometheus-stack --namespace infra
```

### 2.3. Verify the Installation

Check the status of the pods. Wait until they are all in the `Running` state.

```bash
# Watch the status in real-time
kubectl get pods --namespace infra --watch
```

### 2.4. Access Grafana & Prometheus

Use `kubectl port-forward` to access the web UIs from your local machine. **Each command requires its own terminal window.**

**Access Grafana:**

```bash
# 1. Get the admin password
kubectl get secret --namespace infra prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# 2. Forward the port
kubectl port-forward --namespace infra svc/prometheus-grafana 3000:80

# 3. Open http://localhost:3000 in your browser (user: admin)
```

**Access Prometheus:**

```bash
# 1. Forward the port in a new terminal
kubectl port-forward --namespace infra svc/prometheus-kube-prometheus-prometheus 9090:9090

# 2. Open http://localhost:9090 in your browser
```

## 3. CI/CD Server: Jenkins

### 3.1. Update Jenkins Helm Values File

Update your `helm/values/jenkins-values.yaml` file to add the **Job DSL** plugin, which is essential for our seed job approach.

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
        # Add volume for Docker socket
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
        # Add container with Docker client
        - name: docker
          image: docker:20.10.17
          command: cat
          ttyEnabled: true
          alwaysPullImage: true
          # Mount the docker socket volume
          volumeMounts:
          - mountPath: /var/run/docker.sock
            name: docker-sock
            readOnly: false
        # Add container with Helm client
        - name: helm
          image: alpine/helm:3.9.0
          command: cat
          ttyEnabled: true
          alwaysPullImage: true
```

### 3.2. Add Jenkins Helm Repository

(If you haven't already done this)

```bash
helm repo add jenkins [https://charts.jenkins.io](https://charts.jenkins.io)
helm repo update
```

### 3.3. Upgrade Jenkins

Apply the new plugin configuration by running `helm upgrade`.

```bash
helm upgrade jenkins jenkins/jenkins --namespace infra -f helm/values/jenkins-values.yaml
```

### 3.4. Verify the Installation

Watch the `jenkins-0` pod. It will restart to apply the new configuration. Wait for it to be in the `Running` state.

```bash
kubectl get pods --namespace infra --watch
```

### 3.5. Access Jenkins

(No changes to this step)

```bash
# 1. Get the Jenkins admin password
kubectl get secret --namespace infra jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# 2. Forward the port in a new terminal (Jenkins runs on port 8080)
kubectl port-forward --namespace infra svc/jenkins 8080:8080

# 3. Open http://localhost:8080 in your browser
#    Login with username 'admin' and the password you retrieved.
```

## 4. Configure Jenkins for Kubernetes Deployment

(This section remains the same)

### 4.1. Create Directory for Kubernetes Configurations

```bash
mkdir -p kubernetes/jenkins-sa
```

### 4.2. Create Service Account YAML File

```yaml
# kubernetes/jenkins-sa/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-agent
  namespace: apps
```

### 4.3. Create Role & RoleBinding YAML File

```yaml
# kubernetes/jenkins-sa/role-binding.yaml
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

### 4.4. Apply the Kubernetes Configurations

```bash
kubectl apply -f kubernetes/jenkins-sa/
```

### 4.5. Add Kubernetes Credentials to Jenkins

1. Go to your Jenkins UI (`http://localhost:8080`).
2. Navigate to **Manage Jenkins** > **Credentials**.
3. Under **Stores scoped to Jenkins**, click on the **(global)** domain.
4. Click **Add Credentials** on the left menu.
5. Fill out the form:
   * **Kind**: Select `Kubernetes Service Account`.
   * **Scope**: `Global (unrestricted)`.
   * **ID**: `kubernetes-jenkins-agent`.
   * **Description**: `Service account to deploy to the apps namespace`.
6. Click **OK** to save.

## 5. Prepare the Platform Repository

(This section remains mostly the same, but we add a new step for the DSL script)

### 5.1. Prepare the Application `Dockerfile`

Ensure any application you want to onboard has a `Dockerfile` in its root directory. For the `sample-java-api`, the file is:

```Dockerfile
# Dockerfile

# Use a base image with Java 17
FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 5.2. Create a Generic Application Helm Chart

In your `my-devops-platform` repository, create the reusable Helm chart.

```bash
helm create helm/charts/generic-app
```

Then, add the Prometheus annotations to `helm/charts/generic-app/values.yaml`:

```yaml
# helm/charts/generic-app/values.yaml
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

### 5.3. Create the Job DSL Script

This is the core logic for generating our pipelines. In your `my-devops-platform` repository, create a new directory and file:

```bash
mkdir -p dsl
```

Now, create the file `dsl/seed.groovy` with the following content:

```groovy
// dsl/seed.groovy

// This script is executed by the seed job.
// It reads parameters from the seed job to generate other jobs.

// Get the Git repository URL from the seed job's parameters
def repoUrl = binding.getVariable('REPO_URL')

// Extract the repository name from the URL (e.g., "sample-java-api")
def repoName = repoUrl.tokenize('/').last().tokenize('.').first()

// Define the name of our platform repository (for getting the Helm chart)
def platformRepoUrl = '[https://github.com/your-username/my-devops-platform.git](https://github.com/your-username/my-devops-platform.git)' // <-- IMPORTANT: CHANGE THIS

// Create a folder to hold the generated jobs for this application
folder(repoName) {
    description("Pipelines for ${repoName}")
}

// 1. --- Generate the BUILD job ---
pipelineJob("${repoName}/build-${repoName}") {
    description("Builds and creates a Docker image for ${repoName}")
    
    // Define the pipeline script directly here
    definition {
        cps {
            script("""
                pipeline {
                    agent { label 'jenkins-maven-agent' }
                    
                    environment {
                        // Point to the Minikube internal Docker registry
                        DOCKER_REGISTRY = "localhost:5000"
                        IMAGE_NAME = "${repoName}"
                    }
                    
                    stages {
                        stage('Checkout Code') {
                            steps {
                                git branch: 'main', url: '${repoUrl}'
                            }
                        }
                        
                        stage('Run Build & Tests') {
                            steps {
                                container('maven') {
                                    // Use the Maven wrapper if present, otherwise use system mvn
                                    sh 'if [ -f mvnw ]; then ./mvnw clean install; else mvn clean install; fi'
                                }
                            }
                        }
                        
                        stage('Build and Push Docker Image') {
                            steps {
                                container('docker') {
                                    // Build the image
                                    sh "docker build -t \${IMAGE_NAME}:\${BUILD_ID} ."
                                    
                                    // Tag it for the local registry and push
                                    // Note: This requires the Minikube registry addon to be enabled
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

// 2. --- Generate the DEPLOY job ---
pipelineJob("${repoName}/deploy-${repoName}") {
    description("Deploys a specific version of ${repoName}")
    
    // This job will require a parameter: the image tag to deploy
    parameters {
        stringParam('IMAGE_TAG', '', 'The Docker image tag (build number) to deploy')
    }
    
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
                                    // Checkout the platform repo to get the generic Helm chart
                                    git url: '${platformRepoUrl}', branch: 'main'
                                    
                                    // Run the Helm command, using the IMAGE_TAG parameter
                                    sh \"\"\"
                                        helm upgrade --install \${HELM_RELEASE_NAME} ./\${HELM_CHART_PATH} \\
                                             --namespace apps \\
                                             --set image.repository="\${DOCKER_REGISTRY}/\${IMAGE_NAME}" \\
                                             --set image.tag="\${params.IMAGE_TAG}" \\
                                             --set image.pullPolicy=Always
                                    \"\"\"
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

## 6. Create and Run the Seed Job

This is the one job you will create manually. It will read the DSL script and generate all the others.

1.  **Enable the Minikube Docker Registry:** The DSL script is configured to push images to Minikube's internal registry. You must enable it in a separate terminal:
    ```bash
    minikube addons enable registry
    ```

2.  **Create the Seed Job in Jenkins:**
    * Go to your Jenkins UI (`http://localhost:8080`).
    * On the main dashboard, click **New Item**.
    * Enter an item name: `seed-job`.
    * Select **Freestyle project** and click **OK**.

3.  **Configure the Seed Job:**
    * Under the **General** tab, check the box **This project is parameterized**.
    * Click **Add Parameter** and select **String Parameter**.
    * **Name**: `REPO_URL`
    * **Description**: `The Git URL of the application to onboard (e.g., https://github.com/marlonpg/sample-java-api.git)`
    * Scroll down to the **Build Steps** section.
    * Click **Add build step** and select **Process Job DSLs**.
    * **Look on Filesystem**: Select this option.
    * **DSL Scripts**: Enter the path to your script: `dsl/seed.groovy`.
    * Under **Source Code Management**, select **Git**.
    * **Repository URL**: Enter the URL to *your* `my-devops-platform` repository. **IMPORTANT:** You must commit and push the `dsl/seed.groovy` file to this repository first.
    * Click **Save**.

## 7. The New Application Onboarding Workflow

Now, the process for onboarding a new application is completely automated:

1.  Go to the `seed-job` in Jenkins.
2.  Click **Build with Parameters**.
3.  Enter the Git URL of the new application (e.g., `https://github.com/marlonpg/sample-java-api.git`) into the `REPO_URL` field.
4.  Click **Build**.

The seed job will run, and when it's finished, you will see a new folder on the Jenkins dashboard named after the repository (e.g., `sample-java-api`). Inside this folder, you will find two new jobs: `build-sample-java-api` and `deploy-sample-java-api`.

To deploy the application:
1.  Run the `build-sample-java-api` job. Note the build number (e.g., `#1`).
2.  Run the `deploy-sample-java-api` job **with parameters**.
3.  For the `IMAGE_TAG` parameter, enter the build number from the build job (e.g., `1`).
4.  Click **Build**. The application will be deployed to your Kubernetes cluster.
