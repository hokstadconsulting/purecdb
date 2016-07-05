module PureCDB
  #
  # Write 32 or 64 bit CDB files
  #
  # == Memory considerations
  #
  # While the entry is written to the target object immediately on calling #store, the actual
  # hash tables can not be written until the full dataset is ready. You must therefore be able
  # to hold the hash of each key (including duplicates) and the position in the file the full
  # netry is stored at in memory while building the CDB file.
  #
  # It would be possible to write this to a temporary file at the cost of performance, but the
  # current implementation does not do this.
  #
  # As a compromise, the current implementation stores the hashes and positions as a BER encoded
  # string per hash bucket until it is ready to write it to disk.
  #
  class Writer < Base
    # How full any given hash table is allowed to get, as a float between 0 and 1.
    #
    # Needs to be <= 1. The lower it is, the fewer records will collide. The closer to 1 it is,
    # the more frequently the reader may have to engage in potentially lengthy (worst case
    # scanning all the records) probing to find the right entry
    attr_accessor :hash_fill_factor

    # Open a CDB file for writing, or preparing an IO like object for writing.
    #
    # :call-seq:
    #   w = PureCDB::Writer.new(target)
    #   w = PureCDB::Writer.new(target, *options)
    #   PureCDB::Writer.new(target)  {|w| ... }
    #   PureCDB::Writer.new(target, *options) {|w| ... }
    #
    # If +:mode+ is passed in +options+, it must be the integers 32 or 64, indicating whether
    # you wish to write a standard (32 bit) CDB file, or a 64 bit CDB-like file. The default
    # is 32.
    #
    # If +target+ is a +String+ it is treated as a filename of a file to be opened to write to.
    # Otherwise +target+ is assumed to be an IO-like object that ideally responds to #sysseek
    # and #syswrite. If it doesn't, it will be wrapped with an object delegating #sysseek and
    # #syswrite to #seek and #write respectively, and these must be present.
    #
    # (+IO+ and +StringIO+ both satisfy these requirements)
    #
    # If passed a block, the writer is yielded to the block and PureCDB::Writer#close is called
    # afterwards.
    #
    # **WARNING:** To complete writing the hash tables, you *must* ensure #close is called
    # when you are done.
    #
    def initialize target, *options
      super *options

      @hash_fill_factor = 0.7

      set_mode(32) if @mode == :detect

      if target.is_a?(String)
        @io = File.new(target,"wb")
      else
        set_stream(target)
      end

      @hashes = [nil] * num_hashes

      @hashptrs = [0] * num_hashes * 2
      write_hashptrs

      @pos = hash_size

      if block_given?
        yield(self)
        close
        nil
      else
        self
      end
    end

    # Write out the hashes and hash pointers, and close the target if it responds to #close
    #
    def close
      write_hashes
      write_hashptrs
      @io.close if @io.respond_to?(:close)
    end

    # Store 'value' under 'key'.
    #
    # Multiple values can we stored for the same key by calling #store multiple times
    # with the same key value.
    def store key,value
      # In an attempt to save memory, we pack the hash data we gather into
      # strings of BER compressed integers...
      h = hash(key)
      hi = (h % num_hashes)
      @hashes[hi] ||= ""

      header = build_header(key.length, value.length)
      @io.syswrite(header+key+value)
      size = header.size + key.size + value.size
      @hashes[hi] += [h,@pos].pack("ww") # BER compressed
      @pos += size
    end

    #
    # Alternative to PureCDB::Writer.new(target,options) ..
    #
    def self.open target, *options, &block
      Writer.new(target, *options, &block)
    end
   
   private
    def write_hashes
      @hashes.each_with_index do |h,i|
        if !h || h.size == 0
          @hashptrs[i*2] = @pos
          @hashptrs[i*2+1] = 0
        else
          @hashptrs[i*2] = @pos

          len = (h.size / hash_fill_factor).ceil
          @hashptrs[i*2+1] = len

          ary = [0] * len * 2

          free_slots = len
          h.unpack("w*").each_slice(2) do |entry|
            raise "Oops; hash buffer too small (hash size: #{h.size}, buffer size: #{len})" if free_slots <= 0

            hk = entry[0]
            off = ((hk / num_hashes) % len).floor
            while ary[off*2] != 0
              off = (off + 1) % len
            end
            free_slots -= 1
            ary[off*2] = entry[0]
            ary[off*2+1] = entry[1]
          end
          size = ary.size / 2 * (length_size + hashptr_size)

          write_hash_slots(ary)
          @pos += size
        end
      end
      @io.syswrite(CDB64_MAGIC) if self.mode == 64
    end

    def build_header key_length, value_length
      ary_pack([key_length, value_length])
    end

    def write_hash_slots(ary)
      @io.syswrite(ary_pack(ary))
    end

    def write_hashptrs
      @io.sysseek(0,IO::SEEK_SET)
      @io.syswrite(ary_pack(@hashptrs))
    end
  end

end
