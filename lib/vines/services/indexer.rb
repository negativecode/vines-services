# encoding: UTF-8

module Vines
  module Services
    # Save system ohai documents in a sqlite database for fast searching. This
    # index powers the live search feature of the service builder user interface.
    # The indexing happens on a separate thread for two reasons:
    #   - writes to sqlite block the EventMachine thread
    #   - writes to sqlite lock the database file, so we need one writer process
    class Indexer
      include Vines::Log

      @@indexers = {}

      # Return the Indexer instance managing this file, creating a new Indexer
      # instance if needed.
      def self.[](file)
        file = File.expand_path(file)
        @@indexers[file] ||= self.new(file)
      end

      # There must be only one Indexer managing a sqlite file at one time.
      # Use Indexer[file] to create or retrieve the Indexer for a given file
      # rather than calling the constructor directly.
      def initialize(file)
        @db = database(file)
        @tasks = PriorityQueue.new do |a, b|
          a[:priority] <=> b[:priority]
        end
        process_tasks
      end

      # Queue the document for indexing at some point in the future. Because
      # adding documents to the index is less time-sensitive than querying the
      # index, these tasks may be delayed by query tasks.
      def <<(doc)
        @tasks.push({
          priority: Time.now.to_f,
          type: :index,
          doc: doc
        })
      end

      # Run the SQL query with optional replacement parameters (e.g. ?) and yield
      # the results array to the callback block. Queries are prioritized ahead of
      # document indexing tasks so they will return quickly even when many documents
      # are waiting to be indexed.
      def find(query, *args, &callback)
        @tasks.push({
          priority: 0,
          type: :query,
          query: query,
          args: args.flatten,
          callback: callback
        })
      end

      private

      # Run the index processing loop, indexing one document at a time so that
      # writes to sqlite are single threaded. Each task is performed in the
      # EM thread pool so the reactor thread isn't blocked.
      def process_tasks
        @tasks.pop do |task|
          callback = task[:callback]
          op = proc do
            case task[:type]
            when :index then index(task[:doc])
            when :query then query(task[:query], task[:args])
            end
          end
          cb = proc do |results|
            callback.call(results) if callback rescue nil
            process_tasks
          end
          EM.defer(op, cb)
        end
      end

      def query(sql, args)
        @db.prepare(sql) do |stmt|
          stmt.execute!(*args)
        end
      rescue Exception => e
        log.error("Error searching index: #{e.message}")
        []
      end

      def index(doc)
        @db.transaction do
          flat = flatten(doc)
          system_id = find_or_create_system(doc)
          attrs = find_attributes(system_id)
          delete_attributes(flat, attrs, system_id)
          update_attributes(flat, attrs, system_id)
          insert_attributes(flat, attrs, system_id)
        end
      rescue Exception => e
        log.error("Error indexing document: #{e.message}")
      end

      def find_or_create_system(doc)
        @db.prepare("select id from systems where name=?") do |stmt|
          row = stmt.execute!(name(doc)).first
          row ? row[0] : insert_system(doc)
        end
      end

      def insert_system(doc)
        os = doc['kernel']['os'].downcase.sub('gnu/', '')
        @db.prepare("insert into systems (name, os) values (?, ?)") do |stmt|
          stmt.execute!(name(doc), os)
          @db.last_insert_row_id
        end
      end

      def find_attributes(system_id)
        sql = "select key, value from attributes where system_id=?"
        @db.prepare(sql) do |stmt|
          {}.tap do |attrs|
            stmt.execute!(system_id) do |row|
              attrs[row[0]] = row[1]
            end
          end
        end
      end

      def delete_attributes(flat, attrs, system_id)
        deletes = attrs.keys.select {|k| !flat.key?(k) }
        return if deletes.empty?
        deletes.each_slice(999) do |slice|
          params = slice.map{'?'}.join(',')
          sql = "delete from attributes where system_id=? and key in (%s)" % params
          @db.prepare(sql) do |stmt|
            stmt.execute!(system_id, *slice)
          end
        end
      end

      def update_attributes(flat, attrs, system_id)
        updates = flat.select {|k, v| attrs.key?(k) && attrs[k].to_s != v.to_s }
        return if updates.empty?
        sql = "update attributes set value=? where system_id=? and key=?"
        @db.prepare(sql) do |stmt|
          updates.each do |k, v|
            stmt.execute!(v, system_id, k)
          end
        end
      end

      def insert_attributes(flat, attrs, system_id)
        inserts = flat.select {|k, v| !attrs.key?(k) }
        return if inserts.empty?
        sql = "insert into attributes (system_id, key, value) values (?, ?, ?)"
        @db.prepare(sql) do |stmt|
          inserts.each do |k, v|
            stmt.execute!(system_id, k, v)
          end
        end
      end

      def database(file)
        SQLite3::Database.new(file).tap do |db|
          db.synchronous = 'off'
          db.execute("create table if not exists systems(id integer primary key, name text not null, os text)")
          db.execute("create index if not exists systems_ix01 on systems (name)")
          db.execute("create table if not exists attributes (system_id integer not null, key text not null, value text)")
          db.execute("create index if not exists attributes_ix01 on attributes (system_id, key)")
          db.execute("create index if not exists attributes_ix02 on attributes (key, value)")
        end
      end

      def name(doc)
        doc['fqdn'].downcase
      end

      # Recursively expand a nested Hash into a flat key namespace. For example:
      # flatten({one: {two: {three: 3}}}) #=> {"one.two.three"=>3}
      def flatten(doc, output={}, stack=[])
        case doc
        when Hash
          doc.each do |k,v|
            stack.push(k)
            flatten(v, output, stack)
            stack.pop
          end
        else
          val = doc.is_a?(Array) ? doc.join(',') : doc
          output[stack.join('.')] = val
        end
        output
      end
    end
  end
end
