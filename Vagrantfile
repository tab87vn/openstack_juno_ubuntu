# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"


nodes = {
    'controller'  => [1, 200],
    #'network'  => [1, 201],    
    #'compute'  => [2, 202],
    #'cinder'   => [1, 211],
    #'test'	   => [1, 222],
}

	
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
	config.vm.box = "dummy"
	config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
	config.vm.synced_folder ".", "/vagrant", id: "vagrant-root"
	
	nodes.each do |prefix,(count, ip_start)|
		count.times do |i|
			if prefix == "compute"
		        hostname = "%s-%02d" % [prefix, (i+1)]
	      	else
		        hostname = "%s" % [prefix, (i+1)]
	      	end

			config.vm.define "#{hostname}".to_sym do |aws2|
				aws2.vm.hostname = "somename"
							
				aws2.vm.provider :aws do |aws, override|  
					aws.access_key_id = ENV['ACCESS_KEY_ID']
					aws.secret_access_key = ENV['SECRET_ACCESS_KEY']
					aws.keypair_name = ENV['KEYPAIR_NAME']
				
					aws.ami = "ami-3d50120d" #Ubuntu 14.04 LTS

					if prefix == "network" or prefix == "compute" or prefix == "controller"
						aws.instance_type = "t2.medium"
					end
					
					if prefix == "cinder" or prefix == "test"
						aws.instance_type = "t2.micro"
					end
					
					if prefix == "test" 
						aws.private_ip_address =  "172.31.21.#{ip_start+i}"
					else
						aws.private_ip_address =  "172.31.20.#{ip_start+i}"
					end

					# an IP for network
					#if prefix == "network"
					#	aws.elastic_ip = true
					#end
				
					aws.region = "us-west-2"
					aws.availability_zone = "us-west-2a"
					aws.security_groups = ["tab87vn_master_thesis"]
					
					if prefix == "controller"
						aws.block_device_mapping = [{ 'DeviceName' => '/dev/sda1', 'Ebs.VolumeSize' => 20 }]			
					else
						aws.block_device_mapping = [{ 'DeviceName' => '/dev/sda1', 'Ebs.VolumeSize' => 10 }]	
					end

					override.ssh.username = "ubuntu"
					override.ssh.private_key_path = "~/myfiles/keys/tab87vn_openstack.pem"
					aws.tags = {
					  'user' => 'tab87vn-node#{i}'
					}
				end
				#aws2.vm.provision :shell, :path => "#{prefix}.sh"
			end
		end
    end
end