require 'tmpdir'
require 'tempfile'
require 'webrick'

# == TestfileServer
#
# This is simple webserver that is intended to allow for pre-populating a
# directory without needing to mount or make file system calls to do it.
#
# This is intended to be a shared inface that can be used locally as well, but
# is desgined to assist with Vagrant environments, where it is not possible to
# configure nfsd to work with a virtualbox shared folder that is encrypted.
#
#   https://serverfault.com/a/392232
#   https://stackoverflow.com/q/36110703
#
# So as a way to create "existing files" on a server, this webserver is meant
# to be an interface to interact with the current environment to do just that.
#
#
# === Usage
#
# Run this script
#
#   $ ruby test_file_server.rb nfs
#
# Then hit the endpoint to write a file to the storage directory
#
#   $ curl -X POST localhost:8888/nfs; echo
#   20200211-3246-185fn5u
#   $ curl -X POST -d size=10 localhost:8888/nfs; echo
#   20200211-3246-74sjrg
#   $ ls -lh /var/nfs/
#   total 0
#   -rw-------    1 root     root           0 Feb 11 23:39 20200211-3246-185fn5u
#   -rw-------    1 root     root          10 Feb 11 23:38 20200211-3246-74sjrg
#   $ curl -X DELETE localhost:8888/nfs; echo
#   /var/nfs cleaned!
#
class FileCreator < WEBrick::HTTPServlet::AbstractServlet
  def initialize server, type
    super server

    @type        = type
    @storage_dir = "/var/#{type}" # TODO:  Make basedir configurable
  end

  # List directory or file
  #
  # pass entry=path/to/file, otherwise it will look from the root.
  #
  # passing size=* will return the total size of dir/file
  #
  # without size, it is a newline delimited list of entries
  def do_GET request, response
    glob    = request.query["entry"].to_s
    glob    = File.join(@storage_dir, glob)
    glob   << "/*" if glob == "" || File.directory?(glob)
    entries = Dir[glob]

    if request.query["size"]
      sum = entries.map { |file| File.stat(file).size }.sum

      give response, 200, 'text/plain', sum.to_s
    else
      give response, 200, 'text/plain', entries.join("\n")
    end
  end

  # Create a new tempfile
  #
  # sets the response to the file path of the newly created file
  def do_POST request, response
    Dir::Tmpname.create("", @storage_dir) do |tmpname, n, opts|
      if request.query["dir"]
        Dir.mktmpdir(nil, @storage_dir).sub("#{@storage_dir}/", "")
      else
        size = request.query["size"].to_i # nil.to_i (0) will default to a "touch" action
        mode = 0|File::RDWR|File::CREAT|File::EXCL
        file = File.open(tmpname, mode)

        file.print "0" * size
        file.close
      end

      give response, 200, 'text/plain', file.path
    end

  end

  # Clean @storage_dir
  def do_DELETE request, response
    Dir[File.join(@storage_dir, '*')].each do |entry|
      FileUtils.remove_entry(entry)
    end

    give response, 200, 'text/plain', "#{@storage_dir} cleaned!"
  end

  private

  # Modify the response before returning it to the client
  def give response, status, content_type, body
    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end
end

class TestfileServer

  def self.start(*mount_types)
    new(*mount_types).start
  end

  def initialize(*mount_types)
    @server = WEBrick::HTTPServer.new :Port => 8888, :BindAddress => "0.0.0.0"
    mount_types.each { |type| @server.mount "/#{type}", FileCreator, type }
  end

  def start
    trap 'INT' do @server.shutdown end
    @server.start
  end
end

if $PROGRAM_NAME == __FILE__
  TestfileServer.start *ARGV
end
