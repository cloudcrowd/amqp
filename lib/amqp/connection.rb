# encoding: utf-8

require "amqp/ext/em"
require "amqp/ext/blankslate"

require "amqp/buffer"
require "amqp/spec"
require "amqp/protocol"
require "amqp/frame"
require "amqp/client"

module AMQP
  class << self
    @logging = false
    attr_accessor :logging
    attr_reader :conn, :closing
    alias :closing? :closing
    alias :connection :conn
  end

  def self.connect *args
    Client.connect *args
  end

  def self.settings
    @settings ||= {
      # server address
      :host => '127.0.0.1',
      :port => PORT,

      # login details
      :user => 'guest',
      :pass => 'guest',
      :vhost => '/',

      # connection timeout
      :timeout => nil,

      # logging
      :logging => false,

      # ssl
      :ssl => false
    }
  end

  # Must be called to startup the connection to the AMQP server.
  #
  # The method takes several arguments and an optional block.
  #
  # This takes any option that is also accepted by EventMachine::connect.
  # Additionally, there are several AMQP-specific options.
  #
  # * :user => String (default 'guest')
  # The username as defined by the AMQP server.
  # * :pass => String (default 'guest')
  # The password for the associated :user as defined by the AMQP server.
  # * :vhost => String (default '/')
  # The virtual host as defined by the AMQP server.
  # * :timeout => Numeric (default nil)
  # Measured in seconds.
  # * :logging => true | false (default false)
  # Toggle the extremely verbose logging of all protocol communications
  # between the client and the server. Extremely useful for debugging.
  #
  #  AMQP.start do
  #    # default is to connect to localhost:5672
  #
  #    # define queues, exchanges and bindings here.
  #    # also define all subscriptions and/or publishers
  #    # here.
  #
  #    # this block never exits unless EM.stop_event_loop
  #    # is called.
  #  end
  #
  # Most code will use the MQ api. Any calls to AMQP::Channel.direct / AMQP::Channel.fanout /
  # AMQP::Channel.topic / AMQP::Channel.queue will implicitly call #start. In those cases,
  # it is sufficient to put your code inside of an EventMachine.run
  # block. See the code examples in AMQP for details.
  #
  def self.start *args, &blk
    EM.run {
      @conn ||= connect *args
      @conn.callback(&blk) if blk
      @conn
    }
  end

  class << self
    alias :run :start
  end

  def self.stop
    if @conn and not @closing
      @closing = true
      EM.next_tick do
        @conn.close {
          @conn = nil
          @closing = false
          # yield should happens last, just in case that this thread lose execution rights to any
          # conditiona_variable.signal that might be present in the given block
          yield if block_given?
        }
      end
    end
  end

  def self.fork workers
    EM.fork(workers) do
      # clean up globals in the fork
      Thread.current[:mq] = nil
      AMQP.instance_variable_set('@conn', nil)

      yield
    end
  end
end
