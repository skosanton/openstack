# !/bin/bash

source /usr/kolla_python_virt_env/bin/activate

echo "Ensuring the latest version of pip is installed"
pip install -U pip

echo "installing Ansible using pip"
pip install 'ansible>=4,<6'

echo "installing kolla and it's dependancies using pip install git+https://opendev.org/openstack/kolla-ansible@stable/yoga"
pip install git+https://opendev.org/openstack/kolla-ansible@stable/yoga

echo "creating /etc/kolla folder"
mkdir -p /etc/kolla

echo "changing user and group owner for /etc/kolla"
chown $USER:$USER /etc/kolla

echo "copying all the files from /usr/kolla_python_virt_env/share/kolla-ansible/etc_examples/kolla/* to/etc/kolla"
cp -r /usr/kolla_python_virt_env/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp /usr/kolla_python_virt_env/share/kolla-ansible/ansible/inventory/* .

#For all-in-one scenario in virtual environment add the following to the very beginning of the inventory:
echo "Adding a line for all-in-one scenario in virtual environment"
sed -i '1s/^/localhost ansible_python_interpreter=python\n/' all-in-one

echo "Installing kolla-ansible dependancies"
kolla-ansible install-deps

echo "Creating Ansible folder and config file if not exist yet"
if ls -la /etc/ansible 2>/dev/null; then : ; else mkdir /etc/ansible ; fi
if ls -la /etc/ansible/ansible.cfg 2>/dev/null; then : ; else ansible-config init --disabled > /etc/ansible/ansible.cfg ; fi
if ls -la /etc/ansible/hosts 2>/dev/null; then : ; else ansible-config init --disabled > /etc/ansible/hosts && echo "$HOSTNAME" > /etc/ansible/hosts; fi

sed -i 's/.host_key_checking.*/host_key_checking=False/' /etc/ansible/ansible.cfg
sed -i 's/.pipelining=.*/pipelining=True/' /etc/ansible/ansible.cfg
sed -i 's/.forks=.*/forks=100/' /etc/ansible/ansible.cfg

echo "checking that ansible config is ok"
ansible -i all-in-one all -m ping

echo "generating passwords for kolla using kolla-genpwd. The passwords gonna be in: /etc/kolla/passwords.yml"
kolla-genpwd

echo "configuring kolla's openstack files"
sed -i 's/.kolla_base_distro:.*/kolla_base_distro: "ubuntu"/' /etc/kolla/globals.yml
sed -i 's/.kolla_install_type:.*/kolla_install_type: "source"/' /etc/kolla/globals.yml
#interface=$(ip route | grep "default via" |sed -r 's/default via [0-9].* dev //g; s/ .*//g')
sed -i 's/.network_interface: .*/network_interface: "wlp5s0"/' /etc/kolla/globals.yml
#interface1=$(echo "$interface" | sed -r 's/0/1/g')
sed -i 's/.neutron_external_interface: .*/neutron_external_interface: "vr-br"/' /etc/kolla/globals.yml
sed -i 's/^#kolla_internal_vip_address: /kolla_internal_vip_address: /' /etc/kolla/globals.yml
sed -i 's/^#enable_openstack_core: .*/enable_openstack_core: "yes"/' /etc/kolla/globals.yml
sed -i 's/^#enable_cinder: .*/enable_cinder: "yes"/' /etc/kolla/globals.yml
sed -i 's/^#enable_cinder_backend_lvm: .*/enable_cinder_backend_lvm: "yes"/' /etc/kolla/globals.yml
sed -i 's/kolla_internal_vip_address: .*/kolla_internal_vip_address: "10.0.0.233"/' /etc/kolla/globals.yml
sed -i 's/#kolla_internal_vip_address: /kolla_internal_vip_address: "/' /etc/kolla/globals.yml
sed -i 's/#network_address_family: .*/network_address_family: "ipv4"/' /etc/kolla/globals.yml
sed -i 's/- { name: "net.ipv6.ip_nonlocal_bind", value: 0 }//' /usr/kolla_python_virt_env/share/kolla-ansible/ansible/roles/loadbalancer/tasks/config-host.yml
sed -i 's/.*"net.ipv6.*//' /usr/kolla_python_virt_env/share/kolla-ansible/ansible/roles/neutron/tasks/config-host.yml
for x in $(find /usr/kolla_python_virt_env/share/kolla-ansible/ansible/roles/ -type f -name "*"); do sed -i 's/^.*net.ipv6.*//' $x ;done

echo "deploying openstack to docker"
kolla-ansible -i ./all-in-one bootstrap-servers > /var/log/kolla-ansible-bootstrap-openstack
kolla-ansible -i ./all-in-one prechecks > /var/log/kolla-ansible-prechecks-openstack
kolla-ansible -i ./all-in-one deploy > /var/log/kolla-ansible-deploy-openstack

echo "installing CLI for Yoga"
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/yoga

echo "creating openrc file where credentials for admin user are set"
kolla-ansible post-deploy
. /etc/kolla/admin-openrc.sh

echo "show password to console"
cat /etc/kolla/admin-openrc.sh

echo 'TO CREATE TEST INSTANCE:


1. Download image:
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

2. Add image to OpenStack:
openstack image create "cirros" \
  --file cirros-0.3.4-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public

3. Create network.
For that get the name flat_networks =    from file:
cat /etc/kolla/neutron-server/ml2_conf.ini
In my case it is physnet1
So Add this name to command below and run it:
openstack network create  --share --external   --provider-physical-network physnet1   --provider-network-type flat physnet1

4. Create a subnet on the network (it is the same network as your real internal one. At least for me it is. So the same as my server):
openstack subnet create --network physnet1 \
  --allocation-pool start=10.0.0.60,end=10.0.0.70 \
  --dns-nameserver 8.8.4.4 --gateway 10.0.0.1 \
  --subnet-range 10.0.0.0/24 physnet1

5. Create a "flavor". It is instance types. Like:
openstack flavor create --id 0 --vcpus 2 --ram 512 --disk 10 m1.micro

6. Create key pair:
ssh-keygen -q -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey

7. Create a volume and attach it to server:
openstack volume create --size 100 my_volume
openstack server add volume my_volume $(openstack volume list -f value | sed '\'"s/ .*//"\'')

8. Add security group to allow icmp and ssh. It will be added to default security group.
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default

9. To check if everything is ready:
openstack flavor list
openstack image list
openstack network list
openstack security group list
openstack volume list

10. Run the test instance (Replace PROVIDER_NET_ID with the ID of the provider provider network.):
openstack server create --flavor m1.micro --image cirros \
  --nic net-id=$(openstack network list -f value | sed '\'"s/ .*//"\'') --security-group default \
  --key-name mykey my-test-cirros-instance

11. Check the status of your instance:
openstack server list

If something goes wrong, check:
docker exec -it -uroot nova_libvirt /bin/bash -c "egrep -c '\'"(vmx|svm)"\'' /proc/cpuinfo"
docker exec -it -uroot nova_libvirt /bin/bash -c "ls -la /var/log/kolla/libvirt/libvirtd.log"

12. Access the instance using the virtual console:
openstack console url show my-test-cirros-instance
or SSH:
ssh cirros@IP_FROM_(openstack server list)

TO DESTROY:
kolla-ansible -i ./all-in-one destroy --yes-i-really-really-mean-it
'

echo "You can now open web interface from your computer connecting to the address from network adapter below (probably eth0):"
docker exec -it horizon /bin/bash -c "ip addr"

echo "And username and password is:"
echo $OS_USERNAME
echo $OS_PASSWORD
