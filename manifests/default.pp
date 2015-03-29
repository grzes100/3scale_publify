
Exec {
  path => ['/usr/sbin', '/usr/bin', '/sbin', '/bin']
}

$mysql_root_pass="root"
$mysql_app_user="publify"
$mysql_app_pass="publify"
$publify_git="https://github.com/publify/publify.git"
$rails_home="/home/vagrant/rails"


# --- preinstall ---

stage { 'pre':
  before => Stage['main'],
}

class apt_updates {
  exec { 'apt-get -y update': }
}

class { 'apt_updates':
  stage => 'pre',
}


# --- load-balancer ---

node 'lb.local' {
  class { 'haproxy': }

  haproxy::listen { 'hap00':
    collect_exported => false,
    ipaddress        => $::ipaddress_eth1,
    ports            => '80',
    options	     => { 'option' => [ 'tcplog' ], 'balance' => 'roundrobin' }
  }

  haproxy::balancermember { 'master00':
    listening_service => 'hap00',
    server_names      => 'web.local',
    ipaddresses       => $::ipaddress_web,
    ports             => '3000',
    options           => 'check',
  }
}


# --- database ---

node 'db.local' {
	class { 'mysql::server':
	  root_password           => $mysql_root_pass,
	  remove_default_accounts => true,
	  restart                 => true,
	  override_options        => { 'mysqld' => { 'bind-address' => $::ipaddress_eth1 } },

	  users 		  => {
	    "$mysql_app_user@$::ipaddress_web" => {
	      ensure                   => 'present',
	      password_hash            => mysql_password($mysql_app_pass)
	    }
	  },

	  grants 	          => {
	    "$mysql_app_user@$::ipaddress_web/*.*" => {
	      ensure     => 'present',
	      options    => ['GRANT'],
	      privileges => ['ALL'],
	      table      => '*.*',
	      user       => "$mysql_app_user@$::ipaddress_web"
	    }
	  }
	}
}


# --- webapp ---

node 'web.local' {

  # Ruby on Rails

  #notify { 'Installing Rvm': } ->
  class { 'rvm': 
    before => Rvm_system_ruby['ruby-2.2'];
  }

  rvm_system_ruby {
    'ruby-2.2':
      ensure      => 'present',
      default_use => true;
  }

  rvm_gem {
    'bundler':
      name         => 'bundler',
      ruby_version => 'ruby-2.2',
      ensure       => latest,
      require      => [ Rvm_system_ruby['ruby-2.2'], Package['libmysqlclient-dev']];
  }

  rvm_gem {
    'rails':
      name         => 'rails',
      ruby_version => 'ruby-2.2',
      ensure       => latest,
      require      => Rvm_system_ruby['ruby-2.2'];
  }

  package { ['mysql-client', 'libmysqlclient-dev', 'sendmail', 'git-core', 'libcurl4-openssl-dev']:
    ensure => installed;
  }


  # Publify webapp

  file { "${rails_home}":
    ensure  => 'directory',
    owner   => 'vagrant',
    group   => 'vagrant';
  }

 exec { 'git clone':
    command => "git clone $publify_git",
    user    => 'vagrant',
    cwd     => "${rails_home}",
    creates => "${rails_home}/publify/config/database.yml.mysql",
    require => [ File["${rails_home}"], Package['git-core'] ];
  }

  exec { 'config_database':
    command => "cp database.yml.mysql database.yml && sed -i 's/host.*/host: $::ipaddress_db/; s/username.*/username: $mysql_app_user/; s/password.*/password: $mysql_app_pass/' database.yml",
    user    => 'vagrant',
    cwd     => "${rails_home}/publify/config",
    creates => "${rails_home}/publify/config/database.yml",
    require => Exec['git clone'];
  }

  exec { 'bundle_install':
    command	=> '/bin/bash -c "source /etc/profile.d/rvm.sh && bundle install"',
    user	=> 'vagrant',
    environment	=> ['RAILS_ENV=production'],
    cwd		=> "${rails_home}/publify",
    creates	=> "${rails_home}/publify/Gemfile.lock",
    require	=> [ Exec['config_database'], Package['libcurl4-openssl-dev'], Rvm_gem['bundler'] ];
  }

  exec { 'init_db':
    command	=> '/bin/bash -c "source /etc/profile.d/rvm.sh && rake db:setup && rake db:migrate && rake db:seed"',
    user	=> 'vagrant',
    environment	=> ['RAILS_ENV=production'],
    cwd		=> "${rails_home}/publify",
    unless	=> "mysqlshow -u${mysql_app_user} -p${mysql_app_pass} -h $::ipaddress_db|grep -q publify",
    require	=> Exec['bundle_install'];
  }

  exec { 'assets':
    command	=> '/bin/bash -c "source /etc/profile.d/rvm.sh && rake assets:precompile"',
    user	=> 'vagrant',
    environment	=> ['RAILS_ENV=production'],
    cwd		=> "${rails_home}/publify",
    creates	=> "${rails_home}/publify/public/assets",
    require	=> Exec['bundle_install'];
  }

  exec { 'start_rails':
    command	=> "/bin/bash -c 'source /etc/profile.d/rvm.sh && rails server -b $::ipaddress_eth1 -d'",
    user	=> 'vagrant',
    environment	=> ['RAILS_ENV=production'],
    cwd		=> "${rails_home}/publify",
    creates	=> "${rails_home}/publify/tmp/pids/server.pid",
    require	=> [ Exec['init_db'], Exec['assets'] ];
  }
}

