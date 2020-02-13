# Interface module for helping define shared contexts for each interface that
# will be used with the generic "a file storage" shared example set
#
# When creating a new shared context, include this module, and define a
# `driver` method that can connects to the storage:
#
#   shared_context "with SuperFS", :with_super_fs do
#     include WithFileStorageInterface
#
#     def driver
#       SuperFS.driver
#     end
#   end
#
# The driver needs to then implement the following methods:
#
# - create_existing_file(size)
# - create_existing_dir
# - list_in_storage(file_or_dir)
# - size_in_storage(file_or_dir)
#
# These will be used in the custom_matchers of :exist_in_storage and
# :have_size_in_storage, as well as in the shared example set "a file storage",
# which is a set of examples defining the default behavior of all ManageIQ file
# storage providers.
#
module WithFileStorageInterface
  def driver
    raise NotImplementedError, "implement in submodule/shared_examples"
  end

  def existing_file_in_storage(size = 0)
    driver.create_existing_file(size)
  end

  def existing_file_storage_dir
    driver.create_existing_dir
  end

  class Driver
    # Before running a spec, create a example file of +size+ that can be
    # manipulated (downloaded, deleted, queried, etc.) as part of the spec.
    #
    # Return the path of the temp file created
    def create_existing_file(size = 0)
      raise NotImplementedError, "implement in driver subclass"
    end

    # Before running a spec, create a example dir that can be manipulated
    # (downloaded, deleted, queried, etc.) as part of the spec.
    #
    # Return the path of the temp dir created
    def create_existing_dir
      raise NotImplementedError, "implement in driver subclass"
    end

    # List the current file or directory.
    #
    # Returns an array (even if the argument is file, not a dir)
    #
    # If the file doesn't exist, the directory is empty, or the user doesn't
    # have permission to view the entry, return an empty array.
    def list_in_storage(file_or_dir)
      raise NotImplementedError, "implement in driver subclass"
    end

    # List the current file or directory.
    #
    # Returns an integer
    #
    # If the file doesn't exist or the user doesn't have permission to view the
    # entry, return 0.
    def size_in_storage(file_or_dir)
      raise NotImplementedError, "implement in driver subclass"
    end

    def to_path_string(path)
      (path.respond_to?(:path) && path.path) || URI.split(path.to_s)[5]
    end
  end
end
