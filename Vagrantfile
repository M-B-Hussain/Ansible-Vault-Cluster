Vagrant.configure("2") do |config|
  # Base OS image for the cluster nodes
  config.vm.box = "ubuntu/jammy64"

  # -------------------------------------------------------------------------
  # NODE 1: The Load Balancer
  # -------------------------------------------------------------------------
  config.vm.define "lb01" do |lb|
    lb.vm.hostname = "lb01"
    lb.vm.network "private_network", ip: "192.168.56.10"
    
    lb.vm.provider "virtualbox" do |v|
      v.memory = 512
      v.cpus = 1
      v.name = "infra-lb01"
    end
  end

  # -------------------------------------------------------------------------
  # NODE 2: Application Runner 1
  # -------------------------------------------------------------------------
  config.vm.define "app01" do |app01|
    app01.vm.hostname = "app01"
    app01.vm.network "private_network", ip: "192.168.56.11"
    
    app01.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 1
      v.name = "infra-app01"
    end
  end

  # -------------------------------------------------------------------------
  # NODE 3: Application Runner 2
  # -------------------------------------------------------------------------
  config.vm.define "app02" do |app02|
    app02.vm.hostname = "app02"
    app02.vm.network "private_network", ip: "192.168.56.12"
    
    app02.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 1
      v.name = "infra-app02"
    end
  end
end
