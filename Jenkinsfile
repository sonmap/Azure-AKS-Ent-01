pipeline {
  agent any

  environment {
    ACR_NAME = 'acraksent01dev'
    ACR_LOGIN_SERVER = "${ACR_NAME}.azurecr.io"
    IMAGE_TAG = "${BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Azure Login') {
      steps {
        withCredentials([azureServicePrincipal(
          credentialsId: 'azure-service-principal',
          subscriptionIdVariable: 'AZURE_SUBSCRIPTION_ID',
          clientIdVariable: 'AZURE_CLIENT_ID',
          clientSecretVariable: 'AZURE_CLIENT_SECRET',
          tenantIdVariable: 'AZURE_TENANT_ID'
        )]) {
          sh '''
            az login --service-principal \
              --username "$AZURE_CLIENT_ID" \
              --password "$AZURE_CLIENT_SECRET" \
              --tenant "$AZURE_TENANT_ID"
            az account set --subscription "$AZURE_SUBSCRIPTION_ID"
            az acr login --name "$ACR_NAME"
          '''
        }
      }
    }

    stage('Build and Push') {
      steps {
        sh '''
          docker build -t "$ACR_LOGIN_SERVER/tc01/apache:$IMAGE_TAG" apps/legacy-app/apache
          docker build -t "$ACR_LOGIN_SERVER/tc01/tomcat:$IMAGE_TAG" apps/legacy-app/tomcat
          docker push "$ACR_LOGIN_SERVER/tc01/apache:$IMAGE_TAG"
          docker push "$ACR_LOGIN_SERVER/tc01/tomcat:$IMAGE_TAG"
        '''
      }
    }

    stage('Prepare Manifest') {
      steps {
        sh '''
          sed "s#ACR_LOGIN_SERVER/tc01/apache:v1.0#$ACR_LOGIN_SERVER/tc01/apache:$IMAGE_TAG#g; \
               s#ACR_LOGIN_SERVER/tc01/tomcat:v1.0#$ACR_LOGIN_SERVER/tc01/tomcat:$IMAGE_TAG#g" \
            deploy/tc01/legacy-stack.yaml > deploy/tc01/legacy-stack.rendered.yaml
        '''
      }
    }

    stage('Deploy to AKS') {
      when { branch 'main' }
      steps {
        sh '''
          az aks get-credentials \
            --resource-group rg-aks-ent01-dev-krc \
            --name aks-aks-ent01-dev-krc \
            --overwrite-existing
          kubectl apply -f deploy/tc01/legacy-stack.rendered.yaml
          kubectl rollout status deployment/apache -n tc01 --timeout=180s
          kubectl rollout status deployment/tomcat -n tc01 --timeout=180s
        '''
      }
    }
  }
}
