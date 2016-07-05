# PureCDB

A Pure Ruby CDB reader/writer w/64 bit extensions

For information about CDB, see: http://cr.yp.to/cdb.html

The motivation for writing this was:

 * Bernstein's CDB format can only handle files up to 4GB. For a past project
 we needed a simple CDB style file for datasets several times that.
 
 * The C library is under a license that prevents us from releasing modified versions of it,
 but the format is so simple that writing our own reader and writer was easy.
 
 * We don't like depending on C extensions for Ruby code if we don't have to.



## Installation

Add this line to your application's Gemfile:

```ruby
gem 'purecdb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install purecdb

## Basic Usage

To create a 32 bit (standard) CDB file:

```ruby
    PureCDB::Writer.open("/tmp/somecdbfile.cdb") do |cdb| 
     cdb.add("key","value")
    end
```

To instead create a 64 bit file, pass {mode: 64} as the second argument to PureCDB::Writer#open .


To read a CDB file (auto-detecting standard 32-bit or extended 64-bit) CDB files:

```ruby
    PureCDB::Reader.open("/tmp/somecdbfile.cdb") do |r|
       p r.values("key")
    end
```

To require a 32 or 64 bit file specifically, pass {mode: 32} or {mode: 64} as
the second argument to PureCDB::Reader#open.

See PureCDB::Reader#new for additional usage.


## 64-bit Format

The 64 bit file format follows http://cr.yp.to/cdb/cdb.txt *except* that any
reference to 32-bit should be replaced by 64-bit, and that a 64 bit file
*ends* with the magic cookie "cdb64:01"




## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release` to create a git tag for the version, push git commits
and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

To run the Rspec tests, you need tinycdb or a command-line compatible implementation
installed for interoperability tests.


## Contributing

1. Fork it ( https://github.com/hokstadconsulting/purecdb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
