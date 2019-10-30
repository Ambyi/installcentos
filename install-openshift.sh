#!/bin/bash

## see: https://youtu.be/aqXSbDZggK4

## Default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export PVS=${INTERACTIVE:="true"}
#export DOMAIN=${DOMAIN:="$(curl -s ipinfo.io/ip).nip.io"}
export DOMAIN=${DOMAIN:="echo $HOSTNAME"}
export USERNAME=${USERNAME:="$(whoami)"}
export PASSWORD=${PASSWORD:=password}
export VERSION=${VERSION:="3.11"}
export SCRIPT_REPO=${SCRIPT_REPO:="https://github.com/Ambyi/installcentos/blob/master"}
export ip=${ip:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}')"}
export API_PORT=${API_PORT:="8443"}
export LETSENCRYPT=${LETSENCRYPT:="false"}
export MAIL=${MAIL:="example@email.com"}
export DISK=${DISK:="/dev/vdc"}

## Make the script interactive to set the variables
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Domain to use: ($DOMAIN): " choice;
	if [ "$choice" != "" ] ; then
		export DOMAIN="$choice";
	fi

# 	read -rp "Username: ($USERNAME): " choice;
# 	if [ "$choice" != "" ] ; then
# 		export USERNAME="$choice";
# 	fi

# 	read -rp "Password: ($PASSWORD): " choice;
# 	if [ "$choice" != "" ] ; then
# 		export PASSWORD="$choice";
# 	fi

# 	read -rp "OpenShift Version: ($VERSION): " choice;
# 	if [ "$choice" != "" ] ; then
# 		export VERSION="$choice";
# 	fi
# 	read -rp "IP: ($IP): " choice;
# 	if [ "$choice" != "" ] ; then
# 		export IP="$choice";
# 	fi

# 	read -rp "API Port: ($API_PORT): " choice;
# 	if [ "$choice" != "" ] ; then
# 		export API_PORT="$choice";
# 	fi 

# 	echo "Do you wish to enable HTTPS with Let's Encrypt?"
# 	echo "Warnings: " 
# 	echo "  Let's Encrypt only works if the IP is using publicly accessible IP and custom certificates."
# 	echo "  This feature doesn't work with OpenShift CLI for now."
# 	select yn in "Yes" "No"; do
# 		case $yn in
# 			Yes) export LETSENCRYPT=true; break;;
# 			No) export LETSENCRYPT=false; break;;
# 			*) echo "Please select Yes or No.";;
# 		esac
# 	done
	
# 	if [ "$LETSENCRYPT" = true ] ; then
# 		read -rp "Email(required for Let's Encrypt): ($MAIL): " choice;
# 		if [ "$choice" != "" ] ; then
# 			export MAIL="$choice";
# 		fi
# 	fi
	
# 	echo

fi

echo "******"
# echo "* Your domain is $DOMAIN "
# echo "* Your IP is $ip "
# echo "* Your username is $USERNAME "
# echo "* Your password is $PASSWORD "
# echo "* OpenShift version: $VERSION "
# echo "* Enable HTTPS with Let's Encrypt: $LETSENCRYPT "
# if [ "$LETSENCRYPT" = true ] ; then
# 	echo "* Your email is $MAIL "
# fi
echo "******"


cd /tmp

#the EPEL repository globally so that is not accidentally used during later steps of the installation
sudo wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
ls *.rpm
sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# Disable the EPEL repository globally so that is not accidentally used during later steps of the installation

sudo sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo
# sudo wget https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.8.5-1.el7.ans.noarch.rpm
# ls *.rpm
# curl -o ansible.rpm https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.8.5-1.el7.ans.noarch.rpm
#yum -y --enablerepo=epel install ansible.rpm
sudo yum -y remove ansible
sudo rpm -Uvh https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.8.5-1.el7.ans.noarch.rpm
ansible --version
#sudo yum update -y
# [ ! -d openshift-ansible ] && git clone https://github.com/openshift/openshift-ansible.git -b release-${VERSION} --depth=1

echo "******  openshift-ansible.git ${VERSION}  "
sudo chmod 777 /etc/ansible/hosts 
for s in  10.80.4.117 10.80.4.118 10.80.4.122;
do
   echo $s 
done > /etc/ansible/hosts

# Generate SSH Key on master machine and copy key on Compute and Infra
# ssh-keygen
# for host in 10.80.4.117  \
#             10.80.4.118; \
#       do ssh-copy-id -i ~/.ssh/id_rsa.pub $host; \
# done
# cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
# sudo cat <<EOD > /etc/hosts
# 127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 
# ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# ${ip}		$(hostname) console console.${DOMAIN}
# 10.80.4.117
# 10.80.4.118
# EOD
sudo rm -r docker

ansible -m ping all

sudo git clone https://github.com/Ambyi/docker.git


ansible-playbook docker/install_docker_okd_shell.yml --syntax-check -vvvv
ansible-playbook docker/install_docker_okd_shell.yml -vvvv
#ansible-playbook docker/install_docker_okd_shell.yml 

if [ -z $DISK ]; then 
	echo "Not setting the Docker storage."
else
	sudo cp /etc/sysconfig/docker-storage-setup /etc/sysconfig/docker-storage-setup.bk

	echo DEVS=$DISK > /etc/sysconfig/docker-storage-setup
	echo VG=DOCKER >> /etc/sysconfig/docker-storage-setup
	echo SETUP_LVM_THIN_POOL=yes >> /etc/sysconfig/docker-storage-setup
	echo DATA_SIZE="100%FREE" >> /etc/sysconfig/docker-storage-setup

	sudo systemctl stop docker

	#rm -rf /var/lib/docker
	#wipefs --all $DISK
	#docker-storage-setup
fi

# systemctl restart docker
# systemctl enable docker

# if [ ! -f ~/.ssh/id_rsa ]; then
# 	ssh-keygen -q -f ~/.ssh/id_rsa -N ""
# 	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
# 	ssh -o StrictHostKeyChecking=no root@$ip "pwd" < /dev/null
# fi

export METRICS="True"
export LOGGING="True"

memory=$(cat /proc/meminfo | grep MemTotal | sed "s/MemTotal:[ ]*\([0-9]*\) kB/\1/")

if [ "$memory" -lt "4194304" ]; then
	export METRICS="False"
fi

if [ "$memory" -lt "16777216" ]; then
	export LOGGING="False"
fi



echo "******  inventory.download $SCRIPT_REPO/inventory.ini ${SCRIPT_REPO}  "
# add proxy in inventory.ini if proxy variables are set

cd /tmp

sudo rm -r /tmp/inventory.ini
sudo rm -r /tmp/tempMaster.ini
sudo rm -r /tmp/tempetcd.ini
sudo rm -r /tmp/tempnodes.ini

sudo cp /home/ec2-user/installcentos/inventory.ini /tmp/inventory.ini

sudo touch tempMaster.ini
sudo touch tempetcd.ini
sudo touch tempinfra.ini
sudo touch tempnodes.ini

sudo chmod 777 /tmp/inventory.ini 
sudo chmod 777 /tmp/tempMaster.ini
sudo chmod 777 /tmp/tempetcd.ini
sudo chmod 777 /tmp/tempinfra.ini
sudo chmod 777 /tmp/tempnodes.ini

sudo touch temp.ini

	echo "* Your IP is ${ip} ${DOMAIN}"
	echo "*****************************************************inventory.ini update**********************" 
for s in 10.80.4.117 10.80.4.118;
do
  ssh $s hostname
done > tempMaster.ini;

for s in 10.80.4.117 10.80.4.118;
do
  ssh $s hostname
done > tempetcd.ini;

for s in 10.80.4.117 10.80.4.118;
do
  ssh $s hostname
done > tempinfra.ini;

for s in 10.80.4.117 10.80.4.118;
do
  ssh $s hostname
done > tempnodes.ini;


#### Write inventory file 


while read line
do
        echo $line  >> tempMaster.ini
done < inventory.ini;

##### host group for etcd ####
#[etcd]

cat <<EOT > inventory.ini
##### host group for etcd ####
[etcd]
EOT

while read line
do
        echo $line  >> tempetcd.ini
done < inventory.ini;

##### host group for infra ####
#[infra]
cat <<EOT > inventory.ini
##### host group for infra ####
[infra]
EOT

while read line
do
        echo $line  >> tempinfra.ini
done < inventory.ini;

#### host group for nodes, includes region info
#[nodes]
cat <<EOT > inventory.ini
##### host group for nodes #### 
[nodes]
EOT

while read line
do
        echo "$line    openshift_node_group_name='node-config-master'"  >> tempnodes.ini
done < inventory.ini;

# 	cat <<EOT >> inventory.ini
	
# 	openshift_master_overwrite_named_certificates=true
	
# 	openshift_master_cluster_hostname=console-internal.${DOMAIN}
# 	openshift_master_cluster_public_hostname=console.${DOMAIN}
	
# 	openshift_master_named_certificates=[{"certfile": "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem", "keyfile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem", "cafile": "/etc/letsencrypt/live/${DOMAIN}/chain.pem", "names": ["console.${DOMAIN}"]}]
	
# 	openshift_hosted_router_certificate={"certfile": "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem", "keyfile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem", "cafile": "/etc/letsencrypt/live/${DOMAIN}/chain.pem"}
	
# 	openshift_hosted_registry_routehost=registry.apps.${DOMAIN}
# 	openshift_hosted_registry_routecertificates={"certfile": "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem", "keyfile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem", "cafile": "/etc/letsencrypt/live/${DOMAIN}/chain.pem"}
# 	openshift_hosted_registry_routetermination=reencrypt
# EOT
	
	# Add Cron Task to renew certificate
# 	echo "@weekly  certbot renew --pre-hook=\"oc scale --replicas=0 dc router\" --post-hook=\"oc scale --replicas=1 dc router\"" > certbotcron
# 	crontab certbotcron
# 	rm certbotcron
#fi

# Checkout Origin 3.11 release 
# cd openshift-ansible && git fetch && git checkout release-3.11 && cd ..
# -----------------------------------------------------
# # confirm selinux setting on Master,Compute,Infra
# vi /etc/selinux/config
# SELINUX=enforcing
# SELINUXTYPE=targeted

# 	echo "*****************************************************inventory.ini update**********************" 
# mkdir -p /etc/origin/master/
# chmod 777 /etc/origin/master
# touch /etc/origin/master/htpasswd
# 	echo "*****************************************************start run ansible **********************" 
# 	echo  ${PWD=pwd}  ${ip}
# 	echo "@@@@@@@@@git clone https://github.com/openshift/openshift-ansible.git###@@@@@@@@@@@"  
# 	#cd /root/installcentos
# 	echo  ${PWD=pwd}  ${ip}
# 	  #git clone https://github.com/openshift/openshift-ansible.git
# 	  echo "*****************************************************start run ansible **********************" 
# 	echo  ${PWD=pwd} ${ip}
# 	echo "* Your IP is $ip ******${ip}***** $"
	
# 	DOMAIN = ip-10-80-4-122.eu-west-2.compute.internal

# ansible-playbook -i inventory.ini openshift-ansible/playbooks/prerequisites.yml -vvvv
# ansible-playbook -i inventory.ini openshift-ansible/playbooks/deploy_cluster.yml -vvvv

# htpasswd -b /etc/origin/master/htpasswd ${USERNAME} ${PASSWORD}
# oc adm policy add-cluster-role-to-user cluster-admin ${USERNAME}

# if [ "$PVS" = "true" ]; then

# 	curl -o vol.yaml $SCRIPT_REPO/vol.yaml

# 	for i in `seq 1 200`;
# 	do
# 		DIRNAME="vol$i"
# 		mkdir -p /mnt/data/$DIRNAME 
# 		chcon -Rt svirt_sandbox_file_t /mnt/data/$DIRNAME
# 		chmod 777 /mnt/data/$DIRNAME
		
# 		sed "s/name: vol/name: vol$i/g" vol.yaml > oc_vol.yaml
# 		sed -i "s/path: \/mnt\/data\/vol/path: \/mnt\/data\/vol$i/g" oc_vol.yaml
# 		oc create -f oc_vol.yaml
# 		echo "created volume $i"
# 	done
# 	rm oc_vol.yaml
# fi

echo "******"
# echo "* Your IP is $IP "
# echo "* Your console is https://console.$DOMAIN:$API_PORT"
# echo "* Your username is $USERNAME "
# echo "* Your password is $PASSWORD "
# echo "*"
# echo "* Login using:"
# echo "*"
# echo "$ oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:$API_PORT/"
echo "******"

#oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:$API_PORT/
