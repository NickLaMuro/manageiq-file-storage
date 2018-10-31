# This class is meant to be a abstract interface for defining a file_storage
# class.
#
# The storage class can either be of a type of "object storage", which includes:
# * protocols like FTP
# * document storage like s3 and OpenStack's Swift
#
# And mountable filesystems like:
# * NFS
# * SMB
#
# The class is meant to allow a shared interface for working with these
# different forms of file storage, while maintaining their differences in
# implementation where necessary.  Connection will be handled separately by the
# subclasses, but they must conform to the top level interface.
#
class MiqFileStorage
  class InvalidSchemeError < ArgumentError
    def initialize(bad_scheme = nil)
      super(error_message(bad_scheme))
    end

    def error_message(bad_scheme)
      valid_schemes = ::MiqFileStorage.storage_interface_classes.keys.inspect
      "#{bad_scheme} is not a valid MiqFileStorage uri scheme. Accepted schemes are #{valid_schemes}"
    end
  end

  def self.with_interface_class(opts)
    klass = fetch_interface_class(opts)
    block_given? ? yield(klass) : klass
  end

  def self.fetch_interface_class(opts)
    return nil unless opts[:uri]

    require 'uri'
    scheme, _ = URI.split(URI::DEFAULT_PARSER.escape(opts[:uri]))
    klass = storage_interface_classes[scheme]

    raise InvalidSchemeError, scheme if klass.nil?

    klass.new_with_opts(opts)
  end
  private_class_method :fetch_interface_class

  def self.storage_interface_classes
    @storage_interface_classes ||= Interface.descendants.each_with_object({}) do |klass, memo|
      memo[klass.uri_scheme] = klass if klass.uri_scheme
    end
  end

  class Interface
    BYTE_HASH_MATCH = /^(?<BYTE_NUM>\d+(\.\d+)?)\s*(?<BYTE_QUALIFIER>K|M|G)?$/i
    BYTE_HASH       = {
      "k" => 1.kilobyte,
      "m" => 1.megabyte,
      "g" => 1.gigabyte
    }.freeze

    attr_reader :remote_file_path, :byte_count, :source_input, :input_writer

    def self.new_with_opts(opts) # rubocop:disable Lint/UnusedMethodArgument
      raise NotImplementedError, "#{name}.new_with_opts is not defined"
    end

    def self.uri_scheme
      nil
    end

    # :call-seq:
    #   add( remote_uri )                       { |input_writer| ... }
    #   add( remote_uri, byte_count )           { |input_writer| ... }
    #
    #   add( local_io, remote_uri )
    #   add( local_io, remote_uri, byte_count )
    #
    # Add a file to the destination URI.
    #
    # In the block form of the method, only the remote_uri is required, and it
    # is assumed the input will be a generated in the executed block (most
    # likely an external process) to a unix pipe that can be written to.  The
    # pipe generated by this method and passed in to the block as a file
    # location to the `input_stream`).
    #
    # In the non-block form, a source must be provided as the first argument
    # either as an IO object that can be read from, or a file path, and the
    # second argument is the remote_uri as in the block form.
    #
    # An additional argument in both forms as the last argument is `byte_count`
    # can also be included.  If passed, it will be assumed that the resulting
    # input will be split, and the naming for the splits will be:
    #
    #   - filename.00001
    #   - filename.00002
    #   ...
    #
    # Block form:
    #
    #   nfs_session.add("path/to/file", "200M") do |input_stream|
    #     `pg_dump -f #{input_stream} vmdb_production`
    #   end
    #
    # Non-block form:
    #
    #   nfs_session.add("path/to/local_file", "path/to/remote_file")
    #   nfs_session.add("path/to/local_file", "path/to/remote_file", "200M")
    #
    def add(*upload_args, &block)
      initialize_upload_vars(*upload_args)
      mkdir(File.dirname(@remote_file_path))
      thread = handle_io_block(&block)
      result = if byte_count
                 upload_splits
               else
                 upload_single(@remote_file_path)
               end
      # `.join` will raise any errors from the thread, so we want to do that
      # here (if a thread exists of course).
      thread.join if thread
      result
    ensure
      reset_vars
    end
    alias upload add

    def mkdir(dir) # rubocop:disable Lint/UnusedMethodArgument
      raise NotImplementedError, "#{self.class}##{__callee__} is not defined"
    end

    # :call-seq:
    #   download( local_io, remote_uri )
    #   download( nil,      remote_uri ) { |input_writer| ... }
    #
    # Download a file from a remote uri.
    #
    # In non-block form, the remote_uri is saved to the local_io.
    #
    # In block form, the local_io is omitted, and it is set to a PTY writer
    # path that will assumed to be read by the block provided.
    def download(local_file, remote_file_uri, &block)
      @remote_file_path = remote_file_uri
      if block_given?
        thread = handle_io_block(&block)
        download_single(remote_file_uri, input_writer)
        input_writer.close
        thread.join
      else
        download_single(remote_file_uri, local_file)
      end
    ensure
      reset_vars
    end

    # :call-seq:
    #   magic_number_for( remote_uri )
    #   magic_number_for( remote_uri, {:accepted => {:key => "magic_str", ...} } )
    #
    # Determine a magic number for a remote file.
    #
    # If no options[:accepted] is passed, then only the first 256 bytes of the
    # file are downloaded, and just that data is returned.
    #
    # If a hash of magic number keys and values for those magic numbers is
    # passed, then it will download the largest byte size for the magic number
    # values, and compare against the list, returning the first match.
    #
    # Example:
    #
    #   magics = { :pgdump => PostgresAdmin::PG_DUMP_MAGIC }
    #
    #   magic_number_for("example.org/my_dump.gz", :accepted => magics)
    #   #=> :pgdump
    #   magic_number_for("example.org/my_file.rb", :accepted => magics)
    #   #=> nil
    #
    # NOTE:  This is an extremely niave implementation for remote magic number
    # checking, and is only really meant for working with the known magics
    # PostgresAdmin.  Many other use cases would need to be considered, since
    # magic numbers can also checked against the tail of the file, and are not
    # limited to the first 256 bytes as has been arbitrarily decided on here.
    def magic_number_for(uri, options = {})
      # Amount of bytes to download for checking magic
      @byte_count = options.fetch(:accepted, {}).values.map(&:length).max || 256
      uri_data_io = StringIO.new
      download_single(uri, uri_data_io)
      uri_data    = uri_data_io.string

      if (magics = options[:accepted])
        result = magics.detect { |_, magic| uri_data.force_encoding(magic.encoding).start_with?(magic) }
        result && result.first
      else
        uri_data
      end
    ensure
      reset_vars
    end

    private

    # NOTE:  Needs to be overwritten in the subclass!
    #
    # Classes that inherit from `MiqFileStorage` need to make sure to create a
    # method that overwrites this one to handle the specifics of uploading for
    # their particular ObjectStore protocol or MountSession.
    #
    # `dest_uri` is the current file that will be uploaded.  If file splitting
    # is occurring, this will update the filename passed into `.add` to include
    # a `.0000X` suffix, where the suffix is padded up to 5 digits in total.
    #
    # `#upload_single` doesn't need to worry about determining the file name
    # itself for splitting, but if any relative path munging is necessary, that
    # should be done here (see `MiqGenericMountSession#upload_single` for an
    # example)
    #
    # `source_input` available as an attr_reader in this method, and will
    # always be a local IO object that is available for reading.
    #
    # `byte_count` is also an attr_reader that is available, and will either be
    # `nil` if no file splitting is occurring, or a integer representing the
    # maximum number of bytes to uploaded for this particular `dest_uri`.
    #
    #
    # Ideally, making use of `IO.copy_stream` will simplify this process
    # significantly, as you can pass it `source_input`, `dest_uri`, and
    # `byte_count` respectively, and it will automatically handle streaming the
    # data from one IO object to the other.  In mount based situations, where
    # `dest_uri` is a file path (in `MiqGenericMountSession#upload_single`,
    # this is converted to `relpath`), this does not need to be converted to a
    # `File` IO object as `IO.copy_stream` will do that for you.
    def upload_single(dest_uri) # rubocop:disable Lint/UnusedMethodArgument
      raise NotImplementedError, "#{self.class}#upload_single is not defined"
    end

    def upload_splits
      @position = 0
      until source_input.eof?
        upload_single(next_split_filename)
        @position += byte_count
      end
    end

    def initialize_upload_vars(*upload_args)
      upload_args.pop if (@byte_count = parse_byte_value(upload_args.last))
      @remote_file_path = upload_args.pop

      unless upload_args.empty?
        source        = upload_args.pop
        @source_input = source.kind_of?(IO) ? source : File.open(source, "r")
      end
    end

    def parse_byte_value(bytes)
      match = bytes.to_s.match(BYTE_HASH_MATCH) || return

      bytes = match[:BYTE_NUM].to_f
      if match[:BYTE_QUALIFIER]
        bytes *= BYTE_HASH[match[:BYTE_QUALIFIER].downcase]
      end
      bytes.to_i
    end

    def handle_io_block
      if block_given?
        require "tmpdir"

        # create pathname, but don't create the file for it (next line)
        fifo_path = Pathname.new(Dir::Tmpname.create("") {})
        File.mkfifo(fifo_path)

        # For #Reasons(TM), the reader must be opened first
        @source_input = File.open(fifo_path.to_s, IO::RDONLY | IO::NONBLOCK)
        @input_writer = File.open(fifo_path.to_s, IO::WRONLY | IO::NONBLOCK)

        Thread.new do
          begin
            yield fifo_path      # send the path to the block to get executed
          ensure
            @input_writer.close  # close the file so we know we hit EOF (for #add)
          end
        end
      end
    end

    def reset_vars
      File.delete(@input_writer.path) if @input_writer
      @position, @byte_count, @remote_file_path, @source_input, @input_writer = nil
    end

    def next_split_filename
      "#{remote_file_path}.#{'%05d' % (@position / byte_count + 1)}"
    end

    def download_single(source, destination) # rubocop:disable Lint/UnusedMethodArgument
      raise NotImplementedError, "#{self.class}#download_single is not defined"
    end
  end
end
