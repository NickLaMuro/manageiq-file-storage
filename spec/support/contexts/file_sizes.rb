shared_context "file sizes" do
  let!(:one_kilobyte)  { 1024 }
  let!(:one_megabyte)  { 1024 * one_kilobyte }
  let!(:two_megabytes) { one_megabyte * 2 }
  let!(:ten_megabytes) { one_megabyte * 10 }
  let!(:one_gigabyte)  { 1024 * one_megabyte }
end
