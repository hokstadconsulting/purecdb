module PureCDB
  class Writer < Base
    # This just needs to be <= 1. The lower it is, the fewer records will collide. The closer to 1 it is,
    # the more frequently the reader may have to engage in potentially lengthy (worst case scanning all the
    # records) probing to find the right entry
    def hash_fill_factor
      0.7
    end

    def initialize target, *options
      super *options

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

    def close
      write_hashes
      write_hashptrs
      @io.close if @io.respond_to?(:close)
    end
   
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
