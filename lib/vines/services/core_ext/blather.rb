# encoding: UTF-8

module Blather
  class FileTransfer
    class Ibb
      # Override the accept method to write directly to the file system rather
      # than using EM#attach. This is a workaround for this bug:
      # https://github.com/eventmachine/eventmachine/issues/200
      def accept(handler, *params)
        klass = Class.new.send(:include, handler)
        handler = klass.new(*params)
        handler.post_init

        @stream.register_handler :ibb_data, :from => @iq.from, :sid => @iq.sid do |iq|
          if iq.data['seq'] == @seq.to_s
            begin
              handler.receive_data(Base64.decode64(iq.data.content))
              @stream.write iq.reply
              @seq += 1
              @seq = 0 if @seq > 65535
            rescue Exception => e
              handler.unbind
              @stream.write StanzaError.new(iq, 'not-acceptable', :cancel).to_node
            end
          else
            handler.unbind
            @stream.write StanzaError.new(iq, 'unexpected-request', :wait).to_node
          end
          true
        end

        @stream.register_handler :ibb_close, :from => @iq.from, :sid => @iq.sid do |iq|
          @stream.write iq.reply
          @stream.clear_handlers :ibb_data, :from => @iq.from, :sid => @iq.sid
          @stream.clear_handlers :ibb_close, :from => @iq.from, :sid => @iq.sid
          handler.unbind
          true
        end

        @stream.clear_handlers :ibb_open, :from => @iq.from
        @stream.clear_handlers :ibb_open, :from => @iq.from, :sid => @iq.sid
        @stream.write @iq.reply
      end
    end
  end
end
