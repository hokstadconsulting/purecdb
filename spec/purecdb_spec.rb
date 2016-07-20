require 'spec_helper'

describe PureCDB do
  let(:strio) { StringIO.new }

  # FIXME: Randomly create a larger set
  let(:pairs) {
    [
     ["foo", "bar"],
     ["1","2"],
     ["This is a test", "And a value"],
     ["Some more", "5678"],
     ["Blahrg","What is this?"],
     ["foo2","bar2"]
    ]
  }

  def create_cdb(*options)
    PureCDB::Writer.open(strio,*options) do |f|
      yield f if block_given?
    end
  end
  
  def read_cdb(*options)
    str = strio.string
    strio = StringIO.new(str) # Replace, as by this point it may be closed
    PureCDB::Reader.open(strio,*options).collect{|k,v| [k,v]}
  end

  def check_pairs_individually
    r = PureCDB.reader(StringIO.new(strio.string))
    pairs.each do |pair|
      # This presupposes no multi-value keys
      expect(r.values(pair[0])).to eq([pair[1]])
    end
  end

  def create_cdb_with_pairs *options
    create_cdb(*options) {|f| pairs.each { |pair| f.store(*pair) } }
  end


  def create_cdb_other(pairs)
    File.open("/tmp/cdbpairs","w") do |f|
      pairs.each do |k,v|
        f.write("+#{k.size},#{v.size}:#{k}->#{v}\n")
      end
      f.write("\n")
    end
    %x{cdb -c /tmp/test.cdb /tmp/cdbpairs}
    return File.open("/tmp/test.cdb","r")
  end


  describe PureCDB::Reader do
    specify "#mode will return 64 if the CDB file being read is 64 bits" do
      create_cdb(:mode => 64)
      r = PureCDB::Reader.open(StringIO.new(strio.string))
      expect(r.mode).to eq(64)
    end

    specify "#mode will return 32 if the CDB file being read is 32 bits" do
      create_cdb(:mode => 32)
      r = PureCDB::Reader.open(StringIO.new(strio.string))
      expect(r.mode).to eq(32)
    end

    specify "when reading back a CDB created by another CDB implementation, it should find all the key->value pairs" do
      f = create_cdb_other(pairs)
      r = PureCDB::Reader.open(f)
      expect(r.collect{|k,v| [k,v]}).to eq(pairs)
    end

    specify "when reading back a CDB created by another CDB implementation, looking up each key individually should return the values" do
      r = PureCDB::Reader.open(create_cdb_other(pairs))
      pairs.each do |k,v|
        expect(r.values(k)).to eq([v])
      end
    end

    specify "will use FFI::Mmap when passed a filename if possible" do
      f = create_cdb_other(pairs)
      r = PureCDB::Reader.open(f)
      expect(r.mmap?).to be true
      pairs.each do |k,v|
        expect(r.values(k)).to eq([v])
      end
      # Mmap will be switched off during read if it fails, so check again
      # after reading back the key/values
      expect(r.mmap?).to be true
    end
  end


  describe PureCDB::Writer do

    specify "Writer.open should be able to take an IO object and a block, and yield a Writer object to the block" do
      create_cdb do |f|
        expect(f).to be_a(PureCDB::Writer)
      end
    end

    # This step is non-obvious and not covered in the cdb spec, but at least some existing implementations
    # fail if the pointers are 0
    specify "when opening a CDB file for writing and not writing anything, the result should be a file where all hash pointers point to the end and have zero size" do
      wr = create_cdb
      expect(strio.string.size).to eq(wr.hash_size)
      expect(strio.string.unpack("V*").uniq).to eq([wr.hash_size,0])
    end

    specify "when writing a set of key-value pairs and subsequently reading them back again using the reader interface, all the key value pairs should be the same, and in order" do
      create_cdb_with_pairs
      expect(read_cdb).to eq(pairs)
    end

    specify "When creating a CDB64 file, the last 8 character will be 'cdb64:01'" do
      create_cdb(:mode => 64)
      expect(strio.string[-8..-1]).to eq("cdb64:01")
    end

    specify "After creating a CDB64 file, PureCDB::Reader will throw an error if explicitly asked to open it in 32 bit mode" do
      create_cdb(:mode => 64)
      expect { read_cdb(:mode => 32)}.to raise_error("64bit mode detected in file; options request 32bit mode")
    end

    specify "When creating a CDB in 64 bit mode, and reading it back again in 64 bit mode, all the key value pairs should be the same, and in order" do
      create_cdb_with_pairs(:mode => 64)
      expect(read_cdb(:mode => 64)).to eq(pairs)
    end

    specify "When creating a CDB64 and looking up each value key by key, all the values should be found" do
      create_cdb_with_pairs(:mode => 64)
      check_pairs_individually
    end

    specify "When creating a CDB32 and looking up each value key by key, all the values should be found" do
      create_cdb_with_pairs(:mode => 32)
      check_pairs_individually
    end

    specify "When creating a CDB with duplicate keys, '#values' should include all values for the key" do
      pairs2 = pairs.dup
      pairs2 << ["foo", "bar3"]
      create_cdb { |f| pairs2.each { |pair| f.store(*pair) } }

      r = PureCDB::Reader.open(StringIO.new(strio.string))
      pairs2res = pairs2.group_by{|a| a.first }.collect{|k,v| [k,v.collect{|a| a.last}]}

      pairs2res.each do |k,v|
        expect(r.values(k)).to eq(v)
      end
    end

    specify "When creating a CDB with duplicate keys, '#collect' should return each pair separately" do
      pairs2 = pairs.dup
      pairs2 << ["foo", "bar3"]
      create_cdb { |f| pairs2.each { |pair| f.store(*pair) } }

      r = PureCDB::Reader.open(StringIO.new(strio.string))

      c = r.collect.sort_by{|a| a.first}
      ps = pairs2.sort_by{|a| a.first}
      expect(c).to eq(ps)
    end


    specify "When creating a CDB64 of more than 4GB, all the values should be found when looking them up" do
      pending
      raise "Test not implemented"
    end
  end
end
