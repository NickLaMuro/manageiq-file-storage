require "ftpd"
require "tmpdir"
require "tempfile"
require "fileutils"

require "support/contexts/with_file_storage"

class FtpSingletonServer
  class << self
    attr_reader :driver
  end

  def self.run_ftp_server
    @driver     = FTPServerDriver.new
    @ftp_server = Ftpd::FtpServer.new(@driver)
    @ftp_server.on_exception do |e|
      STDOUT.puts e.inspect
    end
    @ftp_server.start
  end

  def self.bound_port
    @ftp_server.bound_port
  end

  def self.stop_ftp_server
    @ftp_server.stop
    @ftp_server = nil

    @driver.cleanup
    @driver = nil
  end
end

class FTPServerDriver < WithFileStorageInterface::Driver

  attr_reader :existing_file, :existing_dir

  def initialize
    create_tmp_dir
  end

  def authenticate(username, password)
    username == "ftpuser" && password == "ftppass"
  end

  def file_system(_user)
    Ftpd::DiskFileSystem.new(@ftp_dir)
  end

  def cleanup
    FileUtils.remove_entry(@ftp_dir)
  end

  def create_existing_file(size = 0)
    @existing_file ||= Tempfile.new("", @ftp_dir).tap { |tmp| tmp.puts "0" * size }
  end

  # Create a dir under the @ftp_dir, but only return the created directory name
  def create_existing_dir
    @existing_dir ||= Dir.mktmpdir(nil, @ftp_dir).sub("#{@ftp_dir}/", "")
  end

  def list_in_storage(file_or_dir)
    with_connection do |ftp|
      begin
        ftp.nlst(to_path_string(file_or_dir))
      rescue Net::FTPPermError
        []
      end
    end
  end

  def size_in_storage(file_or_dir)
    path = to_path_string(file_or_dir)
    with_connection do |ftp|
      begin
        ftp.size(path)
      rescue Net::FTPPermError
        0
      end
    end
  end

  private

  def create_tmp_dir
    @ftp_dir = Dir.mktmpdir
  end

  def with_connection
    Net::FTP.open("localhost") do |ftp|
      ftp.login("ftpuser", "ftppass")
      yield ftp
    end
  end
end

shared_context "with ftp server", :with_ftp_server do
  include WithFileStorageInterface

  def driver
    FtpSingletonServer.driver
  end

  before(:all) { FtpSingletonServer.run_ftp_server }
  after(:all)  { FtpSingletonServer.stop_ftp_server }

  # HACK:  Avoid permission denied errors with `ftpd` starting on port 21, but
  # our FTP lib always assuming that we are using the default port
  #
  # The hack basically sets the default port for `Net::FTP` to the bound port
  # of the running server
  before(:each) do
    stub_const("Net::FTP::FTP_PORT", FtpSingletonServer.bound_port)
  end

  let(:valid_ftp_creds) { { :username => "ftpuser", :password => "ftppass" } }
end
