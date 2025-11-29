# Minecraft on Kubernetes
This Kubernetes deployment contains a docker image that provides a Minecraft Server that will automatically download the latest stable version at startup. You can also run/upgrade to any specific version or the latest snapshot.

```
cat <<EOF | kubectl apply -f -
# 1. PersistentVolumeClaim (PVC)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minecraft-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi 
---
# 2. Deployment
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
        volumeMounts:
        - name: minecraft-data
          mountPath: /data 
      volumes:
      - name: minecraft-data
        persistentVolumeClaim:
          claimName: minecraft-pvc
---
# 3. Service
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
```
