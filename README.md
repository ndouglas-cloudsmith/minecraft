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
kubectl apply -f https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/refs/heads/main/kube-doom.yaml
```

```
kubectl delete -f https://raw.githubusercontent.com/ndouglas-cloudsmith/minecraft/refs/heads/main/kube-doom.yaml
```

```
kubectl get pod kubedoom-with-novnc -w
```

```
kubectl port-forward pod/kubedoom-with-novnc 8080:8080
```

**URL:** http://localhost:8080/vnc.html <br/>
**Password:** ```idbehold```

Read the logs better:
```
alias kubectl="kubecolor"
```

Create excess namespace names to reflect our monsters:
```
kubectl create ns juliana, brooke, meghan, parul, nicky, corey, claire, nigel
```

```
kubectl logs kubedoom-with-novnc -c kubedoom --follow | \
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
