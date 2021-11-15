# Task 4
### Check what I can do
```bash
kubectl auth can-i create deployments --namespace kube-system
```
### Sample output
```bash
yes
```
### Configure user authentication using x509 certificates
### Create private key
```bash
openssl genrsa -out k8s_user.key 2048
```
### Create a certificate signing request
```bash
openssl req -new -key k8s_user.key \
-out k8s_user.csr \
-subj "/CN=k8s_user"
```
### Sign the CSR in the Kubernetes CA. We have to use the CA certificate and the key, which are usually in /etc/kubernetes/pki. But since we use minikube, the certificates will be on the host machine in ~/.minikube
```bash
openssl x509 -req -in k8s_user.csr \
-CA ~/.minikube/ca.crt \
-CAkey ~/.minikube/ca.key \
-CAcreateserial \
-out k8s_user.crt -days 500
```
### Create user in kubernetes
```bash
kubectl config set-credentials k8s_user \
--client-certificate=k8s_user.crt \
--client-key=k8s_user.key
```
### Set context for user
```bash
kubectl config set-context k8s_user \
--cluster=kubernetes --user=k8s_user
```
### Edit ~/.kube/config
```bash
Change path
- name: k8s_user
  user:
    client-certificate: C:\Users\Andrey_Trusikhin\educ\k8s_user.crt
    client-key: C:\Users\Andrey_Trusikhin\educ\k8s_user.key
contexts:
- context:
    cluster: minikube
    user: k8s_user
  name: k8s_user
```
### Switch to use new context
```bash
kubectl config use-context k8s_user
```
### Check privileges
```bash
kubectl get node
kubectl get pod
```
### Sample output
```bash
Error from server (Forbidden): pods is forbidden: User "k8s_user" cannot list resource "pods" in API group "" in the namespace "default"
```
### Switch to default(admin) context
```bash
kubectl config use-context minikube
```
### Bind role and clusterrole to the user
```bash
kubectl apply -f binding.yaml
```
### Check output
```bash
kubectl get pod
```
Now we can see pods


### Homework
* Create users deploy_view and deploy_edit. Give the user deploy_view rights only to view deployments, pods. Give the user deploy_edit full rights to the objects deployments, pods.
* Create namespace prod. Create users prod_admin, prod_view. Give the user prod_admin admin rights on ns prod, give the user prod_view only view rights on namespace prod.
* Create a serviceAccount sa-namespace-admin. Grant full rights to namespace default. Create context, authorize using the created sa, check accesses.