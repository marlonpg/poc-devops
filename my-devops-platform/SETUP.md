DevOps Platform Setup GuideThis document outlines the step-by-step commands to set up a local DevOps platform using Minikube, Helm, Prometheus, Grafana, and Jenkins.1. Initial Setup1.1. Create Project DirectoryAll configuration files will be stored here.mkdir my-devops-platform
cd my-devops-platform
1.2. Create Kubernetes NamespacesLogically separate infrastructure components from deployed applications.# Create the 'infra' namespace for tools like Jenkins, Prometheus, etc.
kubectl create namespace infra

# Create the 'apps' namespace for your applications
kubectl create namespace apps

# Verify that the namespaces were created
kubectl get namespaces
2. Monitoring Stack: Prometheus & Grafana2.1. Add Helm RepositoryAdd the community repository that contains the monitoring stack chart.helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
2.2. Install the ChartInstall the kube-prometheus-stack chart, which bundles Prometheus, Grafana, and other necessary components into the infra namespace.helm install prometheus prometheus-community/kube-prometheus-stack --namespace infra
2.3. Verify the InstallationCheck the status of the pods. Wait until they are all in the Running state.# Watch the status in real-time
kubectl get pods --namespace infra --watch
2.4. Access Grafana & PrometheusUse kubectl port-forward to access the web UIs from your local machine. Each command requires its own terminal window.Access Grafana:# 1. Get the admin password
kubectl get secret --namespace infra prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# 2. Forward the port
kubectl port-forward --namespace infra svc/prometheus-grafana 3000:80

# 3. Open http://localhost:3000 in your browser (user: admin)
Access Prometheus:# 1. Forward the port in a new terminal
kubectl port-forward --namespace infra svc/prometheus-kube-prometheus-prometheus 9090:9090

# 2. Open http://localhost:9090 in your browser
3. CI/CD Server: Jenkins3.1. Update Jenkins Helm Values FileUpdate your helm/values/jenkins-values.yaml file to include docker and helm tools in your build agent, and add the github-branch-source plugin needed for organization scanning.# helm/values/jenkins-values.yaml
controller:
  installPlugins:
    - kubernetes
    - workflow-aggregator
    - git
    - configuration-as-code
    # Add this plugin for GitHub Organization scanning
    - github-branch-source
  persistence:
    enabled: true
    storageClass: "standard"
    size: "8Gi"

agent:
  kubernetes:
    name: kubernetes
    namespace: infra
    jenkinsUrl: http://jenkins.infra.svc.cluster.local:8080
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
3.2. Add Jenkins Helm Repository(If you haven't already done this)helm repo add jenkins https://charts.jenkins.io
helm repo update
3.3. Upgrade JenkinsApply the new plugin configuration by running helm upgrade.helm upgrade jenkins jenkins/jenkins --namespace infra -f helm/values/jenkins-values.yaml
3.4. Verify the InstallationWatch the jenkins-0 pod. It will restart to apply the new configuration. Wait for it to be in the Running state.kubectl get pods --namespace infra --watch
3.5. Access Jenkins(No changes to this step)# 1. Get the Jenkins admin password
kubectl get secret --namespace infra jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# 2. Forward the port in a new terminal (Jenkins runs on port 8080)
kubectl port-forward --namespace infra svc/jenkins 8080:8080

# 3. Open http://localhost:8080 in your browser
#    Login with username 'admin' and the password you retrieved.
4. Configure Jenkins for Kubernetes DeploymentCreate a Service Account for Jenkins to give it secure access to deploy applications into the apps namespace.4.1. Create Directory for Kubernetes Configurationsmkdir -p kubernetes/jenkins-sa
4.2. Create Service Account YAML FileCreate a file named kubernetes/jenkins-sa/service-account.yaml with the following content. This defines the "user account" for Jenkins.# kubernetes/jenkins-sa/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-agent
  namespace: apps
4.3. Create Role & RoleBinding YAML FileCreate a file named kubernetes/jenkins-sa/role-binding.yaml with the following content. This defines the permissions for the Jenkins user and assigns them.# kubernetes/jenkins-sa/role-binding.yaml
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
4.4. Apply the Kubernetes ConfigurationsApply the files to your cluster from the root of your project directory.kubectl apply -f kubernetes/jenkins-sa/
4.5. Add Kubernetes Credentials to JenkinsNow, configure Jenkins to use the Service Account you just created. This credential ID must match the one in jenkins-values.yaml.Go to your Jenkins UI (http://localhost:8080).Navigate to Manage Jenkins > Credentials.Under Stores scoped to Jenkins, click on the (global) domain.Click Add Credentials on the left menu.Fill out the form:Kind: Select Kubernetes Service Account.Scope: Global (unrestricted).ID: kubernetes-jenkins-agent (This must match the ID from your values file).Description: Service account to deploy to the apps namespace.Click OK to save.5. Prepare the Application for DeploymentFor this step, you will need a local copy of the sample-java-api application. It's best practice to fork the repository on GitHub and then clone your fork.# Clone the repository (replace with your fork's URL if you created one)
git clone https://github.com/marlonpg/sample-java-api.git
cd sample-java-api
5.1. Create the DockerfileIn the root of the sample-java-api directory, create a new file named Dockerfile with the following content. This file defines how to build the container image for the application.# Dockerfile

# Use a base image with Java 17
FROM eclipse-temurin:17-jdk-jammy

# Set the working directory inside the container
WORKDIR /app

# Copy the compiled JAR file from the target directory to the container
# The JAR file is created by the 'mvn package' command
COPY target/*.jar app.jar

# Expose port 8080, which is the default port for the Spring Boot application
EXPOSE 8080

# The command to run when the container starts
ENTRYPOINT ["java", "-jar", "app.jar"]
5.2. Create a Generic Application Helm ChartInstead of creating a new chart for every application, we will create one generic chart in our platform repository. This chart will be reused for all applications, making the process much more automated for developers.Navigate back to your my-devops-platform root folder.Create a directory to hold your application charts.mkdir -p helm/charts
Use the helm create command to generate a boilerplate chart named generic-app.helm create helm/charts/generic-app
Important: We need to add annotations to the chart's values.yaml file so that Prometheus can automatically discover and scrape metrics from our application. Open the file helm/charts/generic-app/values.yaml and add the podAnnotations block as shown below:# helm/charts/generic-app/values.yaml

# ... (keep all the existing content above)

service:
  type: ClusterIP
  port: 8080

# Add this entire podAnnotations block
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"

# ... (keep all the existing content below)
6. Create the Automation Pipeline (Jenkinsfile)This is the heart of your CI/CD process. In the root of your sample-java-api project, create a new file named Jenkinsfile with the following content. Notice it now points to the generic-app chart.// Jenkinsfile

pipeline {
    // 1. Define the build agent. This must match the label in jenkins-values.yaml
    agent {
        label 'jenkins-maven-agent'
    }

    // 2. Environment variables used throughout the pipeline
    environment {
        // The name of the Docker image we will build
        IMAGE_NAME = "sample-java-api"
        // The path to the GENERIC application's Helm chart in the platform repo
        HELM_CHART_PATH = "helm/charts/generic-app"
        // The Helm release name for the deployment
        HELM_RELEASE_NAME = "sample-java-api"
    }

    stages {
        // 3. Stage to run tests. The pipeline will fail here if tests fail.
        stage('Run Tests') {
            steps {
                // Use the 'maven' container from our agent pod
                container('maven') {
                    sh 'mvn test'
                }
            }
        }

        // 4. Stage to compile the code and package it into a .jar file
        stage('Package Application') {
            steps {
                container('maven') {
                    // Skip tests since they already ran
                    sh 'mvn package -DskipTests'
                }
            }
        }

        // 5. Stage to build a Docker image
        stage('Build Docker Image') {
            steps {
                // Use the 'docker' container from our agent pod
                container('docker') {
                    // Build the image and tag it with the Jenkins BUILD_ID
                    sh "docker build -t ${env.IMAGE_NAME}:${env.BUILD_ID} ."
                }
            }
        }

        // 6. Stage to deploy the application using Helm
        stage('Deploy to Kubernetes') {
            steps {
                // Use the 'helm' container from our agent pod
                container('helm') {
                    // We need to check out the devops-platform repo to get the Helm chart
                    // This assumes your my-devops-platform project is also in a Git repo
                    // For this example, we'll use a placeholder URL.
                    // IMPORTANT: Replace this with the actual URL to your devops platform repo
                    git url: 'https://github.com/your-username/my-devops-platform.git', branch: 'main'
                    
                    // Run the helm upgrade command
                    sh """
                        helm upgrade --install ${env.HELM_RELEASE_NAME} ./${env.HELM_CHART_PATH} \\
                             --namespace apps \\
                             --set image.repository=${env.IMAGE_NAME} \\
                             --set image.tag=${env.BUILD_ID} \\
                             --set image.pullPolicy=Never
                    """
                }
            }
        }
    }
}
7. Automate Job Creation with an Organization FolderThis is the final, fully automated step. Instead of creating one job per repository, you create one "Organization Folder" that automatically discovers every repository with a Jenkinsfile.Go to your Jenkins UI (http://localhost:8080).On the main dashboard, click New Item.Enter an item name, for example, marlonpg-repos (or your GitHub username/organization).Select Organization Folder and click OK.On the configuration page, under Projects, click Add source and select GitHub.In the Owner field, enter the GitHub username or organization name whose repositories you want to scan (e.g., marlonpg).Jenkins will automatically scan the account, find the sample-java-api repository (because it contains a Jenkinsfile), and create the pipeline job for it.Click Save.From now on, to add a new application to this CI/CD system, the only thing a developer needs to do is add a Jenkinsfile to their repository. Jenkins will discover it and build it automatically.