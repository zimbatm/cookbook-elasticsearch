[Chef::Recipe, Chef::Resource].each { |l| l.send :include, ::Extensions }

Erubis::Context.send(:include, Extensions::Templates)

elasticsearch = "elasticsearch-#{node.elasticsearch[:version]}"

include_recipe "elasticsearch::curl"
include_recipe "ark"

# Create user and group
#
group node.elasticsearch[:user] do
  action :create
  system true
end

user node.elasticsearch[:user] do
  comment "ElasticSearch User"
  home    "#{node.elasticsearch[:dir]}/elasticsearch"
  shell   "/bin/bash"
  gid     node.elasticsearch[:user]
  system  true
  action  :create
end

# Create ES directories
#
[ node.elasticsearch[:path][:conf], node.elasticsearch[:path][:logs], node.elasticsearch[:pid_path] ].each do |path|
  directory path do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Create data path directories
#
data_paths = node.elasticsearch[:path][:data].is_a?(Array) ? node.elasticsearch[:path][:data] : node.elasticsearch[:path][:data].split(',')

data_paths.each do |path|
  directory path.strip do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Create service
#

template "/etc/default/elasticsearch" do
  source "elasticsearch.default.erb"
  mode 0644
end

template "/etc/init.d/elasticsearch" do
  source "elasticsearch.init.erb"
  mode 0755
end

service "elasticsearch" do
  supports :status => true, :restart => true
  action [ :enable ]
end

# Download, extract, symlink the elasticsearch libraries and binaries
#
ark_prefix_root = node.elasticsearch[:dir] || node.ark[:prefix_root]
ark_prefix_home = node.elasticsearch[:dir] || node.ark[:prefix_home]

ark "elasticsearch" do
  url   node.elasticsearch[:download_url]
  owner node.elasticsearch[:user]
  group node.elasticsearch[:user]
  version node.elasticsearch[:version]
  has_binaries ['bin/elasticsearch', 'bin/plugin']
  checksum node.elasticsearch[:checksum]
  prefix_root   ark_prefix_root
  prefix_home   ark_prefix_home

  notifies :start,   'service[elasticsearch]'
  notifies :restart, 'service[elasticsearch]'
end

# Create file with ES environment variables
#
template "elasticsearch-env.sh" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch-env.sh"
  source "elasticsearch-env.sh.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

  notifies :restart, 'service[elasticsearch]'
end

# Create ES config file
#
template "elasticsearch.yml" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch.yml"
  source "elasticsearch.yml.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

  notifies :restart, 'service[elasticsearch]'
end

# Create ES logging file
#
template "logging.yml" do
  path   "#{node.elasticsearch[:path][:conf]}/logging.yml"
  source "logging.yml.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

  notifies :restart, 'service[elasticsearch]'
end
