RSpec.shared_examples "adding files" do |dest_path|
  include_context "generated tmp files"

  let(:dest_path) { dest_path }

  it "copies single files" do
    expect(subject.add(source_path.to_s, dest_path.to_s)).to eq(dest_path.to_s)
    expect(dest_path).to exist_in_file_storage
    expect(dest_path).to have_size_in_storage_of(ten_megabytes)
  end

  it "copies file to splits" do
    expected_splitfiles = (1..5).map do |suffix|
      "#{dest_path}.0000#{suffix}"
    end

    File.open(source_path) do |f| # with an IO object this time
      subject.add(f, dest_path.to_s, "2M")
    end

    expected_splitfiles.each do |filename|
      expect(filename).to exist_in_file_storage
      expect(filename).to have_size_in_storage_of(two_megabytes)
    end
  end

  it "can take input from a command" do
    expected_splitfiles = (1..5).map do |suffix|
      "#{dest_path}.0000#{suffix}"
    end

    subject.add(dest_path.to_s, "2M") do |input_writer|
      `#{Gem.ruby} -e "File.write('#{input_writer}', '0' * #{tmpfile_size})"`
    end

    expected_splitfiles.each do |filename|
      expect(filename).to exist_in_file_storage
      expect(filename).to have_size_in_storage_of(two_megabytes)
    end
  end

  context "with slightly a slightly smaller input file than 10MB" do
    let(:tmpfile_size) { ten_megabytes - one_kilobyte }

    it "properly chunks the file" do
      expected_splitfiles = (1..10).map do |suffix|
        "#{dest_path}.%<suffix>05d" % {:suffix => suffix}
      end

      # using pathnames this time
      subject.add(source_path, dest_path.to_s, one_megabyte)

      expected_splitfiles[0, 9].each do |filename|
        expect(filename).to exist_in_file_storage
        expect(filename).to have_size_in_storage_of(one_megabyte)
      end

      last_split = expected_splitfiles.last
      expect(last_split).to exist_in_file_storage
      expect(last_split).to have_size_in_storage_of(one_megabyte - one_kilobyte)
    end
  end
end

RSpec.shared_examples "a file storage" do |uri_scheme|
  describe "#add" do
    context "using a 'relative path'" do
      include_examples "adding files", "path/to/file"
    end

    context "using a 'absolute path'" do
      include_examples "adding files", "/path/to/my_file"
    end

    context "using a uri" do
      include_examples "adding files", "#{uri_scheme}://localhost/foo/bar/baz"
    end
  end

  describe "#download" do
    include_context "file sizes"

    let(:dest_path)   { Dir::Tmpname.create("") { |name| name } }
    let(:source_file) { existing_file_in_storage(ten_megabytes) }
    let(:source_path) { File.basename(source_file.path) }

    after { File.delete(dest_path) if File.exist?(dest_path) }

    it "downloads the file" do
      subject.download(dest_path, source_path)

      # Sanity check that what we are downloading is the size we expect
      expect(source_path).to exist_in_file_storage
      expect(source_path).to have_size_in_storage_of(ten_megabytes)

      expect(File.exist?(dest_path)).to be true
      expect(File.stat(dest_path).size).to eq(ten_megabytes)
    end

    it "can take input from a command" do
      source_data = nil
      subject.download(nil, source_path) do |input_writer|
        source_data = `#{Gem.ruby} -e "print File.read('#{input_writer}')"`
      end

      # Sanity check that what we are downloading is the size we expect
      # (and we didn't actually download the file to disk)
      expect(File.exist?(dest_path)).to be false
      expect(source_path).to exist_in_file_storage
      expect(source_path).to have_size_in_storage_of(ten_megabytes)

      # Nothing written, just printed the streamed file in the above command
      expect(source_data.size).to eq(ten_megabytes)
    end
  end

  describe "#magic_number_for" do
    include_context "file sizes"

    let(:source_file) { existing_file_in_storage(ten_megabytes) }
    let(:source_path) { File.basename(source_file.path) }

    it "returns 256 bytes by default" do
      result = subject.magic_number_for(source_path)

      expect(result.size).to eq(256)
      expect(result).to      eq("0" * 256)
    end

    describe "with a hash of accepted magics" do
      it "returns key for the passed in magic number value" do
        magics = { :zero => "000", :one => "1", :foo => "bar" }
        result = subject.magic_number_for(source_path, :accepted => magics)

        expect(result).to eq(:zero)
      end
    end
  end
end
