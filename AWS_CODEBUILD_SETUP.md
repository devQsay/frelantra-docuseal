# AWS CodeBuild Docker Hub Rate Limit Fix

## Problem
AWS CodeBuild was failing due to Docker Hub rate limiting (429 Too Many Requests).

## Solution 1: Docker Hub Authentication (Recommended)

### Step 1: Create Docker Hub Account (if you don't have one)
1. Go to https://hub.docker.com/signup
2. Create a free account (gives 200 pulls per 6 hours instead of 100)

### Step 2: Store Credentials in AWS Secrets Manager
Run this AWS CLI command to create the secret:

```bash
aws secretsmanager create-secret \
    --name dockerhub-credentials \
    --description "Docker Hub credentials for CodeBuild" \
    --secret-string '{"username":"YOUR_DOCKERHUB_USERNAME","password":"YOUR_DOCKERHUB_PASSWORD"}' \
    --region us-east-1
```

Or use the AWS Console:
1. Go to AWS Secrets Manager in us-east-1 region
2. Click "Store a new secret"
3. Select "Other type of secret"
4. Add two key/value pairs:
   - Key: `username`, Value: your Docker Hub username
   - Key: `password`, Value: your Docker Hub password
5. Name it: `dockerhub-credentials`
6. Click "Next" and "Store"

### Step 3: Update CodeBuild IAM Role
Add this policy to your CodeBuild service role to allow it to read the secret:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:us-east-1:820976529764:secret:dockerhub-credentials*"
        }
    ]
}
```

### Step 4: Push Updated buildspec.yml
The buildspec.yml has been updated to authenticate with Docker Hub before building.

---

## Solution 2: Use AWS ECR Public Gallery (Alternative)

If you don't want to use Docker Hub authentication, you can modify the Dockerfile to use AWS ECR Public Gallery:

### Update Dockerfile to use ECR Public:
Change all instances of:
```dockerfile
FROM ruby:3.4.5-alpine
```

To:
```dockerfile
FROM public.ecr.aws/docker/library/ruby:3.4.5-alpine
```

This uses AWS's public mirror of Docker Hub images and has no rate limiting.

---

## Solution 3: Use Your Own ECR Repository (Most Reliable)

1. Pull the Ruby image locally:
```bash
docker pull ruby:3.4.5-alpine
```

2. Tag it for your ECR:
```bash
docker tag ruby:3.4.5-alpine 820976529764.dkr.ecr.us-east-1.amazonaws.com/ruby:3.4.5-alpine
```

3. Push to your ECR:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 820976529764.dkr.ecr.us-east-1.amazonaws.com
docker push 820976529764.dkr.ecr.us-east-1.amazonaws.com/ruby:3.4.5-alpine
```

4. Update Dockerfile to use your ECR image:
```dockerfile
FROM 820976529764.dkr.ecr.us-east-1.amazonaws.com/ruby:3.4.5-alpine
```

---

## Recommended Approach

**Solution 1 (Docker Hub Authentication)** is the quickest fix and has been implemented in the buildspec.yml. You just need to:
1. Create the secret in AWS Secrets Manager
2. Update the CodeBuild IAM role permissions
3. Push the updated code

Once done, your builds will authenticate with Docker Hub and bypass rate limits.
