require "tmpdir"

require "support/docker_container_manager"

DockerContainerManager.configure :nfs_server do
  image      "erichough/nfs-server"
  env        "NFS_EXPORT_0", '/var/nfs    *(rw,sync,no_root_squash,no_subtree_check)'
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

shared_context "with nfs server", :with_nfs_server do
  before(:all) { DockerContainerManager.start :nfs_server }
  after(:all)  { DockerContainerManager.stop :nfs_server }

  def existing_ftp_file(size = 0)
    filename = File.basename(Dir::Tmpname.create("") {})
    filepath = File.join("", "var", "nfs", filename)
    DockerContainerManager[:nfs_server].store_file(filepath, "0" * size)
    filepath
  end
end
