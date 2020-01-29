module ManageIQ
  module FileStorage
    class TypeRegistry
      def self.storage_interface_classes
        @storage_interface_classes ||= {}
      end

      def self.register_file_storage(klass)
        storage_interface_classes[klass.uri_scheme] = klass
      end

      module InterfaceClassMethods
        def storage_interface_classes
          TypeRegistry.storage_interface_classes
        end

        def register_file_storage(klass)
          TypeRegistry.register_file_storage(klass)
        end
      end
    end
  end
end
