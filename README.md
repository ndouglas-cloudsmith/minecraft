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
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubedoom-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubedoom-cr
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "namespaces"]
  verbs: ["get", "list", "watch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubedoom-crb
subjects:
- kind: ServiceAccount
  name: kubedoom-sa
  namespace: default
roleRef:
  kind: ClusterRole
  name: kubedoom-cr
  apiGroup: rbac.authorization.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubedoom
  labels:
    app: kubedoom
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubedoom
  template:
    metadata:
      labels:
        app: kubedoom
    spec:
      serviceAccountName: kubedoom-sa
      containers:
      - name: kubedoom
        image: ghcr.io/storax/kubedoom:latest
        ports:
        - containerPort: 5900 # The VNC port inside the container
          name: vnc-port
---
apiVersion: v1
kind: Service
metadata:
  name: kubedoom-vnc-clusterip
spec:
  selector:
    app: kubedoom
  ports:
  - protocol: TCP
    port: 5900 # Service port (doesn't matter much for ClusterIP/port-forward)
    targetPort: 5900 # **The actual VNC port**
  type: ClusterIP # <-- This is the key change!
EOF
```

```
kubectl port-forward service/kubedoom-vnc-clusterip 5901:5900
```

```
vncviewer localhost:5901
```
