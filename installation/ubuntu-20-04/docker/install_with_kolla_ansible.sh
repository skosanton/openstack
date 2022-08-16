# !/bin/bash
# BEFORE EXECUTING THE SCRIPT MAKE SURE YOU HAVE SECOND NETWORK ADAPTER LIKE ETH1 THAT HAS NO IP, BUT ACTIVE.

#ALSO YOU HAVE TO ADD SECOND DISK TO SYSTEM WITH NOTHING ON IT AND CHANGE THE NAMES OF THOSE VOLUMES IN 2 COMMANDS BELOW
lsblk
pvcreate /dev/nvme0n1
vgcreate cinder-volumes /dev/nvme0n1

#ALSO IN activate.env.sh SCRIPT THERE IS A LINE:
#sed -i 's/kolla_internal_vip_address: .*/kolla_internal_vip_address: "10.0.0.233"/' /etc/kolla/globals.yml
#YOU HAVE TO CHANGE IP THERE TO SOME IP IN THE SAME NETWORK AS YOUR LOCAL NETWORK FOR THE SERVER (Ex. THE SAME AS ETH0 INTERFACE'S
#NETWORK. BUT IP SHOULD BE NOT USED BY ANYONE, OR IT WILL FAIL)

#THIS WAS TAKEN FROM https://docs.openstack.org/project-deploy-guide/kolla-ansible/yoga/quickstart.html

echo "disable ipv4"
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash ipv6.disable=1"' >> /etc/default/grub
echo 'GRUB_CMDLINE_LINUX="ipv6.disable=1"' >> /etc/default/grub
update-grub

echo "updating ubuntu"
apt update -y

echo "installing python3-dev libffi-dev gcc libssl-dev"
apt install python3-dev libffi-dev gcc libssl-dev git -y

echo "installing python3-venv and python3-pip"
apt install python3-venv python3-pip -y

echo "creating folder for virtual environment"
mkdir /usr/kolla_python_virt_env

echo "Creating a virtual environment and activating it"
python3 -m venv /usr/kolla_python_virt_env
source ./activate_env.sh
