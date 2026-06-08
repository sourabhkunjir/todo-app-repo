pipeline {
  agent any

  environment {
    AWS_REGION     = 'eu-north-1'
    AWS_ACCOUNT_ID = '378898677985'
    EKS_CLUSTER    = 'todo-app-prod'
    ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ECR_BACKEND    = "${ECR_REGISTRY}/todo-app-prod-backend"
    ECR_FRONTEND   = "${ECR_REGISTRY}/todo-app-prod-frontend"
    K8S_NAMESPACE  = 'todo-app'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.IMAGE_TAG = env.GIT_COMMIT.take(7)
        }
      }
    }

    stage('ECR Login') {
      steps {
        sh '''
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$ECR_REGISTRY"
        '''
      }
    }

    stage('Build Backend') {
      steps {
        sh '''
          docker build -t "$ECR_BACKEND:$IMAGE_TAG" -t "$ECR_BACKEND:latest" backend/
          docker push "$ECR_BACKEND:$IMAGE_TAG"
          docker push "$ECR_BACKEND:latest"
        '''
      }
    }

    stage('Build Frontend') {
      steps {
        sh '''
          docker build -t "$ECR_FRONTEND:$IMAGE_TAG" -t "$ECR_FRONTEND:latest" frontend/
          docker push "$ECR_FRONTEND:$IMAGE_TAG"
          docker push "$ECR_FRONTEND:latest"
        '''
      }
    }

    stage('Deploy to EKS') {
      steps {
        sh '''
          aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"

          kubectl set image deployment/backend \
            backend="$ECR_BACKEND:$IMAGE_TAG" \
            -n "$K8S_NAMESPACE"

          kubectl set image deployment/frontend \
            frontend="$ECR_FRONTEND:$IMAGE_TAG" \
            -n "$K8S_NAMESPACE"

          kubectl rollout status deployment/backend -n "$K8S_NAMESPACE" --timeout=300s
          kubectl rollout status deployment/frontend -n "$K8S_NAMESPACE" --timeout=300s
        '''
      }
    }

    stage('Update CORS') {
      steps {
        sh '''
          NLB=$(kubectl get svc frontend -n "$K8S_NAMESPACE" \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

          MONGODB_URI=$(kubectl get secret todo-app-secrets -n "$K8S_NAMESPACE" \
            -o jsonpath='{.data.MONGODB_URI}' | base64 -d)

          kubectl create secret generic todo-app-secrets -n "$K8S_NAMESPACE" \
            --from-literal=MONGODB_URI="$MONGODB_URI" \
            --from-literal=FRONTEND_URL="http://${NLB}" \
            --dry-run=client -o yaml | kubectl apply -f -

          kubectl rollout restart deployment/backend -n "$K8S_NAMESPACE"
          kubectl rollout status deployment/backend -n "$K8S_NAMESPACE" --timeout=180s
        '''
      }
    }

    stage('Smoke Test') {
      steps {
        sh '''
          NLB=$(kubectl get svc frontend -n "$K8S_NAMESPACE" \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

          echo "App URL: http://${NLB}/"
          curl -fsS "http://${NLB}/api/health"
          echo ""
          echo "Smoke test passed"
        '''
      }
    }
  }

  post {
    success {
      echo "Deployed todo-app tag ${IMAGE_TAG} to EKS"
    }
    failure {
      echo "Pipeline failed — check console output above"
    }
    always {
      sh 'docker image prune -f || true'
    }
  }
}
