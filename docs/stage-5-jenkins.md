# Stage 5 — Jenkins pipeline + GitHub webhook

## One-time on Jenkins EC2

```bash
cd ~/todo-app-repo
git pull
sudo bash scripts/prepare-jenkins-pipeline.sh
```

## Jenkins UI (http://51.20.171.84:8080)

### 1. Install plugins

**Manage Jenkins → Plugins → Available**

- GitHub
- GitHub Branch Source (optional)
- Pipeline
- Docker Pipeline

Restart Jenkins if prompted.

### 2. Create Pipeline job

1. **New Item** → name: `todo-app-deploy` → **Pipeline** → OK
2. **Build Triggers** → check **GitHub hook trigger for GITScm polling**
3. **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/sourabhkunjir/todo-app-repo.git`
   - Credentials: add GitHub PAT if repo is private (Username + Token)
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
4. **Save**

### 3. First manual run

Click **Build Now** and watch **Console Output**.

Expected stages: Checkout → ECR Login → Build → Deploy → Smoke Test.

## GitHub webhook

**GitHub repo → Settings → Webhooks → Add webhook**

| Field | Value |
|-------|--------|
| Payload URL | `http://51.20.171.84:8080/github-webhook/` |
| Content type | `application/json` |
| Events | Just the **push** event |

Save. Push to `main` should auto-trigger the job.

## After success

```bash
kubectl get pods -n todo-app
kubectl get svc frontend -n todo-app
```

Open the NLB URL in browser — todo app should load.

## Troubleshoot

| Problem | Fix |
|---------|-----|
| `permission denied` on docker | Run `prepare-jenkins-pipeline.sh`, restart Jenkins |
| `kubectl: command not found` | Install kubectl for jenkins user or run prepare script as root |
| ECR login failed | EC2 instance profile needs ECR permissions (terraform) |
| ImagePullBackOff after deploy | Check ECR images exist: `aws ecr list-images --repository-name todo-app-prod-backend` |
