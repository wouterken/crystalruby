<table>
  <tr>
    <td><img src="logo.png" alt="logo" width="150"></td>
    <td>
      <h1 align="center">crystalruby</h1>
      <p align="center">
        <a href="https://rubygems.org/gems/crystalruby">
          <img alt="GEM Version" src="https://img.shields.io/gem/v/crystalruby?color=168AFE&include_prereleases&logo=ruby&logoColor=FE1616">
        </a><br>
        <a href="https://rubygems.org/gems/crystalruby">
          <img alt="GEM Downloads" src="https://img.shields.io/gem/dt/crystalruby?color=168AFE&logo=ruby&logoColor=FE1616">
        </a>
      </p>
    </td>
  </tr>
</table>

`crystalruby` is a gem that allows you to write Crystal code, inlined in Ruby. All you need is a modern crystal compiler installed on your system.

You can then turn simple methods into Crystal methods as easily as demonstrated below:

```ruby
require 'crystalruby'

module MyTestModule
  # The below method will be replaced by a compiled Crystal version
  # linked using FFI.
  crystalize [:int, :int] => :int
  def add(a, b)
    a + b
  end
end

# This method is run in Crystal, not Ruby!
MyTestModule.add(1, 2) # => 3
```

With as small a change as this, you should be able to see a significant increase in performance for some Ruby code.
E.g.

```ruby

require 'crystalruby'
require 'benchmark'

module Fibonnaci
  crystalize [n: :int32] => :int32
  def fib_cr(n)
    a = 0
    b = 1
    n.times { a, b = b, a + b }
    a
  end

  module_function

  def fib_rb(n)
    a = 0
    b = 1
    n.times { a, b = b, a + b }
    a
  end
end

puts(Benchmark.realtime { 1_000_000.times { Fibonnaci.fib_rb(30) } })
puts(Benchmark.realtime { 1_000_000.times { Fibonnaci.fib_cr(30) } })

```

```bash
3.193121999996947 # Ruby
0.29086600001028273 # Crystal
```

_Note_: The first run of the Crystal code will be slower, as it needs to compile the code first. The subsequent runs will be much faster.

You can call embedded crystal code, from within other embedded crystal code.
E.g.

```ruby
module Cache

  crystalize [key: :string] => :string
  def redis_get(key)
    rds = Redis::Client.new
    value = rds.get(key).to_s
  end

  crystalize [key: :string, value: :string] => :string
  def redis_set_and_return(key)
    redis = Redis::Client.new
    redis.set(key, value)
    Cache.redis_get(key)
  end
end
Cache.redis_set_and_return('test', 'abc')
puts Cache.redis_get('test')
```

```bash
$ abc
```

## Syntax

### Ruby Compatible

Where the Crystal syntax is also valid Ruby syntax, you can just write Ruby.
It'll be compiled as Crystal automatically.

E.g.

```ruby
crystalize [a: :int, b: :int] => :int
def add(a, b)
  puts "Adding #{a} and #{b}"
  a + b
end
```

### Crystal Compatible

Some Crystal syntax is not valid Ruby, for methods of this form, we need to
define our functions using a :raw parameter.

```ruby
crystalize :raw, [a: :int, b: :int] => :int
def add(a, b)
  <<~CRYSTAL
    c = 0_u64
    a + b + c
  CRYSTAL
end
```

## Types

Currently primitive types are supported.
Composite types are supported using JSON serialization.
C-Structures are a WIP.
To see the list of currently supported primitive type mappings of FFI types to crystal types, you can check: `CrystalRuby::Typemaps::CRYSTAL_TYPE_MAP`
E.g.

```ruby
CrystalRuby::Typemaps::CRYSTAL_TYPE_MAP
=> {:char=>"Int8",
 :uchar=>"UInt8",
 :int8=>"Int8",
 :uint8=>"UInt8",
 :short=>"Int16",
 :ushort=>"UInt16",
 :int16=>"Int16",
 :uint16=>"UInt16",
 :int=>"Int32",
 :uint=>"UInt32",
 :int32=>"Int32",
 :uint32=>"UInt32",
 :long=>"Int32 | Int64",
 :ulong=>"UInt32 | UInt64",
 :int64=>"Int64",
 :uint64=>"UInt64",
 :long_long=>"Int64",
 :ulong_long=>"UInt64",
 :float=>"Float32",
 :double=>"Float64",
 :bool=>"Bool",
 :void=>"Void",
 :string=>"String"}
```

## Composite Types (using JSON serialization)

The library allows you to pass complex nested structures using JSON as a serialization format.
The type signatures for composite types can use ordinary Crystal Type syntax.
Type conversion is applied automatically.

E.g.

```ruby
crystalize [a: json{ Int64 | Float64 | Nil }, b: json{ String | Array(Bool)  } ] => :void
def complex_argument_types
  puts "Got #{a} and #{b}"
end

crystalize [] => json{ Int32 | String | Hash(String, Array(NamedTuple(hello: Int32)) | Time)}
def complex_return_type
  return {
    "hello" => [
      {
        hello: 1,
      },
    ],
    "world" => Time.utc
  }
end
```

Type signatures validations are applied to both arguments and return types.

```ruby
[1] pry(main)> Foo.complex_argument_types(nil, "test")
Got  and test
=> nil

[2] pry(main)> Foo.complex_argument_types(88, [true, false, true])
Got 88 and [true, false, true]
=> nil

[3] pry(main)> Foo.complex_argument_types(88, [true, false, 88])
ArgumentError: Expected Bool but was Int at line 1, column 15
from crystalruby.rb:303:in `block in compile!'
```

## Named Types

You can name your types, for more succinct method signatures.
The type names will be mirrored in the generated Crystal code.
E.g.

```ruby

IntArrOrBoolArr = crtype{ Array(Bool) | Array(Int32) }

crystalize [a: IntArrOrBoolArr] => json{ IntArrOrBoolArr }
def method_with_named_types(a)
  return a
end
```

## Exceptions

Exceptions thrown in Crystal code can be caught in Ruby.

## Installing shards and writing non-embedded Crystal code

You can use any Crystal shards and write ordinary, stand-alone Crystal code.

The default entry point for the crystal shared library generated by the gem is
inside `./crystalruby/src/main.cr`. This file is not automatically overridden by the gem, and is safe for you to define and require new files relative to this location to write additional stand-alone Crystal code.

You can define shards inside `./crystalruby/src/shard.yml`
Run the below to install new shards

```bash
bundle exec crystalruby install
```

Remember to require these installed shards after installing them. E.g. inside `./crystalruby/src/main.cr`

You can edit the default paths for crystal source and library files from within the `./crystalruby.yaml` config file.

### Wrapping Crystal code in Ruby

Sometimes you may want to wrap a Crystal method in Ruby, so that you can use Ruby before the Crystal code to prepare arguments, or after the Crystal code, to apply transformations to the result. A real-life example of this might be an ActionController method, where you might want to use Ruby to parse the request, perform auth etc., and then use Crystal to perform some heavy computation, before returning the result from Ruby.
To do this, you simply pass a block to the `crystalize` method, which will serve as the Ruby entry point to the function. From within this block, you can invoke `super` to call the Crystal method, and then apply any Ruby transformations to the result.

```ruby
module MyModule
  crystalize [a: :int32, b: :int32] => :int32 do |a, b|
    # In this example, we perform automated conversion to integers inside Ruby.
    # Then add 1 to the result of the Crystal method.
    result = super(a.to_i, b.to_i)
    result + 1
  end
  def add(a, b)
    a + b
  end
end

MyModule.add("1", "2")
```

### Release Builds

You can control whether CrystalRuby builds in debug or release mode by setting following config option

```ruby
CrystalRuby.configure do |config|
  config.debug = false
end
```

By default, Crystal code is only JIT compiled. In production, you likely want to compile the Crystal code ahead of time. To do this, you can create a dedicated file which

- Preloads all files Ruby code with embedded crystal
- Forces compilation.

E.g.

```ruby
# E.g. crystalruby_build.rb
require "crystalruby"

CrystalRuby.configure do |config|
  config.debug = false
end

require_relative "foo"
require_relative "bar"

CrystalRuby.compile!
```

Then you can run this file as part of your build step, to ensure all Crystal code is compiled ahead of time.

### Troubleshooting

The logic to detect when to JIT recompile is not robust and can end up in an inconsistent state. To remedy this it is useful to clear out all generated assets and build from scratch.

To do this execute:

```bash
bundle exec crystalruby clean
```

## Design Goals

`crystalruby`'s primary purpose is provide ergonomic access to Crystal from Ruby, over FFI.
For simple usage, advanced knowledge of Crystal should not be required.

However, the abstraction it provides should remain simple, transparent, and easy to hack on and it should not preclude users from supplementing its capabilities with a more direct integration using ffi primtives.

It should support escape hatches to allow it to coexist with code that performs a more direct [FFI](https://github.com/ffi/ffi) integration to implement advanced functionality not supported by `crystalruby`.

The library is currently in its infancy. Planned additions are:

- Replace existing checksum process, with one that combines results of inline and external crystal to more accurately detect when recompilation is necessary.
- Simple mixin/concern that utilises `FFI::Struct` for bi-directional passing of Ruby objects and Crystal objects (by value).
- Install command to generate a sample build script, and supports build command (which simply verifies then invokes this script)
- Call Ruby from Crystal using FFI callbacks (implement `.expose_to_crystal`)
- Support long-lived synchronized objects (through use of synchronized memory arena to prevent GC).
- Support for passing `crystalruby` types by reference (need to contend with GC).
- Explore mechanisms to safely expose true parallelism using [FFI over Ractors](https://github.com/ffi/ffi/wiki/Ractors)

## Installation

To get started, add this line to your application's Gemfile:

```ruby
gem 'crystalruby'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install crystalruby
```

`crystalruby` requires some basic initialization options inside a crystalruby.yaml file in the root of your project.
You can run `crystalruby init` to generate a configuration file with sane defaults.

```bash
crystalruby init
```

```yaml
crystal_src_dir: "./crystalruby/src"
crystal_lib_dir: "./crystalruby/lib"
crystal_main_file: "main.cr"
crystal_lib_name: "crlib"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wouterken/crystalruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/wouterken/crystalruby/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the `crystalruby` project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/wouterken/crystalruby/blob/master/CODE_OF_CONDUCT.md).
