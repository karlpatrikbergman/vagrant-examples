# Vagrant example
## Run CentOS 7 guest WITHOUT networking 
To start with we skip Vagrant networking altogether to be able to see how network interfaces 
are added/changed both on the host and on the guest. Create Vagrant file with default provider 
Virtualbox and box CentOS 7. 

Simplified output of "ifconfig" on my host machine before running any vm:
```shell
docker0:	inet 172.17.0.1  		netmask 255.255.0.0
eth0:		inet 10.210.72.239  	netmask 255.255.254.0 
lo:         inet 127.0.0.1  		netmask 255.0.0.0
vibr0:		inet 192.168.122.1		netmask 255.255.255.0
``` 
I have docker and libvirt installed, therefore the 'docker0' and 'vibr0' network interfaces.  

The routing table on my host looks like this:  
```shell
$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.210.72.1     0.0.0.0         UG    100    0        0 eth0
se-dc01.infiner 10.210.72.1     255.255.255.255 UGH   100    0        0 eth0
10.210.72.0     0.0.0.0         255.255.254.0   U     100    0        0 eth0
loopback        gentoo-pabe2.in 255.0.0.0       UG    0      0        0 lo
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.122.0   0.0.0.0         255.255.255.0   U     0      0        0 virbr0
```
Repeat routing table knowledge:  
My host ip adress '10.210.72.239' falls into the address space '10.210.72.0/23'. Any packages on the network bound for 
'10.210.72.0/23' will be routed directly to the 'eth0' network interface. Listed is also routing
for address spaces to be used for docker and libvirt.  
http://linux-ip.net/html/basic-reading.html  

Bringing up the vm without touching Vagrant network configurations does not change output of ifconfig on host 
(as expected). Notice this ouput during vm boot:
```shell
==> default: Preparing network interfaces based on configuration...
    default: Adapter 1: nat
```

Enter guest and run iproute2 (output simplified):
```shell
$ vagrant ssh
[vagrant@localhost ~]$ ip addr show
eth0:		inet 10.0.2.15/24                   state UP  		
lo:         inet  127.0.0.1/8                   state UNKNOWN
```
<sub><sup>/24 = 255.255.255.0 and /8 = 255.0.0.0</sup></sub>  

The routing table for the guest:  
```shell
$ vagrant ssh
[vagrant@localhost ~]$
ip route
10.0.2.0/24 dev eth0  proto kernel  scope link  src 10.0.2.15  metric 100
```
The guest ip adress '10.0.2.15' falls into the address space '10.0.2.0/24'. Any packages on the network bound for 
'10.0.2.15' will be routed directly to the 'eth0' network interface.  
 
*** 
 
## Run CentOS 7 guest WITH networking
Now we'll try the "private network" feature. To configure private network it is suggested to use an ip address from 
reserved private address space:      
https://www.vagrantup.com/docs/networking/private_network.html
 
Destroy vm and configure "private network" in Vagrant file:
```ruby
config.vm.network "private_network", ip: "10.100.198.200"
```
Bring it up and notice this ouput during boot:
```shell
==> default: Preparing network interfaces based on configuration...
    default: Adapter 1: nat
    default: Adapter 2: hostonly
```
Now the vm has two network adapters.  

Output of "ifconfig" on my host machine after vm with privat network has started:  
```shell
docker0:	inet 172.17.0.1  		netmask 255.255.0.0
eth0:		inet 10.210.72.239  	netmask 255.255.254.0 
lo:         inet 127.0.0.1  		netmask 255.0.0.0
vboxnet0:   inet 10.100.198.1       netmask 255.255.255.0
vibr0:		inet 192.168.122.1		netmask 255.255.255.0
```

The routing table on my host now looks like this:  
```shell
$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.210.72.1     0.0.0.0         UG    100    0        0 eth0
se-dc01.infiner 10.210.72.1     255.255.255.255 UGH   100    0        0 eth0
10.210.72.0     0.0.0.0         255.255.254.0   U     100    0        0 eth0
loopback        gentoo-pabe2.in 255.0.0.0       UG    0      0        0 lo
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.122.0   0.0.0.0         255.255.255.0   U     0      0        0 virbr0
10.100.198.0    0.0.0.0         255.255.255.0   U     0      0        0 vboxnet0
```
Any packages on the network bound for '10.100.198.0/24' will be routed to the 'vboxnet0' network interface. 

Enter guest, and run iproute2:  
```shell
$ vagrant ssh
[vagrant@localhost ~]$ ip addr show
lo:         inet  127.0.0.1/8               state UNKNOWN
eth0:		inet 10.0.2.15/24               state UP  		
eth1:		...                             state DOWN
```
***
We know have another network interface on the guest machine *but it has state DOWN and no ip address*. After doing
some research I found a bug related to CentOS 7 and Vagrant<1.8:  
https://github.com/mitchellh/vagrant/issues/6235  
I run Vagrant 1.9.1 so the problem should not be there? Anyhow the fix suggested solved the problem.  

Log on to the guest and run
```shell
sudo nmcli connection reload
sudo systemctl restart network.service
```
Run iproute2 again:
```shell
[vagrant@localhost ~]$ ip addr show
lo:         inet  127.0.0.1/8               state UNKNOWN
eth0:		inet 10.0.2.15/24               state UP  		
eth1:		10.100.198.100/24               state UP
```
To automate this, add a provisioning script with the commands above (bootstrap.sh).    

The routing table for the guest now looks like this:  
```shell
$ vagrant ssh
[vagrant@localhost ~]$
ip route
10.0.2.0/24     dev eth0  proto kernel  scope link  src 10.0.2.15       metric 100 
10.100.198.0/24 dev eth1  proto kernel  scope link  src 10.100.198.100 
169.254.0.0/16  dev eth1  scope link    metric 1003 
```

TODO: explain this.  
 
Try to ping the guest from the host:
```shell
$ ping 10.100.198.100
PING 10.100.198.101 (10.100.198.100) 56(84) bytes of data.
64 bytes from 10.100.198.100: icmp_seq=1 ttl=64 time=0.614 ms
64 bytes from 10.100.198.100: icmp_seq=2 ttl=64 time=0.381 ms
^C
```
It works!

## Add anohter guest running Ubunty/Trusty64
I followed the same procedure and created a vm with Ubuntu/Trusty64. Running ifconfig on the host produces the same 
output as before:
 ```shell
 docker0:	inet 172.17.0.1  		netmask 255.255.0.0
 eth0:		inet 10.210.72.239  	netmask 255.255.254.0 
 lo:        inet 127.0.0.1  		netmask 255.0.0.0
 vboxnet0:  inet 10.100.198.1       netmask 255.255.255.0
 vibr0:		inet 192.168.122.1		netmask 255.255.255.0
 ```
The routing table on the host is also the same as before:  
```shell
$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.210.72.1     0.0.0.0         UG    100    0        0 eth0
se-dc01.infiner 10.210.72.1     255.255.255.255 UGH   100    0        0 eth0
10.210.72.0     0.0.0.0         255.255.254.0   U     100    0        0 eth0
loopback        gentoo-pabe2.in 255.0.0.0       UG    0      0        0 lo
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.122.0   0.0.0.0         255.255.255.0   U     0      0        0 virbr0
10.100.198.0    0.0.0.0         255.255.255.0   U     0      0        0 vboxnet0
```
My understanding of this is that any messages in the the address space '10.100.198.0/24' will be routed directly to the 
'vboxnet0' network interface (virtualbox), i.e messages to the guests (with ip:s and '10.100.198.101' and '10.100.198.101')
will be routed to 'vboxnet0'.

Running 'ifconfig' on the Ubuntu guest gives the following (simplified) output:
```shell
lo:         inet  127.0.0.1/8
eth0:		inet 10.0.2.15/24  		
eth1:		10.100.198.101
```
The routing table on the Ubuntu guest looks like this:  
```shell
vagrant@vagrant-ubuntu-trusty-64:~$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.0.2.2        0.0.0.0         UG    0      0        0 eth0
10.0.2.0        *               255.255.255.0   U     0      0        0 eth0
10.100.198.0    *               255.255.255.0   U     0      0        0 eth1
```

TODO: Explain how Virtualbox knows which guest to route to.

***

## NFS
Try NFS to speed up Vagrant/Virtualbox as suggested here:    
https://www.vagrantup.com/docs/synced-folders/nfs.html  

Since I use Gentoo I installed nfsd
```shell
emerge --ask net-fs/nfs-utils
```
and added this to my Vagrant file  
```ruby
# Use NFS for shared folders for better performance
config.vm.synced_folder '.', '/vagrant', nfs: true
 ````
I did not need to change anything else. After 'vagrant up' the file '/etc/exports' looked 
like this:  
```shell
# /etc/exports: NFS file systems being exported.  See exports(5).
# VAGRANT-BEGIN: 10447 be7a5220-7297-4a7d-9d79-7ec24d8a79dc
"/usr/local/src/vagrant-examples/vagrant-simple" 10.0.0.2(rw,no_subtree_check,all_squash,anonuid=10447,anongid=100,fsid=1445704803)
# VAGRANT-END: 10447 be7a5220-7297-4a7d-9d79-7ec24d8a79dc
```
**_This worked at first, but failed on following "vagrant up":s because of a problem with permission to the 
"/etc/exports" folder. I will come back to NFS later._**

***

## vagrant-cachier
Unmaintained, but I'll give it a try:  
https://github.com/fgrehm/vagrant-cachier
```shell
$ vagrant plugin install vagrant-cachier
```
