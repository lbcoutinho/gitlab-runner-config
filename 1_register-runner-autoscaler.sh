#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
#----------------------------------------------------------------------------------- From AWS
AWS_REGION=us-east-1
VPC_ID=vpc-0315e33c74d26
SUBNET_ID=subnet-0ea2f17ffd8fe
# The security group must allow inbound access to the ports 22 and 2376
SECURITY_GROUP=SERVICES
CACHE_S3_BUCKET=gitlab-runner-cache.example.com
#----------------------------------------------------------------------------------- From GitLab > Settings > CI/CD > Runners
GITLAB_URL=https://git.mycompany.com/
GITLAB_RUNNER_REGISTRATION_TOKEN=uqVxB1fMyf8LxxtM
#----------------------------------------------------------------------------------- Changes on the vars below are optional
# Name that will show up on GitLab CI/CD page when Runner is registered
RUNNER_NAME=runner-autoscaler-${INSTANCE_ID}
# Comma separated tags to be associated with the Runner. Runner is going to run only job with these tags
RUNNER_TAGS=runner
# Path to the Runner configuration template
RUNNER_TEMPLATE_CONFIG_PATH=~/runner-template-config.toml
# Name of the SSH key pair generated and imported to AWS by the GitLab Runner installation script
KEY_PAIR_NAME=gitlab-runner_${INSTANCE_ID}
# Type of the instances that are going to be created/terminated to run jobs
# Instance types and pricing: https://aws.amazon.com/pt/ec2/spot/pricing/
INSTANCE_TYPE=t3a.small

####################################################################################################################################################################

echo "[TASK 1] Preparing Runner template config..."
cat << EOF > ${RUNNER_TEMPLATE_CONFIG_PATH}
[[runners]]
  name = "${RUNNER_NAME}"
  url = "${GITLAB_URL}"
  executor = "docker+machine"
  limit = 5
  [runners.docker]
    image = "alpine"
    privileged = true
    disable_cache = true
  [runners.cache]
    Type = "s3"
    Shared = true
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "${CACHE_S3_BUCKET}"
      BucketLocation = "${AWS_REGION}"
  [runners.machine]
    IdleCount = 0 # How many instance to keep idle waiting for jobs
    IdleTime = 300 # 5min - How much time (in seconds) an instance that finished running a job will be kept idle waiting for new jobs
    MaxBuilds = 100 # How many builds an instances can run before shutdown
    MachineDriver = "amazonec2"
    MachineName = "${INSTANCE_ID}-machine-%s"
    MachineOptions = [
      # Network
      "amazonec2-region=${AWS_REGION}",
      "amazonec2-vpc-id=${VPC_ID}",
      "amazonec2-subnet-id=${SUBNET_ID}",
      "amazonec2-security-group=${SECURITY_GROUP}",
      "amazonec2-use-private-address=true",
      "amazonec2-private-address-only=true",
      # Launch type
      "amazonec2-request-spot-instance=true",
      "amazonec2-spot-price=", # Leave empty to set the price equals to the default On-Demand price of that instance class
      "amazonec2-instance-type=${INSTANCE_TYPE}",
      "amazonec2-ssh-user=ubuntu", # User must match the default SSH user set in the AMI being used. Default AMI is Ubuntu = ami-927185ef 
      # SSH
      "amazonec2-ssh-keypath=/root/.ssh/${KEY_PAIR_NAME}",
      "amazonec2-keypair-name=${KEY_PAIR_NAME}",
      # Tags  
      "amazonec2-tags=Project,runner"
    ]
    [[runners.machine.autoscaling]]
      Periods = ["* * 12-21 * * mon-fri *"] # 9-18 BRT
      IdleCount = 0
      IdleTime = 1800 # 30min
      Timezone = "UTC"
EOF
sleep 1

echo "[TASK 2] Registering Gitlab Runner..."
sudo gitlab-runner register --non-interactive \
  --template-config ${RUNNER_TEMPLATE_CONFIG_PATH} \
  --name ${RUNNER_NAME} \
  --url ${GITLAB_URL} \
  --registration-token ${GITLAB_RUNNER_REGISTRATION_TOKEN} \
  --request-concurrency 5 \
  --executor docker+machine \
  --docker-image alpine:latest \
  --tag-list ${RUNNER_TAGS}

echo "\nDone!"