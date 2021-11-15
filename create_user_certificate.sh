#!/bin/bash

# Script for create kubernetes user certifcate

KUBE_NEW_USER=$1


echo Generate CSR
openssl genrsa -out "${KUBE_NEW_USER}.key" 2048
openssl req -new -key "${KUBE_NEW_USER}.key" -out "${KUBE_NEW_USER}.csr" -subj "/CN=${KUBE_NEW_USER}/O=${KUBE_NEW_USER}_group"

echo Make template
sed 's/__CERT_REQ__/'"$(cat "${KUBE_NEW_USER}".csr | base64 | tr -d '\n')"'/g' cert-sign-request-template.yaml | sed 's/k8s_user/'${KUBE_NEW_USER}'/g' > "cert-sign-request-user-${KUBE_NEW_USER}.yaml"

echo Issue request
kubectl apply -f "cert-sign-request-user-${KUBE_NEW_USER}.yaml"

echo Approve request
kubectl certificate approve ${KUBE_NEW_USER}

echo Get signed certificate from Kubernetes API
kubectl get csr ${KUBE_NEW_USER} -o jsonpath='{.status.certificate}' | base64 -d > "${KUBE_NEW_USER}.crt"
openssl x509 -in "${KUBE_NEW_USER}.crt" -text

