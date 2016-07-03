module PureCDB

  #
  # Read 32 bit or 54 bit CDB file CDB files.
  # 
  class Reader < Base
    include Enumerable

    # Open a CDB file for reading.
    # 
    # :call-seq:
    #   r = PureCDB::Reader.new(file)
    #   r = PureCDB::Reader.new(file, options)
    #   PureCDB::Reader.new(file)  {|r| ... }
    #   PureCDB::Reader.new(file, options) {|r| ... }
    #
    # +file+ can be a String or any object that meets the minimum
    # requirements, which means having  #sysseek, #sysopen to and #sysclos
    # which does not arbitrarily sttop access ot it.
    #
    # If Mmap is available, the code will attempt to use it.
    # 
    def initialize target, *options
      if target.is_a?(String)
        @name = target
        @io = File.new(target,"rb")
        raise "Unable to open file #{target}" if !@io
      else
        set_stream(target)
      end
      
      @io.sysseek(-8,IO::SEEK_END)
      tail = @io.sysread(8)
      raise "Unable to read trailing 8 bytes for magic cookie" if tail.size != 8
      mode = tail == CDB64_MAGIC ? 64 : 32

      super *options
      if @mode == :detect
        set_mode(mode)
      elsif @mode != mode
        raise "#{mode}bit mode detected in file; options request #{@mode}bit mode"
      end

      # FIXME: It seems like there are bugs triggered if mmap fails                       
      @m = Mmap.new(target,"r", Mmap::MAP_SHARED) rescue nil
      read_hashes

      raise "Invalid File (Hashes are all empty)" if @hashes.uniq == [0]

      if block_given?
        yield(self)
        close
      else
      end
    end

    #
    # Shortcut for PureCDB::Reader.new(target,options) .. 
    #
    def self.open(target, *options, &block)
      Reader.new(target, *options, &block)
    end

    def close
      @io.close if @io
      @m.unmap if @m
      @m = nil
      @io = nil
    end

    def each
      pos = hash_size
      hoff0 = @hashes[0]
      while pos < hoff0
        key, value = *read_entry(pos)
        yield(key,value)
        pos += key.length + value.length + hashref_size
      end
    end

    def read_entry(pos)
      keylen, datalen = read_header(pos)
      return nil,nil if !keylen
      pos += hashref_size
      rkey = read(pos .. pos + keylen - 1)
      pos += keylen
      value = read(pos .. pos + datalen - 1)
      return rkey, value
    end

    def values(key)
      h = hash(key)

      hoff = @hashes[(h % 256)*2]
      hlen = @hashes[(h % 256)*2 + 1]

      return [] if hlen == 0
      off = (h / 256) % hlen

      vals = []

      # FIXME: Is this potentially an infinite loop (if full)?
      # Easy to avoid by exiting if off reaches the same value twice.

      while
          (slot = read(hoff + off * hashref_size .. hoff + off * hashref_size + hashref_size - 1)) &&
          (dslot = ary_unpack(slot,2)) && dslot[1] != 0

        if dslot[0] == h
          pos = dslot[1]

          rkey, value = read_entry(pos)
          if rkey == key
            vals << value
          end
        end
        off = (off + 1) % hlen
      end
      return vals
    end

    private

    # Warning: This will be very slow if not mmap'd
    def read r
      @m = nil
      if @m
        res = @m[r]
        return res if res
        
        # Falling back on IO.read - mmap failed"
        @m = nil
      end
      
      @io.sysseek(r.first, IO::SEEK_SET)
      return @io.sysread(r.last-r.first+1)
    end

    def read_hashes
      r = read(0..(hash_size-1))
      raise "Unable to read hashes for '#{@name}' / #{@target.inspect}" if !r
      @hashes = ary_unpack(r,num_hashes*2)
    end

    def read_header pos
      data = read(pos .. pos+ hashref_size - 1)
      return nil,nil if !data
      keylen,datalen = ary_unpack(data,2)
      raise "Too large" if keylen > 1048576 || datalen > 1048576 * 1024
      return keylen, datalen
    end
  end
end
