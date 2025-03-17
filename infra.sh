#!/bin/bash
#stops the containers the ntp-make, ntp-serv, and ntp-client containters if they are running and deletes them
incus stop ntp-make --force 2>/dev/null || true
incus stop ntp-serv --force 2>/dev/null || true
incus stop ntp-client --force 2>/dev/null || true
incus delete ntp-make --force 2>/dev/null || true
incus delete ntp-serv --force 2>/dev/null || true
incus delete ntp-client --force 2>/dev/null || true

#removes the network if it has already been created
incus network rm ntp-test

#creates the network and containers used to run ansible scripts, ntp server, and ntp client
incus network create ntp-test network=UPLINK ipv4.address=192.168.47.1/24 ipv4.nat=true ipv6.address=none ipv6.nat=false
incus init images:kali ntp-make -t c2-m6 --network ntp-test -d eth0,ipv4.address=192.168.47.50 -d root,size=320GiB
incus init images:ubuntu/jammy/cloud ntp-serv -t c2-m6 --network ntp-test -d eth0,ipv4.address=192.168.47.100 -d root,size=320GiB
incus init images:ubuntu/jammy/cloud ntp-client -t c2-m6 --network ntp-test -d eth0,ipv4.address=192.168.47.101 -d root,size=320GiB

#starts the containers
echo "========== start VMs"
incus start ntp-make
incus start ntp-serv
incus start ntp-client

#install ntp-make(kali) with tools and ansible
echo "========== setup ntp-make"
incus exec ntp-make -- /bin/bash -c  "apt update"
incus exec ntp-make -- /bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y ansible net-tools'
incus exec ntp-make -- bash -c "useradd -m -s /bin/bash 'ansible'"
incus exec ntp-make -- usermod -aG sudo ansible
incus exec ntp-make -- bash -c "echo ansible:ansible | chpasswd"
incus exec ntp-make -- /bin/bash -c 'su ansible -c "mkdir --mode=750 /home/ansible/.ssh"'
incus exec ntp-make -- /bin/bash -c 'su ansible -c "ssh-keygen -t rsa -b 4096 -f /home/ansible/.ssh/id_rsa -P \"\""'

incus file pull ntp-make/home/ansible/.ssh/id_rsa.pub .
incus file push id_rsa.pub ntp-serv/tmp/id_rsa.pub
incus file push id_rsa.pub ntp-client/tmp/id_rsa.pub

# setup ntp-server with ssh
echo "========== set up ntp-serv"
incus exec ntp-serv -- /bin/bash -c  "apt update"
incus exec ntp-serv -- bash -c "useradd -m -s /bin/bash 'ansible'"
incus exec ntp-serv -- usermod -aG sudo ansible
incus exec ntp-serv -- bash -c "echo ansible:ansible | chpasswd"
echo "========== ntp-serv - add sshkey to authorized_keys file"
incus exec ntp-serv -- /bin/bash -c 'su ansible -c "mkdir --mode=750 /home/ansible/.ssh"'
incus exec ntp-serv -- /bin/bash -c 'cat /tmp/id_rsa.pub >> /home/ansible/.ssh/authorized_keys'
incus exec ntp-serv -- /bin/bash -c 'rm /tmp/id_rsa.pub'
incus exec ntp-serv -- /bin/bash -c 'echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible'
incus exec ntp-serv -- /bin/bash -c 'chmod 440 /etc/sudoers.d/ansible'
incus exec ntp-serv -- /bin/bash -c 'chown ansible:ansible -R /home/ansible'
incus exec ntp-serv -- /bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server'
echo "========== systemctl restart ssh"
incus exec ntp-serv -- bash -c "systemctl restart ssh"
echo "========== systemctl enable -now ssh"
incus exec ntp-serv -- bash -c "systemctl enable --now ssh"

incus file push -r make_ntp ntp-make/home/ansible/

# setup ntp client with ssh
echo "========== set up ntp-client"
incus exec ntp-client -- /bin/bash -c  "apt update"
incus exec ntp-client -- bash -c "useradd -m -s /bin/bash 'ansible'"
incus exec ntp-client -- usermod -aG sudo ansible
incus exec ntp-client -- bash -c "echo ansible:ansible | chpasswd"
echo "========== ntp-client - add sshkey to authorized_keys file"
incus exec ntp-client -- /bin/bash -c 'su ansible -c "mkdir --mode=750 /home/ansible/.ssh"'
incus exec ntp-client -- /bin/bash -c 'cat /tmp/id_rsa.pub >> /home/ansible/.ssh/authorized_keys'
incus exec ntp-client -- /bin/bash -c 'rm /tmp/id_rsa.pub'
incus exec ntp-client -- /bin/bash -c 'echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible'
incus exec ntp-client -- /bin/bash -c 'chmod 440 /etc/sudoers.d/ansible'
incus exec ntp-client -- /bin/bash -c 'chown ansible:ansible -R /home/ansible'
incus exec ntp-client -- /bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server'
echo "========== systemctl restart ssh"
incus exec ntp-client -- bash -c "systemctl restart ssh"
echo "========== systemctl enable -now ssh"
incus exec ntp-client -- bash -c "systemctl enable --now ssh"

incus exec ntp-make -- /bin/bash -c '
echo "reset; echo YOU ARE LOGGED IN AS ROOT IN ntp-make, USE su ansible TO SWITCH USERS" >> /root/.bashrc
'
incus exec ntp-serv -- /bin/bash -c '
echo "reset; echo YOU ARE LOGGED IN AS ROOT IN ntp-serv, USE su ansible TO SWITCH USERS" >> /root/.bashrc
'
incus exec ntp-client -- /bin/bash -c '
echo "reset; echo YOU ARE LOGGED IN AS ROOT IN ntp-client, USE su ansible to SWITCH USERS" >> /root/.bash
'
