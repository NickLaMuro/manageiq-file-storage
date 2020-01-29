require 'manageiq/file_storage/interface'

module ManageIQ
  module FileStorage
    class InvalidSchemeError < ArgumentError
      def initialize(bad_scheme = nil)
        super(error_message(bad_scheme))
      end

      def error_message(bad_scheme)
        valid_schemes = ::ManageIQ::FileStorage.storage_interface_classes.keys.inspect
        "#{bad_scheme} is not a valid ManageIQ::FileStorage uri scheme. Accepted schemes are #{valid_schemes}"
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
      @storage_interface_classes ||= ObjectSpace.each_object(::Class).each_with_object({}) do |klass, memo|
        next unless klass < Interface
        memo[klass.uri_scheme] = klass if klass.uri_scheme
      end
    end
  end
end
