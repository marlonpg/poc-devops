# poc-devops

# Build a deployment system with:
- Jenkins
- Helm
- OpenTofu
- Minikub or other kubernetes cluster manager
- Prometheus
- Grafana

* Requirements: You need to be able to deploy an application with all this tools and you need 2 clusters (or 2 namespaces) one for the infra and other for the apps that will be deployed. The pipelines in Jenkins need to run tests and fail if tests fail. OpenTofu need to have automated tests as well, all apps deployed need to be integrated with Grafana and Prometheus by default.


---
### Installing Docker
https://docs.docker.com/get-docker/

### Installing Minikube
#### Step 1
- Download and run the installer for the latest release.
- Or if using PowerShell, use this command:
```bash
New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing
```
#### Step 2
- Add the minikube.exe binary to your PATH.
- Make sure to run PowerShell as Administrator.
```bash
$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\minikube'){
  [Environment]::SetEnvironmentVariable('Path', $('{0};C:\minikube' -f $oldPath), [EnvironmentVariableTarget]::Machine)
}
```

### Start up
#### Start Minikube with Docker
``` bash
minikube start --driver=docker
```
#### Enable the Kubernetes Dashboard (optional)
``` bash
minikube dashboard
```

http://127.0.0.1:59259/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/#/workloads?namespace=default

![alt text](images/image.png)

---

### Deploy Jenkins to Kubernetes

#### Creating YAML to deploy Jenkins (apply it)
``` bash
kubectl apply -f jenkins-deployment.yaml
```

#### Access Jenkins
``` bash
minikube service jenkins-service
```

#### Get Admin password
``` bash
kubectl exec -it $(kubectl get pod -l app=jenkins -o jsonpath="{.items[0].metadata.name}") -- cat /var/jenkins_home/secrets/initialAdminPassword
```

#### After applying the admin password
![alt text](images/customize-jenkins.png)


#### After adding some default plugins
![alt text](images/jenkins-first-page.png)