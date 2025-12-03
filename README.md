# Minecraft on Kubernetes
This Kubernetes deployment contains a docker image that provides a Minecraft Server that will automatically download the latest stable version at startup. You can also run/upgrade to any specific version or the latest snapshot.

```
cat <<EOF | kubectl apply -f -
# 1. PersistentVolumeClaim (PVC)
# Reserves the storage space for the Minecraft world data.
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minecraft-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      # You can adjust this size (e.g., 10Gi for a larger world)
      storage: 5Gi 

---

# 2. Deployment
# Defines the Pod that runs the Minecraft server container, including the EULA fix.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minecraft-deployment
  labels:
    app: minecraft
spec:
  replicas: 1 
  selector:
    matchLabels:
      app: minecraft
  template:
    metadata:
      labels:
        app: minecraft
    spec:
      containers:
      - name: minecraft-server
        image: itzg/minecraft-server:latest
        ports:
        - containerPort: 25565 
        env:
        - name: EULA
          value: "TRUE"
        volumeMounts:
        - name: minecraft-data
          mountPath: /data 
      volumes:
      - name: minecraft-data
        persistentVolumeClaim:
          claimName: minecraft-pvc

---

# 3. Service
# Exposes the Deployment so players can connect to the server.
apiVersion: v1
kind: Service
metadata:
  name: minecraft-service
  labels:
    app: minecraft
spec:
  type: NodePort 
  selector:
    app: minecraft
  ports:
    - protocol: TCP
      port: 25565      
      targetPort: 25565 
EOF
```

Check to see that the service is running:
```
kubectl get svc minecraft-service
kubectl get pods -l app=minecraft
kubectl port-forward svc/minecraft-service 25565:25565
```


## Doom on Kubernetes
```
cat <<EOF | kubectl apply -f -
# -------------------------------------------------------------------
# 1. ServiceAccount for Kubedoom
# -------------------------------------------------------------------
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubedoom
  namespace: default
---
# -------------------------------------------------------------------
# 2. ClusterRole defining Kubedoom's permissions
# -------------------------------------------------------------------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubedoom
rules:
# Permissions for Kubedoom to find, delete, and manage pods and nodes
- apiGroups: [""]
  resources: ["pods", "pods/exec", "nodes"]
  verbs: ["get", "list", "watch", "delete"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
---
# -------------------------------------------------------------------
# 3. ClusterRoleBinding linking the ServiceAccount to the ClusterRole
# -------------------------------------------------------------------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubedoom
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubedoom
subjects:
- kind: ServiceAccount
  name: kubedoom
  namespace: default
---
# -------------------------------------------------------------------
# 4. Multi-Container Pod Definition (Kubedoom + noVNC Proxy)
# NOTE: Security context on 'kubedoom' is relaxed to fix 'socket file' error.
# -------------------------------------------------------------------
apiVersion: v1
kind: Pod
metadata:
  name: kubedoom-with-novnc
  labels:
    app: kubedoom
spec:
  serviceAccountName: kubedoom
  
  containers:
  # --- Kubedoom Container (VNC Server) ---
  - name: kubedoom
    image: ghcr.io/storax/kubedoom:latest
    imagePullPolicy: Always
    ports:
    - containerPort: 5900
      name: vnc-port
    securityContext:
      # RELAXED SECURITY CONTEXT to allow Xvfb to create socket files
      runAsNonRoot: false
      runAsUser: 0
      # We removed other restrictive settings (like seccompProfile) for simplicity
      # in solving the current issue.

  # --- noVNC Container (Web Proxy) ---
  - name: novnc-proxy
    image: theasp/novnc:latest
    imagePullPolicy: Always
    ports:
    - containerPort: 8080
      name: web-port 
    env:
    - name: VNC_HOST
      value: "localhost"
    - name: VNC_PORT
      value: "5900"
    - name: PORT
      value: "8080"
EOF
```

```
kubectl apply -f https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/refs/heads/main/kube-doom2.yaml
```

```
kubectl delete -f https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/refs/heads/main/kube-doom2.yaml
```

```
kubectl get pod kubedoom-with-novnc -w
```

```
kubectl port-forward pod/kubedoom-with-novnc 8080:8080
```

**URL:** <a href="http://localhost:8080/vnc.html" target="_blank">localhost on port 8000</a> <br/>
**Password:** ```idbehold```

Read the logs better:
```
alias kubectl="kubecolor"
```

Create excess namespace names to reflect our monsters:
```
kubectl apply -f https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/refs/heads/main/namespaces.yaml
```

```
kubectl logs kubedoom-with-novnc --follow | \
awk '
  /kill/ || /monster/ || /process/ {
    # Bright Red for 'kill'
    gsub("kill", "\033[1;31mkill\033[0m");
    # Bright Yellow for 'monster'
    gsub("monster", "\033[1;33mmonster\033[0m");
    # Bright Blue for 'process'
    gsub("process", "\033[1;34mprocess\033[0m");
    print
  }
'
```

Auto-generate enemies script:
```
wget https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/refs/heads/main/enemies.sh
chmod +x enemies.sh
```

Run the script:
```
./enemies.sh
```

### Cleanup
Finds all namespaces starting with 'meghan' and deletes them
```
kubectl get ns --no-headers | grep '^cve-[0-9]' | awk '{print $1}' | xargs -r kubectl delete ns
```

### Interacting with the local container

```
docker run -it --platform linux/amd64 --entrypoint /bin/bash docker.cloudsmith.io/acme-corporation/acme-repo-one/kubedoom:latest
```

Use this command to recursively list everything starting from the root of the container file system:
```
find / -print
```

This will print every single file and folder path inside the container. <br/>
Since the output will be enormous, you should pipe it to a command that lets you read it one page at a time:
```
find / -name "*.wad"
```

Assuming you have an alternative .wad file on your /Desktop directory locally, we can move this into our running pod:
```
kubectl cp ./STARWAR1.WAD default/kubedoom-with-novnc:/root/doom1.wad -c kubedoom
```

From outside the pod, you can see that there is a pre-existing .wad file:
```
kubectl exec -it kubedoom-with-novnc -c kubedoom -- ls -lh /root/doom1.wad
```

``` -rw-rw-r-- 1 502 staff 282K Dec  3 12:46 /root/doom1.wad ```

<br/><br/>

### Pushing packages to Cloudsmith

```
docker pull ghcr.io/storax/kubedoom:latest
docker login docker.cloudsmith.io -u "$USERNAME" -p "$CLOUDSMITH_API_KEY"
docker tag ghcr.io/storax/kubedoom:latest docker.cloudsmith.io/acme-corporation/acme-repo-one/kubedoom:latest
docker push docker.cloudsmith.io/acme-corporation/acme-repo-one/kubedoom:latest
```

```
docker pull theasp/novnc:latest
docker login docker.cloudsmith.io -u "$USERNAME" -p "$CLOUDSMITH_API_KEY"
docker tag theasp/novnc:latest docker.cloudsmith.io/acme-corporation/acme-repo-one/novnc:latest
docker push docker.cloudsmith.io/acme-corporation/acme-repo-one/novnc:latest
```

```
docker pull docker.cloudsmith.io/acme-corporation/acme-repo-one/kubedoom:latest
docker run -it docker.cloudsmith.io/acme-corporation/acme-repo-one/kubedoom:latest /bin/bash
docker inspect docker.cloudsmith.io/acme-corporation/acme-repo-one/kubedoom:latest
```

<br/><br/>

### Making changes to Doom in Production

Changed from ```pod``` to ```deployment``` in this version:
```
kubectl apply -f https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/refs/heads/main/kube-doom3.yaml
```

As a result, we need to ```port-forward``` from the deployment:
```
kubectl port-forward deployment/kubedoom-deployment 8080:8080
```

Check the two Cloudsmith images associated with your running pod:
```
kubectl get pods -o custom-columns=POD_NAME:.metadata.name,IMAGE:".spec.containers[*].image"
```

Define the correct raw URL
```
RAW_WAD_URL="https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/main/doom1.wad"
```

Execute the download inside the container, saving it directly as ```doom1.wad```
```
kubectl cp "$FULL_WAD_PATH" default/"$(kubectl get pods -l app=kubedoom -o jsonpath='{.items[0].metadata.name}')":/root/doom1.wad -c kubedoom
```

```
kubectl exec -it deployment/kubedoom-deployment -c kubedoom -- /bin/bash
ls -lh /root/doom1.wad
```
