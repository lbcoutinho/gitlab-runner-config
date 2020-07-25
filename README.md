# GitLab Runner Config
 
This repo contains the scripts required to install and configure the GitLab Runner in autoscaling mode.

## 0_install-gitlab-runner.sh

This script installs Docker, Docker Machine and the GitLab Runner leaving those ready to register GitLab runners.
* The user running the script needs sudo permission.
* The script was tested using an AWS EC2 running CentOS 7 (t3a.nano).
* If you are using a different Linux distribution, then review the "yum install" commands.
* If you are using a cloud provider different from AWS, then update the key pair import on TASK 6.

The instance where the GitLab Runner is being installed is going to be responsible only for receiving the job execution requests and create/terminate the instances that are going to run the job. Therefore, this instance does not have to be large in processing and RAM capacity.

**IMPORTANT**

Create an IAM Role with full access to EC2 e S3 and assign it to the instance where you're installing the GitLab Runner.  
These permissions are required for the instance to be able to upload the generated public key to AWS, create/terminate EC2 instances and upload/download the cache to S3.

## 1_register-runner-autoscaler.sh

This script prepares a configuration template with autoscaling parameters and register the configuration on GitLab.

### Before starting

Create an AWS S3 Bucket to store the runners' shared cache.  
You can set up a Lifecycle Rule in the S3 bucket to delete caches after a few days. This is more important if you are storing cache by branch and branches are deleted after the merge.

### Setup the variables accourding to your environment

At the start of the script, there are several variables that must be set to adapt the script to the AWS environment in use.
* AWS_REGION, VPC_ID, SUBNET_ID, SECURITY_GROUP, CACHE_S3_BUCKET: values from AWS
* GITLAB_URL, GITLAB_RUNNER_REGISTRATION_TOKEN: Used to register the runner. It can be found on GitLab settings > CI/CD > Runners
* Changing the other variables is optional

**IMPORTANT**

The security group in use must allow inbound access to the ports 22 and 2376.

### Standard runner configuration

* The template configuration is prepared to create a Runner in autoscaling mode in AWS.
* It uses the GitLab executor "docker+machine", which allows the GitLab Runner Manager to create EC2 instances to run jobs and terminate these instances after a while.
* The type of the instances created can be configured on the variable INSTANCE_TYPE. By default, it creates t3a.small instances (2 vCPU and 2GB RAM).
* The instances are created as Spot Instances which can offer a price discount of up to 90% when compared to on-demand instances (https://aws.amazon.com/pt/ec2/spot/).
* The Runner won't keep idle instances waiting for jobs, instead when a job is triggered a new instances is created at this moment. The machine start up time is around 2-3 minutes.
* After finishing running the job, the instance will be kept alive waiting for new jobs for 30 minutes. This idle time setup is valid from Monday to Friday from 9AM to 6PM (Brazil Time). At any other time, the instances will be kept alive only for 5 minutes.
* You can change the instances autoscaling and idle time on the section "runners.machine.autoscaling".
* The Runner will created at most 5 instances to run jobs. In case the 5 instances created are busy running jobs, the next jobs are going to wait on queue.

## Debugging GitLab Runner

Below are some useful commands to debug the execution of the GitLab Runner and the created instances.

* List configured runners: `sudo gitlab-runner list`
* Unregister all runners: `sudo gitlab-runner unregister --all-runners`
* Unregister single runner (token can be found using "gitlab-runner list"): `sudo gitlab-runner unregister -t <token>`
* GitLab Runner logs: `journalctl -u gitlab-runner`
* List created instances: `sudo docker-machine ls`
* SSH into created instance (instance-name can be found using "docker-machine ls"): `sudo docker-machine ssh <instance-name>`

**OBS**: You can SSH into the instances using the user `ubuntu` and a private key located at the home directory of the GitLab Runner Manager instance.

## References

Installation:
* https://docs.docker.com/engine/install/centos/
* https://docs.docker.com/machine/install-machine/
* https://docs.gitlab.com/runner/install/linux-repository.html

Configuration:
* https://docs.gitlab.com/runner/configuration/runner_autoscale_aws/
* https://docs.gitlab.com/runner/configuration/autoscale.html
* https://docs.gitlab.com/runner/configuration/advanced-configuration.html
* https://docs.docker.com/machine/drivers/aws/
* https://docs.gitlab.com/runner/executors/docker_machine.html
