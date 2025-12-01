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
# 1. Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: doom

---
# 2. Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubedoom-sa
  namespace: doom

---
# 3. ClusterRole (Grants Permission to Delete Pods Cluster-wide)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubedoom-pod-deleter
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "list", "watch", "delete"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"] # Required for Kubedoom to list all namespaces

---
# 4. ClusterRoleBinding (Binds the ServiceAccount to the ClusterRole)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubedoom-pod-deleter-binding
subjects:
- kind: ServiceAccount
  name: kubedoom-sa
  namespace: doom
roleRef:
  kind: ClusterRole
  name: kubedoom-pod-deleter
  apiGroup: rbac.authorization.k8s.io

---
# 5. Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubedoom-deployment
  namespace: doom
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
      serviceAccountName: kubedoom-sa # Use the ServiceAccount with the ClusterRole
      containers:
      - name: kubedoom
        image: ghcr.io/storax/kubedoom:latest
        imagePullPolicy: Always
        
        # Optionally, set NAMESPACE to a specific namespace if you want Kubedoom 
        # to only target pods there. Leave this out for cluster-wide deletion.
        # env:
        # - name: NAMESPACE
        #   value: "your-target-namespace" 
        
        ports:
        - containerPort: 5900
          name: vnc-port
          
        # Note: We are now relying on the ServiceAccount permissions (RBAC) 
        # instead of mounting the host's kubeconfig, which is the standard K8s approach.
        # This removes the need for the insecure 'hostPath' volume.

---
# 6. Service (Exposes VNC)
apiVersion: v1
kind: Service
metadata:
  name: kubedoom-vnc-service
  namespace: doom
spec:
  selector:
    app: kubedoom
  ports:
    # Port 5901 is the port you'll connect to externally (VNC client)
    # TargetPort 5900 is the port the container is listening on
    - port: 5901
      targetPort: 5900
      protocol: TCP
      name: vnc-port
  # NodePort allows external access; change to LoadBalancer if on a cloud provider
  type: NodePort
EOF
```

```
kubectl get svc -n doom kubedoom-vnc-service
```

```
kubectl port-forward service/kubedoom-vnc-service 8080:8080
```
