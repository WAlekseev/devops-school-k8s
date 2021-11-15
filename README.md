# Task 4

## Homework 4.1
Create users deploy_view and deploy_edit. Give the user deploy_view rights only to view deployments, pods. Give the user deploy_edit full rights to the objects deployments, pods.

Generate X.509 CSR
```
openssl genrsa -out deploy_view.key 2048
openssl req -new -key deploy_view.key -out deploy_view.csr -subj "/CN=deploy_view/O=deploy_view_group" 

openssl genrsa -out deploy_edit.key 2048
openssl req -new -key deploy_edit.key -out deploy_edit.csr -subj "/CN=deploy_edit/O=deploy_edit_group" 
```

#### NB! Because I have a docker-desktop based k8s cluster my way to create users certificates does not correlate with minikube way. It's because docker-desktop doesn't share CA crt and key and it's hard to get. So I will use a Kubernetes API to complete this task.

Create template cert-sign-request-template.yaml
```
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: k8s_user
spec:
  request: __CERT_REQ__
  signerName: kubernetes.io/kube-apiserver-client
  usages: ['digital signature', 'key encipherment', 'client auth']
```

Generate sign request for Kubernetes API for users deploy_view, deploy_edit
```
sed 's/__CERT_REQ__/'"$(cat deploy_view.csr | base64 | tr -d '\n')"'/g' cert-sign-request-template.yaml | sed 's/k8s_user/deploy_view/g' > cert-sign-request-deploy_view.yaml

sed 's/__CERT_REQ__/'"$(cat deploy_edit.csr | base64 | tr -d '\n')"'/g' cert-sign-request-template.yaml | sed 's/k8s_user/deploy_edit/g' > cert-sign-request-deploy_edit.yaml
```

Issue sign request 
```
kubectl apply -f cert-sign-request-deploy_view.yaml
kubectl apply -f cert-sign-request-deploy_edit.yaml
```

Approve and sign
```
kubectl certificate approve deploy_view
kubectl certificate approve deploy_edit
```

Get signed certificate
```
kubectl get csr deploy_view -o jsonpath='{.status.certificate}' > deploy_view.b64
cat deploy_view.b64 | base64 -d > deploy_view.crt

kubectl get csr deploy_edit -o jsonpath='{.status.certificate}' > deploy_edit.b64
cat deploy_edit.b64 | base64 -d > deploy_edit.crt
```

Import user certificates into config
```
kubectl config set-credentials deploy_view --client-key deploy_view.key --client-certificate deploy_view.crt --embed-certs
kubectl config set-credentials deploy_edit --client-key deploy_edit.key --client-certificate deploy_edit.crt --embed-certs
```

Create and bind contexts for users 
```
kubectl config set-context d_view --cluster docker-desktop --user deploy_view
kubectl config set-context d_edit --cluster docker-desktop --user deploy_edit
kubectl config view
```


#### NB! Because in this task text do not strictly mention what kind of scope are needed for users *deploy_view* and *deploy_edit* - cluster or namespace, I'm assuming that we bind them to cluster scope, so I'm using ClusterRole and ClusterRoleBinding to complete the task.

Task: Give the user deploy_view rights only to view deployments, pods.
Create role definition for *deploy_view*
ClusterRole-pod-viewer.yaml
```
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1  
metadata:  
  name: deploy-pod-viewer
rules:  
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

```

Role binding for *deploy_view*
ClusterRoleBinding-pod-viewer.yaml
```
kind: ClusterRoleBinding  
apiVersion: rbac.authorization.k8s.io/v1  
metadata:  
  name: deploy-pod-viewer
subjects:  
- kind: User
  name: deploy_view
  apiGroup: rbac.authorization.k8s.io
roleRef:  
  kind: ClusterRole
  name: deploy-pod-viewer
  apiGroup: rbac.authorization.k8s.io
```



Task: Give the user deploy_edit full rights to the objects deployments, pods.
Create role definition *deploy_edit*
ClusterRole-pod-editor.yaml
```
kind: ClusterRole  
apiVersion: rbac.authorization.k8s.io/v1  
metadata:  
  name: deploy-pod-editor
rules:  
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
```

Role binding for *deploy_edit*
ClusterRoleBinding-pod-editor.yaml
```
kind: ClusterRoleBinding  
apiVersion: rbac.authorization.k8s.io/v1  
metadata:  
  name: deploy-pod-editor
subjects:  
- kind: User
  name: deploy_edit
  apiGroup: rbac.authorization.k8s.io
roleRef:  
  kind: ClusterRole
  name: deploy-pod-editor
  apiGroup: rbac.authorization.k8s.io
```

## Homework 4.2
Create namespace prod. Create users prod_admin, prod_view. Give the user prod_admin admin rights on ns prod, give the user prod_view only view rights on namespace prod.

#### Create namespace prod
```
kubectl create namespace prod
```

Here is my simple bash script for generate X.509 certificate

#### create_user_certificate.sh
```
#!/bin/bash

# Script for create kubernetes user certifcate

KUBE_NEW_USER=$1


echo Generate CSR
openssl genrsa -out "${KUBE_NEW_USER}.key" 2048
openssl req -new -key "${KUBE_NEW_USER}.key" -out "${KUBE_NEW_USER}.csr" -subj "/CN=${KUBE_NEW_USER} /O=${KUBE_NEW_USER}_group"

echo Make template
sed 's/__CERT_REQ__/'"$(cat "${KUBE_NEW_USER}".csr | base64 | tr -d '\n')"'/g' cert-sign-request-template.yaml | sed 's/k8s_user/'${KUBE_NEW_USER}'/g' > "cert-sign-request-user-${KUBE_NEW_USER}.yaml"

echo Issue request
kubectl apply -f "cert-sign-request-user-${KUBE_NEW_USER}.yaml"

echo Approve request
kubectl certificate approve ${KUBE_NEW_USER}

echo Get signed certificate from Kubernetes API
kubectl get csr ${KUBE_NEW_USER} -o jsonpath='{.status.certificate}' | base64 -d > "${KUBE_NEW_USER}.crt"
openssl x509 -in "${KUBE_NEW_USER}.crt" -text
```

Generate users *prod_admin* and *prod_view* via script
```
./create_user_certificate.sh prod_admin
./create_user_certificate.sh prod_view
```

Import user certificates into config
```
kubectl config set-credentials prod_admin --client-key prod_admin.key --client-certificate prod_admin.crt --embed-certs
kubectl config set-credentials prod_view --client-key prod_view.key --client-certificate prod_view.crt --embed-certs
```

Create and bind contexts for users 
```
kubectl config set-context prod_admin --cluster docker-desktop --user prod_admin --namespace prod
kubectl config set-context prod_view --cluster docker-desktop --user prod_view --namespace prod
kubectl config view
```


#### Create role and binding

## NB! By task description we need to restrict user operations by one namespace *prod*. In this case we must use _ClusterRole_ object for referencing to admin and view rights and _RoleBinding_ object for referencing to namespace *prod*. Also we can use cluster internal *admin* and *view* _ClusterRole_ objects, but for simple example (not for production) we create new one for each user.


### Task:  Give the user *prod_admin* admin rights on ns *prod*.
Create role and binding for *prod_admin*

ClusterRole-prod-admin.yaml
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admin-ns-prod
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```


RoleBinding-prod_admin.yaml
```
kind: RoleBinding  
apiVersion: rbac.authorization.k8s.io/v1  
metadata:  
  name: prod-admin-user-binding
  namespace: prod
subjects:  
- kind: User
  name: prod_admin
  apiGroup: rbac.authorization.k8s.io
roleRef:  
  kind: ClusterRole
  name: admin-ns-prod
  apiGroup: rbac.authorization.k8s.io
```

#### Create and bind role to user and namespace
```
kubctl apply -f ClusterRole-prod-admin.yaml
kubctl apply -f RoleBinding-prod_admin.yaml
```

### Task: give the user *prod_view* only view rights on namespace *prod*

Create role and binding for *prod_view*
ClusterRole-prod-view.yaml
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-ns-prod
rules:  
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

RoleBinding-prod_view.yaml
```
kind: RoleBinding  
apiVersion: rbac.authorization.k8s.io/v1  
metadata:  
  name: prod-view-user-binding
  namespace: prod
subjects:  
- kind: User
  name: prod_view
  apiGroup: rbac.authorization.k8s.io
roleRef:  
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

#### Create and bind role to user and namespace
```
kubctl apply -f ClusterRole-prod-view.yaml
kubctl apply -f RoleBinding-prod_view.yaml
```
