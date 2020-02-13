DockerContainerManager.configure :my_httpd do
  image "httpd:2.4-alpine"
  port  "8080", "80"
  file  "/usr/local/apache2/htdocs/index.html", "<html><body><h1>My Content works!</h1></body></html>"
end

DockerContainerManager.configure :nfs_server do
  image "erichough/nfs-server"
  env   "NFS_EXPORT_0", '/var/nfs    *(rw,sync,no_root_squash,no_subtree_check)'
  entrypoint ""

  # Port mappings taken from https://github.com/ehough/docker-nfs-server#usage
  port  111,   111
  port  2049,  2049
  port  32765, 32765
  port  32767, 32767

  # port  111,   111/udp
  # port  2049,  2049/udp
  # port  32765, 32765/udp
  # port  32767, 32767/udp
end
