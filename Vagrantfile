# -*- mode: ruby -*-
# vi: set ft=ruby :

# If container_sync
# enable swift2
# configure swift and swift2 with container_sync configs (execute extra script at end)

# If dvr
# enable compute2
# configure compute and compute2 for dvr

# Uncomment the next line to force use of VirtualBox provider when Fusion provider is present
# ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

nodes = {
    'controller'  => [1, 200],
    'network'  => [1, 201],
#     'compute'  => [1, 202],
    #'swift'   => [1, 210],
    #'swift2'  => [1, 212],
    #'cinder'   => [1, 211],
}

Vagrant.configure("2") do |config|
    
  # Virtualbox
  config.vm.box = "bunchc/trusty-x64"
  config.vm.synced_folder ".", "/vagrant", type: "nfs"

  # VMware Fusion / Workstation
  config.vm.provider :vmware_fusion or config.vm.provider :vmware_workstation do |vmware, override|
    override.vm.box = "bunchc/trusty-x64"
    override.vm.synced_folder ".", "/vagrant", type: "nfs"

    # Fusion Performance Hacks
    vmware.vmx["logging"] = "FALSE"
    vmware.vmx["MemTrimRate"] = "0"
    vmware.vmx["MemAllowAutoScaleDown"] = "FALSE"
    vmware.vmx["mainMem.backing"] = "swap"
    vmware.vmx["sched.mem.pshare.enable"] = "FALSE"
    vmware.vmx["snapshot.disabled"] = "TRUE"
    vmware.vmx["isolation.tools.unity.disable"] = "TRUE"
    vmware.vmx["unity.allowCompostingInGuest"] = "FALSE"
    vmware.vmx["unity.enableLaunchMenu"] = "FALSE"
    vmware.vmx["unity.showBadges"] = "FALSE"
    vmware.vmx["unity.showBorders"] = "FALSE"
    vmware.vmx["unity.wasCapable"] = "FALSE"
    vmware.vmx["vhv.enable"] = "TRUE"
  end

  #Default is 2200..something, but port 2200 is used by forescout NAC agent.
  config.vm.usable_port_range= 2800..2900 

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
    config.cache.enable :apt
    config.cache.synced_folder_opts = {
      type: :nfs,
      mount_options: ['rw', 'vers=3', 'tcp', 'nolock']
    }
  else
    puts "[-] WARN: This would be much faster if you ran vagrant plugin install vagrant-cachier first"
  end

  nodes.each do |prefix, (count, ip_start)|
    count.times do |i|
      if prefix == "compute"
        hostname = "%s-%02d" % [prefix, (i+1)]
      else
        hostname = "%s" % [prefix, (i+1)]
      end

      config.vm.define "#{hostname}" do |box|
        box.vm.hostname = "#{hostname}.ostest"
        if prefix == "controller"
        	box.vm.network :private_network, ip: "130.104.230.109", :netmask => "255.255.255.0"	    	
      		box.vm.network :private_network, ip: "192.168.100.6", :netmask => "255.255.255.0"
      	end
      	if prefix == "network"
      		box.vm.network :private_network, ip: "130.104.230.110", :netmask => "255.255.255.0"
        	box.vm.network :private_network, ip: "10.0.100.7", :netmask => "255.255.255.0" 
      		box.vm.network :private_network, ip: "192.168.100.7", :netmask => "255.255.255.0" 
      	end
      	if prefix == "compute"
      		box.vm.network :private_network, ip: "130.104.230.106", :netmask => "255.255.255.0"
        	box.vm.network :private_network, ip: "10.0.100.3", :netmask => "255.255.255.0" 
      		box.vm.network :private_network, ip: "192.168.100.3", :netmask => "255.255.255.0" 
		end
		

        box.vm.provision :shell, :path => "#{prefix}.sh"

        # Otherwise using VirtualBox
        box.vm.provider :virtualbox do |vbox|
          # Defaults
          vbox.customize ["modifyvm", :id, "--memory", 768]
          vbox.customize ["modifyvm", :id, "--cpus", 1]
          if prefix == "controller"
            vbox.customize ["modifyvm", :id, "--memory", 3172]
            vbox.customize ["modifyvm", :id, "--cpus", 1]
          end
          
          vbox.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
          vbox.customize ["modifyvm", :id, "--nicpromisc4", "allow-all"]
        end
      end
    end
  end
end
