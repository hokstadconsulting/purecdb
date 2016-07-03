module PureCDB

  #
  # Base class with shared functionality for PureCDB::Reader and
  # PureCDB::Writer that abstracts away 32 bit vs. 64 bit format
  # details. You should not need to use this directly.
  # 
  class Base
    # The CDB format contains 256 separate hashes by default.
    DEFAULT_NUM_HASHES = 256

    # Keys and values have a length indicator. In the standard format this is 4 bytes long.
    # In the 64 bit format, this value is multiplied by 2.
    DEFAULT_LENGTH_SIZE  = 4

    # The "pointer" (offset) pointing to a given hash is this many bytes by default. In the
    # 64 bit format this is multiplied by 2.
    DEFAULT_HASHPTR_SIZE = 4

    # Number of bytes that will be buffered
    BUFFER_SIZE = 4096

    # Magic cookied used to indicate that this is a 64 bit (non-standard) CDB file
    # rather than a 32-bit CDB file.
    CDB64_MAGIC = "cdb64:01"


    # The actual number of hashes (depends on 32 vs 64 bit)
    attr_reader :num_hashes

    # The actual number of bytes per length field (depends on 32 vs 64 bit)
    attr_reader :length_size

    # The actual number of bytes per hash pointer (depends on 32 vs 64 bit)
    attr_reader :hashptr_size

    # 32 for 32-bit files, 64 for 64-bit files.
    attr_reader :mode

    # The size of each hash slot
    def hashref_size
      hashptr_size + length_size
    end

    # The size of the table of pointers to the hashes
    def hash_size
      hashref_size * num_hashes
    end

    #
    # Used by PureCDB::Reader and PureCDB::Writer to set 32/64 bit mode
    # 
    def set_mode mode
      @mode = mode
      @num_hashes = DEFAULT_NUM_HASHES
      if @mode == 64
        @length_size  = DEFAULT_LENGTH_SIZE  * 2
        @hashptr_size = DEFAULT_HASHPTR_SIZE * 2
      else
        @length_size  = DEFAULT_LENGTH_SIZE
        @hashptr_size = DEFAULT_HASHPTR_SIZE
      end
    end

    #
    # Parses options and sets mode. Do not call directly - 
    # Use PureCDB::Reader or PureCDB::Writer
    # 
    def initialize *options
      mode = :detect
      options.each do |h|
        h.each do |opt,val|
          mode = val
        end
      end

      # Used to speed up 64bit pack/unpack
      @little_endian = [123456789].pack("L") == [123456789].pack("V")

      if mode == :detect
        @mode = :detect
      else
        set_mode(mode)
      end
    end


    # Used by PureCDB::Reader and PureCDB::Writer to set an IO-like object
    # to read from/write to
    def set_stream target
      if target.respond_to?(:sysseek)
        @io = target
      else
        @io = SysIOWrapper.new(target)
      end
      @name = "<stream>"
    end


    # As per http://cr.yp.to/cdb/cdb.txt
    def hash key
      h = 5381 # Magic
      key.to_s.each_byte do |c|
        # We & it since Ruby uses big ints,
        # so it can't overflow and need to be clamped.

        # FIXME: For 64 bit version we use 64 bit numbers in the slots, so could increase this.
        h = (((h << 5) + h) ^ c) & 0xffffffff
      end
      h
    end

    private

    # Due to Array#pack's lack of a little/big endian specific 64 bit operator
    def ary_pack(ary)
      if @mode == 32
        ary.pack("V*")
      elsif @little_endian
        ary.pack("Q*")
      else
        ary.collect {|a| [a & 0xffffffff, (a >> 32) & 0xffffffff] }.flatten.pack("V*")
      end
    end

    # Due to String#unpack's lack of a little/big endian specific 64 bit operator
    def ary_unpack(data, num)
      if @mode == 32
        data.unpack("V#{num}")
      elsif @little_endian
        data.unpack("Q#{num}")
      else
        ret = []
        data = data.unpack("V#{num*2}")
        data.each_slice(2) {|a| ret << (a[0] + (a[1] << 32)) }
        ret
      end
    end
  end

  #
  # Wrap an object that does not have all of +sysseek/syswrite/sysread+
  # but that does have +seek/write/read+ with similar semantics. This is
  # primarily intended for use with +StringIO+, which lacks +syseek+
  # 
  # It is automatically interjected on creating a +PureCDB::Reader+ or
  # +PureCDB::Writer if the IO-like object that is passed lacks +sysseek+
  # so you should normally not need to think about this class
  #
  class SysIOWrapper
    def initialize target
      @target = target
    end

    # Delegates to +seek+
    def sysseek(offset,mode)
      @target.seek(offset,mode)
    end

    # Delegates to +read+
    def sysread(size)
      @target.read(size)
    end

    # Delegates to +write+
    def syswrite(buffer)
      @target.write(buffer)
    end
  end

end
