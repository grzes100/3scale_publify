Exec {
  path => ['/usr/sbin', '/usr/bin', '/sbin', '/bin']
}

# Install a Puppet module if missing

exec { "puppet module install $::modname":
  unless => "puppet module list | grep -q $::modname" 
}
