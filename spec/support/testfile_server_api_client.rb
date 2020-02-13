require 'net/http'

require "support/contexts/with_file_storage"

class TestfileServerAPIClient < WithFileStorageInterface::Driver
  def initialize(type)
    @host_info = {:host => "192.168.99.99", :port => "8888", :path => "/#{type}"}
  end

  def create_existing_file(size = nil)
    req = Net::HTTP::Post.new(@host_info[:path])
    req.set_form_data('size' => size) if size

    do_request req
  end

  def create_existing_dir
    req = Net::HTTP::Post.new(@host_info[:path])
    req.set_form_data('dir' => '1')

    do_request req
  end

  def list_in_storage(file_or_dir)
    get('entry' => to_path_string(file_or_dir)).split("\n")
  end

  def size_in_storage(file_or_dir)
    get('entry' => to_path_string(file_or_dir), 'size' => 'y').strip.to_i
  end

  def cleanup
    req = Net::HTTP::Delete.new(@host_info[:path])

    do_request req
  end

  def to_path_string(path)
    super.sub("/var#{@host_info[:path]}", "")
  end

  private

  def api
    @api ||= Net::HTTP.new(@host_info[:host], @host_info[:port])
  end

  def get(query_params)
    query = URI.encode_www_form(query_params)
    uri   = URI::HTTP.build @host_info.merge(:query => query)
    req   = Net::HTTP::Get.new(uri)

    do_request req
  end

  def do_request req
    api.start {|http| http.request req}.body.strip
  end
end
