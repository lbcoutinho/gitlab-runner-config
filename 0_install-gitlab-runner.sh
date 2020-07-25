#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AWS_REGION=us-east-1
# Name of the SSH key pair that is going to be generated and imported to AWS during the setup
KEY_PAIR_NAME=gitlab-runner_${INSTANCE_ID}
KEY_PAIR_PATH=~/${KEY_PAIR_NAME}

####################################################################################################################################################################

echo -ne "[TASK 1] Installing Docker...\n"
echo -ne "[                                                                                                       0% ]"
sudo yum install -y yum-utils device-mapper-persistent-data lvm2 > /dev/null 2>&1
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
sudo yum install -y docker-ce > /dev/null 2>&1
sudo systemctl enable docker > /dev/null 2>&1
sudo systemctl start docker > /dev/null 2>&1

echo -ne "\r\e[0K[TASK 2] Installing Docker Machine...\n"
echo -ne "[####################                                                                                  20% ]"
sudo curl -sL https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-$(uname -s)-$(uname -m) > /tmp/docker-machine
chmod +x /tmp/docker-machine
sudo mv /tmp/docker-machine /usr/local/bin/docker-machine
sudo cp /usr/local/bin/docker-machine /usr/bin/docker-machine
  
echo -ne "\r\e[0K[TASK 3] Installing Gilab Runner repository...\n"
echo -ne "[########################################                                                              40% ]"
curl -sL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | sudo bash > /dev/null 2>&1
  
echo -ne "\r\e[0K[TASK 4] Installing Gitlab Runner...\n"
echo -ne "[############################################################                                          60% ]"
sudo yum install -y gitlab-runner > /dev/null 2>&1

echo -ne "\r\e[0K[TASK 5] Installing AWS CLI...\n"
echo -ne "[################################################################################                      80% ]"
sudo yum install -y awscli > /dev/null 2>&1

echo -ne "\r\e[0K[TASK 6] Generating Key Pair and importing to AWS...\n"
echo -ne "[############################################################################################          90% ]"
# The generated key pair is imported to AWS an assigned to the created runner instances
# Using this key, the Runner Manager instance and the system admin can access the runners via SSH
sudo ssh-keygen -t rsa -b 2048 -f ${KEY_PAIR_PATH} -q -N ""
aws ec2 import-key-pair --key-name ${KEY_PAIR_NAME} --public-key-material file://${KEY_PAIR_PATH}.pub --region ${AWS_REGION} > /dev/null 2>&1
sudo cp ${KEY_PAIR_PATH}* /root/.ssh
# Update permission of keys left at home dir to allow coping to local computer
# Use SCP on local computer to download the keys, ex: scp -i ~/.ssh/my-key.pem my-user@10.254.150.14:/home/my-user/gitlab-runner* ~/.ssh
sudo chmod 644 ${KEY_PAIR_PATH}*
echo -ne "\r\e[0K\nSSH key to access created runner machines is located at ${KEY_PAIR_PATH}\n"
echo -ne "Download the key to your computer using SCP and update the key permission to 600 to be able to use it.\n"

echo -ne "[#################################################################################################### 100% ]"
sleep 1
echo -ne "\r\e[0K\nDone!\n"