# encoding: utf-8

module AMQP
  class Header
    def initialize(mq, header_obj)
      @mq = mq
      @header = header_obj
      @acked = false
    end

    # Acknowledges the receipt of this message with the server.
    def ack
      # Double-ACKing will cause RabbitMQ 2.4.1 to close channel on us.
      # Sanity check here to make this method fool-proof
      return if @acked

      @acked = true

      @mq.callback {
        @mq.send Protocol::Basic::Ack.new(:delivery_tag => properties[:delivery_tag])
      }
    end

    # Reject this message.
    # * :requeue => true | false (default false)
    def reject(opts = {})
      @mq.callback {
        @mq.send Protocol::Basic::Reject.new(opts.merge(:delivery_tag => properties[:delivery_tag]))
      }
    end

    def method_missing(meth, *args, &blk)
      @header.send meth, *args, &blk
    end

    def inspect
      @header.inspect
    end
  end
end
