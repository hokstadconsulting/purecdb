begin
    require 'ffi/mmap'
rescue LoadError
end

module PureCDB

  #
  # Read 32 bit or 64 bit CDB files.
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
    # requirements, which means having  #sysseek, #sysopen to and #sysclose
    # which does not arbitrarily sttop access ot it.
    #
    # If Mmap is available, the code will attempt to use it if target is a
    # filename
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

      @m = FFI::Mmap.new(target,"r", FFI::Mmap::MAP_SHARED) rescue nil
      read_hashes

      raise "Invalid File (Hashes are all empty)" if @hashes.uniq == [0]

      if block_given?
        yield(self)
        close
      else
      end
    end

    #
    # Is the file mmap'ed? Note that this may in theory return true right after
    # opening the file, but return false after attempting to read if the 
    # attempt to read from the mmap object fails for whatever reason. 
    #
    # I'm not sure that can ever happen, but to be 100% sure, check *after* a
    # lookup
    #
    def mmap?
       @m.nil? == false
    end

    #
    # Alternative to PureCDB::Reader.new(target,options) ..
    #
    def self.open(target, *options, &block)
      Reader.new(target, *options, &block)
    end

    #
    # Close the CDB file
    #
    def close
      @io.close if @io
      @m.munmap if @m
      @m = nil
      @io = nil
    end

    # Iterate over all key/value pairs in the order they occur in the file.
    # This is *not* sorted or insertion order.
    #
    # +each+ will yield each key,value pair separately even when a key is
    # duplicate.
    def each
      pos = hash_size
      hoff0 = @hashes[0]
      while pos < hoff0
        key, value = *read_entry(pos)
        yield(key,value)
        pos += key.length + value.length + hashref_size
      end
    end

    # Returns all values for +key+ in an array
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

    def read_entry(pos)
      keylen, datalen = read_header(pos)
      return nil,nil if !keylen
      pos += hashref_size
      rkey = read(pos .. pos + keylen - 1)
      pos += keylen
      value = read(pos .. pos + datalen - 1)
      return rkey, value
    end


    # Warning: This will be very slow if not mmap'd
    def read r
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
