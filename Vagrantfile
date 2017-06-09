# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
sudo apt-get update -yq
sudo apt-get install -yq build-essential libreadline-dev libev-dev libssl-dev  
sudo apt-get install -yq libpcre3-dev libpcre3
sudo apt-get install -yq libsqlite3-dev sqlite3
sudo apt-get install -yq luajit luarocks lua5.1

# Lua
sudo luarocks install lua-cjson
sudo luarocks install luasec
sudo luarocks install lua-http
sudo luarocks install lsqlite3
sudo luarocks install argparse
sudo luarocks install luaposix
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provision 'shell', inline: $script
end
