# encoding: UTF-8

module Vines
  module Services
    module Controller
      class TransfersController < BaseController
        register :file_transfer

        def process
          forbidden! unless current_user.manage_files?
          return unless node.to == stream.jid
          name, size = node.si.file['name'], node.si.file['size'].to_i
          log.debug("Receiving file: #{name}")

          path = File.expand_path(name, uploads)
          return unless path.start_with?(uploads)

          log.debug("Saving file to #{path}")
          File.delete(path) if File.exist?(path)

          save_file_doc(name, size)

          transfer = Blather::FileTransfer.new(stream, node)
          transfer.allow_s5b = false
          transfer.accept(FileUploader, path, size, storage)
        end

        private

        def save_file_doc(name, size)
          file = Upload.find_by_name(name) || Upload.new
          file.name = name
          file.size = size
          file.save
        end

        module FileUploader
          include Blather::FileTransfer::SimpleFileReceiver

          def initialize(path, size, storage)
            super(path, size)
            @storage = storage
          end

          def unbind
            super
            return unless File.exist?(@path)
            Fiber.new do
              @storage.store_file(@path) do
                File.delete(@path) rescue nil
              end
            end.resume
          end
        end
      end
    end
  end
end
