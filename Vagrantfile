#
# 3-box setup for running Publify (https://github.com/publify/publify)
#

IP_LB 	= '192.168.10.2'
IP_WEB	= '192.168.10.3'
IP_DB 	= '192.168.10.4'


Vagrant.configure("2") do |config|
	config.vm.box = 'ubuntu/trusty32'

	# load-balancer
	config.vm.define :lb do |lb|
		lb.vm.network :private_network, ip: IP_LB
		lb.vm.hostname = 'lb.local'

		lb.vm.provision :puppet do |puppet|
			puppet.manifest_file = 'module.pp'
			puppet.facter = { 'modname' => 'puppetlabs-haproxy', }
		end

		lb.vm.provision :puppet do |puppet|
			puppet.facter = { 'ipaddress_web' => IP_WEB, }
		end
	end


	# database
	config.vm.define :db do |db|
		db.vm.network :private_network, ip: IP_DB
		db.vm.hostname = 'db.local'

		db.vm.provision :puppet do |puppet|
			puppet.manifest_file = 'module.pp'
			puppet.facter = { 'modname' => 'puppetlabs-mysql', }
		end
		
		db.vm.provision :puppet do |puppet|
			puppet.facter = { 'ipaddress_web' => IP_WEB, }
		end
	end


	# webapp
	config.vm.define :web do |web|
		web.vm.network :private_network, ip: IP_WEB
		web.vm.hostname = 'web.local'

		web.vm.provision :puppet do |puppet|
			puppet.manifest_file = 'module.pp'
			puppet.facter = { 'modname' => 'maestrodev-rvm', }
		end

		web.vm.provision :puppet do |puppet|
			puppet.facter = { 'ipaddress_db' => IP_DB, }
		end

	end

end
