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

`crystalruby` is a gem that allows you to write Crystal code, inlined in Ruby.
All you need is a modern crystal compiler installed on your system.

You can then turn simple methods into Crystal methods as easily as demonstrated below:

```ruby
require 'crystalruby'

# The below method will be replaced by a compiled Crystal version
# linked using FFI.

crystallize
def add(a: Int32, b: Int32, returns: Int32)
  a + b
end

# This method is run in Crystal, not Ruby!
puts add(1, 2) # => 3
```

With as small a change as this, you should be able to see a significant increase in performance for several classes of CPU or memory intensive code.
E.g.

```ruby
require 'crystalruby'
require 'benchmark'

crystallize :int32
def count_primes_upto_cr(n: Int32)
  (2..n).each.count do |i|
    is_prime = true
    (2..Math.isqrt(i)).each do |j|
      if i % j == 0
        is_prime = false
        break
      end
    end
    is_prime
  end
end

def count_primes_upto_rb(n)
  (2..n).each.count do |i|
    is_prime = true
    (2..Integer.sqrt(i)).each do |j|
      if i % j == 0
        is_prime = false
        break
      end
    end
    is_prime
  end
end

puts Benchmark.realtime { count_primes_upto_rb(1_000_000) }
puts Benchmark.realtime { count_primes_upto_cr(1_000_000) }
```

```bash
3.04239400010556 # Ruby
0.06029000016860 # Crystal (50x faster)
```

_Note_: The first, unprimed run of the Crystal code will be slower, as it needs to compile the code first. The subsequent runs will be much faster.

You can call embedded crystal code, from within other embedded crystal code.
The below crystallized method `redis_set_and_return` calls the `redis_get` method, which is also crystallized.
Note the use of the shard command to define the Redis shard dependency of the crystallized code.
E.g.

```ruby
require 'crystalruby'

module Cache

  shard :redis, github: 'jgaskins/redis'

  crystallize :string
  def redis_get(key: String)
    rds = Redis::Client.new
    value = rds.get(key).to_s
  end

  crystallize :string
  def redis_set_and_return(key: String, value: String)
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

To define a method that will be compiled as Crystal, you can use the `crystallize` method.
You must also provide types, for the parameters and return type.

### Method Signatures
Parameter types are defined using kwarg syntax, with the type as the value.
E.g.
```ruby
def foo(a: Int32, b: Array(Int), c: String)
```

Return types are specified using either a lambda, returning the type, as the first argument to the crystallize method, or the special `returns` kwarg.

E.g.

```ruby
# Returns an Int32
crystallize ->{ Int32 }
def returns_int32
  3
end

# You can use the symbol shortcode for primitive types
crystallize :int32
def returns_int32
  3
end

# Define the return type directly using the `returns` kwarg
crystallize
def returns_int32(returns: Int32)
  3
end
```

### Ruby Compatible Method Bodies
Where the Crystal syntax of the method body is also valid Ruby syntax, you can just write Ruby.
It'll be compiled as Crystal automatically.

E.g.

```ruby
crystallize :int
def add(a: :int, b: :int)
  puts "Adding #{a} and #{b}"
  a + b
end
```

### Crystal-only Syntax
Some Crystal syntax is not valid Ruby, for methods of this form, we need to
define our functions using the `raw: true` option

```ruby
crystallize raw: true
def add(a: :int, b: :int)
  <<~CRYSTAL
    c = 0_u64
    a + b + c
  CRYSTAL
end
```

### Upgrading from version 0.2.x

#### Change in type signatures
In version 0.2.x, argument and return types were passed to the `crystallize` method using a different syntax:

```ruby
# V <= 0.2.x
crystallize [arg1: :arg1_type , arg2: :arg2_type] => :return_type
def foo(arg1, arg2)
```

In crystalruby > 0.3.x, argument types are now passed as keyword arguments, and the return type is passed either as a keyword argument
or as the first argument to crystallize (either using symbol shorthand, or a Lambda returning a Crystal type).

```ruby
# V >= 0.3.x
crystallize :return_type
def foo(arg1: :arg1_type, arg2: :arg2_type)

# OR use the `returns` kwarg
crystallize
def foo(arg1: :arg1_type, arg2: :arg2_type, returns: :return_type)
```


## Getting Started

The below is a stand-alone one-file script that allows you to quickly see crystalruby in action.

```ruby
# crystalrubytest.rb
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'crystalruby'
end

require 'crystalruby'

crystallize :int
def add(a: :int, b: :int)
  a + b
end

puts add(1, 2)
```

## Types
Most built-in Crystal Types are available. You can also use the `:symbol` short-hand for primitive types.

### Supported Types
* UInt8 UInt16 UInt32 UInt64 Int8 Int16 Int32 Int64 Float32 Float64
* Time
* Symbol
* Nil
* Bool
* Container Types (Tuple, Tagged Union, NamedTuple, Array, Hash)
* Proc

Primitive types short-hands
* :char :uchar :int8 :uint8 :short :ushort :int16 :uint16
* :int :uint :int32 :uint32 :long :ulong :int64 :uint64
* :long_long :ulong_long :float :double :bool
* :void :pointer :string

For composite and union types, you can declare these within the function signature, using a syntax similar to Crystal's type syntax.

E.g.

```ruby
require 'crystalruby'

crystallize
def complex_argument_types(a:  Int64 | Float64 | Nil, b: String | Array(Bool))
  puts "Got #{a} and #{b}"
end


crystallize
def complex_return_type(returns: Int32 | String | Hash(String, Array(NamedTuple(hello: Int32)) | Time))
  return {
    "hello" => [
      {
        hello: 1,
      },
    ],
    "world" => Time.utc
  }
end

complex_argument_types(10, "Hello")
puts complex_return_type()
```


Type signatures validations are applied to both arguments and return types.

```ruby
[1] pry(main)> complex_argument_types(nil, "test")
Got  and test
=> nil

[2] pry(main)> complex_argument_types(88, [true, false, true])
Got 88 and [true, false, true]
=> nil

[3] pry(main)> complex_argument_types(88, [true, false, 88])
ArgumentError: Expected Bool but was Int at line 1, column 15
from crystalruby.rb:303:in `block in compile!'
```

### Reference Types
By default, all types are passed by value, as there is an implicit copy each time a value is passed
between Crystal and Ruby.
However, if you name a type you can instantiate it (in either Ruby or Crystal) and pass by reference instead.
This allows for more efficient passing of large data structures between the two languages.

`crystalruby` implements a shared reference counter, so that the same object can be safely used across both languages
without fear of them being garbage collected prematurely.

E.g.

```ruby

IntArrOrBoolArr = CRType{ Array(Bool) | Array(Int32) }

crystallize
def method_with_named_types(a: IntArrOrBoolArr, returns: IntArrOrBoolArr)
  return a
end

# In this case the array is converted to a Crystal Array (so a copy is made)
method_with_named_types([1,2,3])

# In this case, no conversion is necessary and the array is passed by reference
int_array = IntArrOrBoolArr.new([1,2,3]) # Or  IntArrOrBoolArr[1,2,3]
method_with_named_types(int_array)
```

We can demonstrate the significant performance advantage of passing by reference with the following benchmark.

```ruby
require 'benchmark'
require 'crystalruby'

IntArray = CRType{ Array(Int32) }

crystallize
def array_doubler(a: IntArray)
  a.map! { |x| x * 2 }
end

def array_doubler_rb(a)
  a.map! { |x| x * 2 }
end

big_array     = Array.new(1_000_000) { rand(100) }
big_int_array = IntArray.new(big_array)

Benchmark.bm do |x|
  x.report("Crystal Pass by value")     { array_doubler(big_array) }
  x.report("Crystal Pass by reference") { array_doubler(big_int_array) }
  x.report("Ruby    Pass by reference") { array_doubler_rb(big_array) }
end
```

### Shared Instances
You can even define instance methods on an instance of a reference type, to make addressable objects that are shared between Ruby and Crystal.

```ruby
require 'crystalruby'

class Person < CRType{ NamedTuple(name: String, age: Int32) }
  def greet_rb
    "Hello from Ruby. My name is #{self.name.value}"
  end

  crystallize :string
  def greet_cr
    "Hello from Crystal, My name is #{self.name.value}"
  end
end

person = Person.new(name: "Bob", age: 30)
puts person.greet_rb
person.name = "Alice"
puts person.greet_cr
```

## Calling Ruby from Crystal
You can also call Ruby methods from Crystal. To do this, you must annotate the exposed Ruby method with
`expose_to_crystal` so that crystalruby can perform the appropriate type conversions.

```ruby
require 'crystalruby'

module Adder
  expose_to_crystal :int32
  def add_rb(a: Int32, b: Int32)
    a + b
  end

  crystallize :int32
  def add_crystal(a: Int32, b: Int32)
    return add_rb(a, b)
  end
end

puts Adder.add_crystal(1, 2)
```

### Kemal
Here's a more realistic example of where you could call Ruby from Crystal.
We run the Kemal web server in Crystal, but allow certain routes to respond from Ruby, allowing
us to combine the raw speed of Kemal, with the flexibility of Ruby.

```ruby
require 'crystalruby'

shard :kemal, github: 'kemalcr/kemal'

crystallize async: true
def start_server
  Kemal.run(3000, [""])
end

expose_to_crystal
def return_ruby_response(returns: String)
  "Hello World! #{Random.rand(0..100)}"
end

crystal do
  get "/kemal_rb" do
    return_ruby_response
  end

  get "/kemal_cr" do
    "Hello World! #{Random.rand(0..100)}"
  end
end

start_server
```

We could compare the above to an equivalent pure Ruby implementation using Sinatra.

```ruby
require 'sinatra'

get '/sinatra_rb' do
  'Hello world!'
end
```

and benchmark the two.

```bash

$ wrk -d 2 http://localhost:4567/kemal_rb
... Requests/sec:  23352.00

$ wrk -d 2 http://localhost:4567/kemal_cr
... Requests/sec:  35730.03

$ wrk -d 2 http://localhost:4567/sinatra_rb
... Requests/sec:   5300.67

```

Note the hybrid Crystal/Ruby implementation is significantly faster (4x) than the pure Ruby implementation
and almost 66% as fast as the pure Crystal implementation.


## Yielding
crystalruby supports Crystal methods yielding to Ruby, and Ruby blocks yielding to Crystal.
To support this, you must add a block argument to your method signature, and use the `yield` keyword to call the block.

See notes on how to define a Proc type in Crystal [here](https://crystal-lang.org/reference/1.14/syntax_and_semantics/literals/proc.html#the-proc-type)

```ruby
require 'crystalruby'

crystallize
def yielder_cr(a: Int32, b: Int32, yield: Proc(Int32, Nil))
  yield a + b
end

expose_to_crystal
def yielder_rb(a: Int32, b: Int32, yield: Proc(Int32, Nil))
  yield a + b
end

crystallize
def invoke_yielder_rb(a: Int32, b: Int32)
  yielder_rb(a, b) do |sum|
    puts sum
  end
end

yielder_cr(10, 20){|sum| puts sum } #=> 30
invoke_yielder_rb(50, 50)           #=> 100
```

## Exceptions

Exceptions thrown in Crystal code can be caught in Ruby.

## Using shards
You can specify shard dependencies inline in your Ruby source, using the `shard` method.

```ruby

shard :redis, github: 'stefanwille/crystal-redis'

```

Any options you pass to the `shard` method will be added to the corresponding shard dependency in the autogenerated `shard.yml` file.
crystalruby will automatically
* run `shards install` for you
* require the specified shard
upon compilation.

If your shard file gets out of sync with your Ruby file, you can run `crystalruby clean` to reset your workspace to a clean state.

## Wrapping Crystal code in Ruby

Sometimes you may want to wrap a Crystal method in Ruby, so that you can use Ruby before the Crystal code to prepare arguments, or after the Crystal code, to apply transformations to the result. A real-life example of this might be an ActionController method, where you might want to use Ruby to parse the request, perform auth etc., and then use Crystal to perform some heavy computation, before returning the result from Ruby.
To do this, you simply pass a block to the `crystallize` method, which will serve as the Ruby entry point to the function. From within this block, you can invoke `super` to call the Crystal method, and then apply any Ruby transformations to the result.

```ruby
crystallize :int32 do |a, b|
  # In this example, we perform automated conversion to integers inside Ruby.
  # Then add 1 to the result of the Crystal method.
  result = super(a.to_i, b.to_i)
  result + 1
end
def convert_to_i_and_add_and_succ(a: :int32, b: :int32)
  a + b
end

puts convert_to_i_and_add_and_succ("1", "2")
```

## Inline Chunks

`crystalruby` also allows you to write top-level Crystal code outside of method definitions. This can be useful for e.g. performing setup operations or initializations.

Follow these steps for a toy example of how we can use crystallized ruby and inline chunks to expose the [crystal-redis](https://github.com/stefanwille/crystal-redis) library to Ruby.

1. Start our toy project

```bash
mkdir crystalredis
cd crystalredis
bundle init
```

2. Add dependencies to our Gemfile and run `bundle install`

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gem 'crystalruby'

# Let's see if performance is comparable to that of the redis gem.
gem 'benchmark-ips'
gem 'redis'
```

3. Write our Redis client

```ruby
# Filename: crystalredis.rb
require 'crystalruby'

module CrystalRedis

  shard :redis, github: 'stefanwille/crystal-redis'

  crystal do
    CLIENT = Redis.new
    def self.client
      CLIENT
    end
  end

  crystallize
  def set(key: String, value: String)
    client.set(key, value)
  end

  crystallize :string
  def get(key: String)
    client.get(key).to_s
  end
end
```

3. Compile and benchmark our new module in Ruby

```ruby
# Filename: benchmark.rb
# Let's compare the performance of our CrystalRedis module to the Ruby Redis gem
require 'crystalruby'
require 'redis'
require 'benchmark/ips'
require 'debug'

# For a high IPS single-threaded program, we can set the single_thread_mode to true for faster
# FFI interop
CrystalRuby.configure do |config|
  config.single_thread_mode = true
end

module CrystalRedis

  shard :redis, github: 'stefanwille/crystal-redis'

  crystal do
    CLIENT = Redis.new
    def self.client
      CLIENT
    end
  end

  crystallize
  def set(key: String, value: String)
    client.set(key, value)
  end

  crystallize :string
  def get(key: String)
    client.get(key).to_s
  end
end

Benchmark.ips do |x|
  rbredis = Redis.new

  x.report(:crredis) do
    CrystalRedis.set("hello", "world")
    CrystalRedis.get("hello")
  end

  x.report(:rbredis) do
    rbredis.set("hello", "world")
    rbredis.get("hello")
  end
end

```

4. Run the benchmark

```bash
$ bundle exec ruby benchmark.rb
```

## Release Builds

You can control whether crystalruby builds in debug or release mode by setting following config option

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

## Concurrency

While Ruby programs allow multi-threading, Crystal (if not using experimental multi-thread support) uses only a single thread and utilises Fiber based cooperative-multitasking to allow for concurrent execution. This means that by default, Crystal libraries can not safely be invoked in parallel across multiple Ruby threads.

To safely utilise `crystalruby` in a multithreaded environment, `crystalruby` implements a Reactor, which multiplexes all Ruby calls to Crystal across a single thread.

By default `crystalruby` methods are blocking/synchronous, this means that for blocking operations, a single crystalruby call can block the entire reactor across _all_ threads.

To allow you to benefit from Crystal's fiber based concurrency, you can use the `async: true` option on crystallized ruby methods. This allows several Ruby threads to invoke Crystal code simultaneously.

E.g.

```ruby
module Sleeper
  crystallize
  def sleep_sync
    sleep 2.seconds
  end

  crystallize async: true
  def sleep_async
    sleep 2.seconds
  end
end
```

```ruby
5.times.map{ Thread.new{ Sleeper.sleep_sync } }.each(&:join) # Will take 10 seconds
5.times.map{ Thread.new{ Sleeper.sleep_async } }.each(&:join) # Will take 2 seconds (the sleeps are processed concurrently)
```

### Reactor performance

There is a small amount of synchronization overhead to multiplexing calls across a single thread. Ad-hoc testing on a fast machine amounts this to be within the order of 10 microseconds per call.
For most use-cases this overhead is negligible, especially if the bulk of your CPU heavy task occurs exclusively in Crystal code. However, if you are invoking very fast Crystal code from Ruby in a tight loop (e.g. a simple 1 + 2)
then the overhead of the reactor can become significant.

In this case you can use the `crystalruby` in a single-threaded mode to avoid the reactor overhead and greatly increase performance, with the caveat that _all_ calls to Crystal must occur from a single thread. If your Ruby program is already single-threaded this is not a problem.

```ruby
CrystalRuby.configure do |config|
  config.single_thread_mode = true
end
```

## Live Reloading

`crystalruby` supports live reloading of Crystal code. It will intelligently
recompile Crystal code only when it detects changes to the embedded function or block bodies. This allows you to iterate quickly on your Crystal code without having to restart your Ruby process in live-reloading environments like Rails.

## Multi-library support

Large Crystal projects are known to have long compile times. To mitigate this, `crystalruby` supports splitting your Crystal code into multiple libraries. This allows you to only recompile any libraries that have changed, rather than all crystal code within the project.
To indicate which library a piece of embedded Crystal code belongs to, you can use the `lib` option in the `crystallize` and `crystal` methods.
If the `lib` option is not provided, the code will be compiled into the default library (simply named `crystalruby`).

```ruby
module Foo
  crystallize lib: "foo"
  def bar
    puts "Hello from Foo"
  end

  crystal lib: "foo" do
    REDIS = Redis.new
  end
end
```

Naturally, Crystal methods must reside in the same library to natively interact.
Cross library interaction can be facilitated via Ruby code.

## Troubleshooting

In cases where compiled assets are in left an invalid state, it can be useful to clear out generated assets and rebuild from scratch.

To do this execute:

```bash
bundle exec crystalruby clean
```

## Design Goals

`crystalruby`'s primary purpose is to provide ergonomic access to Crystal from Ruby, over FFI.
For simple usage, advanced knowledge of Crystal should not be required.

However, the abstraction it provides should remain simple, transparent, and easy to hack on and it should not preclude users from supplementing its capabilities with a more direct integration using ffi primtives.

It should support escape hatches to allow it to coexist with code that performs a more direct [FFI](https://github.com/ffi/ffi) integration to implement advanced functionality not supported by `crystalruby`.

The library is currently in its infancy.

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

`crystalruby` supports some basic configuration options, which can be specified inside a crystalruby.yaml file in the root of your project.
You can run `crystalruby init` to generate a configuration file with sane defaults.

```bash
$ crystalruby init
```

```yaml
crystal_src_dir: "./crystalruby"
crystal_codegen_dir: "generated"
crystal_main_file: "main.cr"
crystal_lib_name: "crlib"
crystal_codegen_dir: "generated"
debug: true
```

Alternatively, these can be set programmatically, e.g:

```ruby
CrystalRuby.configure do |config|
  config.crystal_src_dir = "./crystalruby"
  config.crystal_codegen_dir = "generated"
  config.crystal_missing_ignore = false
  config.debug = true
  config.verbose = false
  config.colorize_log_output = false
  config.log_level = :info
end
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
