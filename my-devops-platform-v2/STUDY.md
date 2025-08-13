### 1. Why are there namespaces in Kubernetes?
Namespaces are a way to **divide cluster resources** between multiple users, teams, or applications. Think of them like folders on a computer; they provide a scope for names. This allows you to have, for example, a "database" service in a "development" namespace and another "database" service in a "production" namespace within the same cluster, without them conflicting.

They are essential for:
* **Organization:** Grouping related resources together.
* **Multi-tenancy:** Creating logically separate environments for different teams or projects.
* **Access Control:** Applying role-based access control (RBAC) and resource quotas on a per-namespace basis.

***

### 2. How does a Kubernetes cluster work?
A Kubernetes cluster consists of a set of worker machines, called **nodes**, that run containerized applications. Every cluster has at least one worker node. The worker node(s) host the **Pods** that are the components of the application workload.

The cluster's operations are managed by the **Control Plane**.


* **Control Plane (Master Node):** This is the brain of the cluster 🧠. It makes global decisions about the cluster (e.g., scheduling) and detects and responds to cluster events. Its key components are:
    * **API Server:** The frontend for the control plane. It exposes the Kubernetes API, which is how you (using `kubectl`) and other components interact with the cluster.
    * **etcd:** A consistent and highly-available key-value store used as Kubernetes' backing store for all cluster data.
    * **Scheduler:** Watches for newly created Pods with no assigned node and selects a node for them to run on.
    * **Controller Manager:** Runs controller processes that regulate the state of the cluster. For example, if a node fails, a controller notices and takes corrective action.

* **Worker Nodes:** These are the machines (VMs or physical servers) where your applications run. Each node contains:
    * **Kubelet:** An agent that runs on each node and makes sure that containers are running in a Pod.
    * **Container Runtime:** The software that is responsible for running containers (e.g., Docker, containerd).
    * **Kube-Proxy:** A network proxy that runs on each node, maintaining network rules to allow network communication to your Pods from inside or outside the cluster.

You tell the control plane your **desired state** (e.g., "I want 3 instances of this application running"), and the control plane works to make the cluster's **current state** match that desired state.

***

### 3. What is kubectl?
**`kubectl`** is the primary **command-line tool (CLI)** for interacting with a Kubernetes cluster. You use it to deploy applications, inspect and manage cluster resources, and view logs. It communicates with the cluster's API Server to perform these actions.

***

### 4. How to work with volumes?
Since containers in a Pod are ephemeral and their filesystems are lost when they crash or restart, **volumes** are used to provide **persistent storage** 💾. A volume is essentially a directory that is accessible to the containers in a Pod.

You define a volume in the Pod's specification (`spec.volumes`) and then mount it into the desired containers (`spec.containers.volumeMounts`).

Key concepts include:
* **Volumes:** Attached to a Pod and shared among its containers. The volume's lifecycle is tied to the Pod's lifecycle.
* **PersistentVolume (PV):** A piece of storage in the cluster that has been provisioned by an administrator. It's a resource in the cluster, just like a node.
* **PersistentVolumeClaim (PVC):** A request for storage by a user. A user's Pod requests a PVC, and Kubernetes binds that claim to an available PV, abstracting away the underlying storage details.

***

### 5. How does Ingress networking work?
**Ingress** is an API object that manages external access to the services in a cluster, typically HTTP and HTTPS. It acts as a **smart router or an entry point** for your cluster.

It works using two components:
1.  **Ingress Resource:** A set of rules you create. These rules define how external traffic should be routed to internal services (e.g., route traffic from `http://foo.com/bar` to the `bar-service`).
2.  **Ingress Controller:** This is the actual component (a load balancer or proxy server like NGINX, Traefik, or HAProxy) that reads the Ingress Resource and implements the rules. You must have an Ingress controller running in your cluster for Ingress to work.

The flow is: **External Client → Ingress Controller → Service → Pod**.

***

### 6. Why do Minikube and Kind exist?
**Minikube** and **Kind** are tools that allow you to run a **local Kubernetes cluster on your personal machine**.

Their primary purpose is for **development and learning** 🎓. They provide a simple, lightweight Kubernetes environment where developers can test their applications before deploying them to a full-scale production cluster.

* **Minikube:** Typically creates a single-node cluster inside a virtual machine (VM) or container. It's great for getting started quickly.
* **Kind (Kubernetes in Docker):** Runs Kubernetes cluster nodes as Docker containers. It's particularly useful for simulating multi-node cluster scenarios locally.

***

### 7. How does the Kubernetes networking system work?
The Kubernetes network model is built on a flat network structure with a few fundamental principles:
1.  **Every Pod gets its own unique IP address.** All containers within a Pod share this IP address.
2.  **Pods can communicate with all other Pods** on any node without needing Network Address Translation (NAT).
3.  **Services** provide a stable endpoint (a virtual IP and a DNS name) to communicate with a group of Pods. The `kube-proxy` component on each node handles routing traffic destined for a Service's IP to one of the backing Pods.

This model is implemented by **Container Network Interface (CNI) plugins** like Calico, Flannel, or Cilium, which are responsible for assigning IP addresses to Pods and configuring the necessary network routes.

***

### 8. What are Pods?
A **Pod** is the **smallest and simplest deployable unit** in Kubernetes. It represents a single instance of a running process in your cluster.

A Pod encapsulates one or more containers (like Docker containers), storage resources (volumes), a unique network IP, and options that govern how the container(s) should run. While a Pod can contain multiple containers, the most common pattern is one container per Pod.

***

### 9. What are Services?
A **Service** is a Kubernetes object that provides a **stable network endpoint** for a set of Pods. Since Pods are ephemeral (they can be created, destroyed, and replaced), their IP addresses change. A Service gives you a single, constant IP address and DNS name to access the application running in those Pods, regardless of what happens to the individual Pods themselves.

Services use **labels and selectors** to dynamically find the group of Pods they should route traffic to.

***

### 10. What is Helm?
Helm is known as **"the package manager for Kubernetes."** 📦 It's a tool that streamlines the installation and management of Kubernetes applications. Helm allows you to find, share, and use software built for Kubernetes, making it much easier to manage complex applications.

***

### 11. What is a Helm Chart?
A **Helm Chart** is a **package** containing all the necessary pre-configured Kubernetes resource definitions to deploy an application, tool, or service inside a Kubernetes cluster. Think of it like an `apt` or `yum` package in Linux, but for Kubernetes.

***

### 12. How does Helm work with Kubernetes?
Helm works by combining two things:
1.  A **Chart:** A collection of templates for Kubernetes manifest files.
2.  A **`values.yaml` file:** Your custom configuration values for that Chart.

Helm takes the templates, injects your values into them, and **renders** them into standard, fully-formed Kubernetes manifest files. It then sends these manifests to the Kubernetes API server, which creates or updates the resources in your cluster.

***

### 13. How does OpenTofu work? Why was it created?
**OpenTofu** is an **Infrastructure as Code (IaC)** tool. It lets you define and provision infrastructure (like servers, networks, and databases) using a declarative configuration language called HCL (HashiCorp Configuration Language).

It works in three steps:
1.  **Write:** You define your infrastructure in `.tf` configuration files.
2.  **Plan:** OpenTofu creates an execution plan (`terraform plan`) describing what it will create, update, or destroy to reach your desired state.
3.  **Apply:** You approve the plan (`terraform apply`), and OpenTofu executes the actions to build the infrastructure across various cloud providers (AWS, Azure, GCP, etc.).

**Why was it created?** OpenTofu was created as a **community-driven, open-source fork of Terraform**. It was established after HashiCorp, the original creator of Terraform, switched its license from the open-source MPL 2.0 to the more restrictive Business Source License (BSL). The community, under the stewardship of the Linux Foundation, created OpenTofu to ensure the tool would remain truly open-source and community-governed.

***

### 14. What are Jenkins Agents?
**Jenkins Agents** (formerly known as "slaves") are worker machines that are connected to a central Jenkins controller (or "master"). Their job is to **execute the build tasks** (or "jobs") dispatched by the controller. Using agents allows you to distribute the workload, run multiple jobs in parallel, and execute jobs on different operating systems or environments.

***

### 15. What types of agents are there?
There are two primary types of Jenkins agents:
* **Permanent Agents:** These are traditional agents that are always connected to the Jenkins controller. They are typically dedicated machines that are manually configured and remain online.
* **Cloud/Dynamic Agents:** These agents are provisioned on-demand from a cloud provider (like AWS EC2, Azure VM, or a Kubernetes Pod) when a job needs to be run and are terminated once the job is complete. This approach is highly scalable and cost-effective as you only pay for the compute resources you use.

***

### 16. What is Prometheus? What is it used for?
**Prometheus** is a leading **open-source monitoring and alerting toolkit**.


It is used to **collect and store time-series data**. Its core function is to scrape (pull) metrics from configured endpoints at specified intervals, evaluate rule expressions, display the results, and trigger alerts if some condition is observed to be true. It's particularly well-suited for monitoring dynamic cloud-native environments like Kubernetes.

***

### 17. What is Grafana? What is it used for?
**Grafana** is an **open-source analytics and interactive visualization web application**.


It is used to **create beautiful and informative dashboards** 📊. Grafana allows you to query, visualize, alert on, and explore your metrics no matter where they are stored. It connects to various data sources, with **Prometheus** being one of the most common. In short, Prometheus collects the data, and Grafana makes it look pretty and easy to understand.

***

### 18. What is a pipeline in Jenkins?
A **Jenkins Pipeline** is a suite of plugins that allows you to implement and integrate **continuous delivery pipelines** into Jenkins. A pipeline defines your entire build process—from checking out code from source control, to building, testing, and deploying it—as a single workflow. This is often described as "Pipeline as Code."

***

### 19. What is a Jenkinsfile?
A **Jenkinsfile** is a **text file that contains the definition of a Jenkins Pipeline**. It is written using a Groovy-based Domain-Specific Language (DSL). By committing a `Jenkinsfile` to your source control repository alongside your application code, you can version, review, and manage your CI/CD process in the same way you manage your code.

***

### 20. What is a Dockerfile and how does it work?
A **Dockerfile** is a **text file that contains a series of instructions on how to build a Docker image**. It's a recipe for creating your container image.

It works when you run the `docker build` command. Docker reads the instructions in the Dockerfile one by one, executing each to create a new layer for the image.
* `FROM`: Specifies the base image to start from.
* `COPY`: Copies files from your local machine into the image.
* `RUN`: Executes a command inside the image (e.g., to install software).
* `CMD`: Specifies the default command to run when a container is started from the image.

This layered approach makes image builds efficient and cacheable.

***

### 21. What is a container registry?
A **container registry** is a **storage and distribution system for container images**. It's a centralized place to store your Docker images and manage their versions. When you run `docker pull nginx`, Docker fetches the `nginx` image from a public registry (Docker Hub). When you run `docker push my-app`, you are uploading your custom image to a registry.

Popular registries include Docker Hub, Google Container Registry (GCR), Amazon Elastic Container Registry (ECR), and Azure Container Registry (ACR).

***

### 22. How to create a custom Helm Chart?
The easiest way to create a custom Helm Chart is by using the Helm command-line tool.

1.  Run the command `helm create my-chart-name`.
2.  This will generate a directory named `my-chart-name` with a standard file structure, including:
    * `Chart.yaml`: Contains metadata about your chart (name, version, etc.).
    * `values.yaml`: Contains the default configuration values for your chart.
    * `templates/`: A directory that holds the Kubernetes resource template files. This is where you'll define your Deployments, Services, etc.
    * `charts/`: A directory for any chart dependencies.
3.  You then **customize the template files** in the `templates/` directory and **adjust the default settings** in `values.yaml` to match your application's needs.

***

### 23. How to add a repository in Helm?
You add a Helm repository using the `helm repo add` command. A repository is a location where charts are stored and can be shared.

The syntax is: `helm repo add [NAME] [URL]`

For example, to add the popular Bitnami repository, you would run:
```bash
helm repo add bitnami [https://charts.bitnami.com/bitnami](https://charts.bitnami.com/bitnami)