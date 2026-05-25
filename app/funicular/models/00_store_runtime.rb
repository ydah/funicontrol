module Funicular
  module Store
    @registered_scopes = []

    def self.mount_indexed_db
      return if @indexed_db_mounted

      script = JS.document.createElement("script")
      script[:textContent] = <<~JAVASCRIPT
        (function() {
          if (window.FunicontrolStore) return;

          const DB_NAME = "funicontrol";
          const STORE_NAME = "entries";
          let dbPromise = null;

          function openDb() {
            if (dbPromise) return dbPromise;
            dbPromise = new Promise((resolve, reject) => {
              const request = indexedDB.open(DB_NAME, 1);
              request.onupgradeneeded = () => {
                const db = request.result;
                if (!db.objectStoreNames.contains(STORE_NAME)) {
                  db.createObjectStore(STORE_NAME);
                }
              };
              request.onsuccess = () => resolve(request.result);
              request.onerror = () => reject(request.error);
            });
            return dbPromise;
          }

          function transaction(mode) {
            return openDb().then((db) => db.transaction(STORE_NAME, mode).objectStore(STORE_NAME));
          }

          window.FunicontrolStore = {
            get(key) {
              return transaction("readonly").then((store) => new Promise((resolve, reject) => {
                const request = store.get(key);
                request.onsuccess = () => resolve(request.result || null);
                request.onerror = () => reject(request.error);
              }));
            },
            put(key, value) {
              return transaction("readwrite").then((store) => new Promise((resolve, reject) => {
                const request = store.put(value, key);
                request.onsuccess = () => resolve(true);
                request.onerror = () => reject(request.error);
              }));
            },
            remove(key) {
              return transaction("readwrite").then((store) => new Promise((resolve, reject) => {
                const request = store.delete(key);
                request.onsuccess = () => resolve(true);
                request.onerror = () => reject(request.error);
              }));
            }
          };
        })();
      JAVASCRIPT
      JS.document.body.appendChild(script)
      JS.document.body.removeChild(script)
      @indexed_db_mounted = true
    end

    def self.register_scope(scope)
      @registered_scopes << scope unless @registered_scopes.include?(scope)
    end

    def self.dispatch(event)
      @registered_scopes.each do |scope|
        scope.clear_for_event(event)
      end
    end

    class BaseStore
      class << self
        def database(name)
          @database_name = name
        end

        def database_name
          @database_name || "funicontrol"
        end

        def scope(*names)
          @scope_names = names
        end

        def scope_names
          @scope_names || []
        end

        def expires_in(seconds)
          @expires_in_seconds = seconds
        end

        def expires_in_seconds
          @expires_in_seconds
        end

        def cleared_on(event, &block)
          @clear_event = event
          @clear_handler = block
        end

        def clear_event
          @clear_event
        end

        def clear_handler
          @clear_handler
        end

        def where(kwargs = {})
          @scopes ||= {}
          key = storage_key(kwargs)
          @scopes[key] ||= scope_class.new(self, kwargs, key)
          Funicular::Store.register_scope(@scopes[key])
          @scopes[key]
        end

        def storage_key(kwargs)
          scope_part = scope_names.map { |name| "#{name}=#{kwargs[name] || kwargs[name.to_s]}" }.join(":")
          "#{database_name}:#{self}:#{scope_part}"
        end
      end
    end

    class Singleton < BaseStore
      def self.scope_class
        SingletonScope
      end
    end

    class Collection < BaseStore
      class << self
        def limit(value)
          @limit_count = value
        end

        def limit_count
          @limit_count || 100
        end

        def order(value)
          @order = value
        end

        def order_name
          @order || :append
        end

        def key(proc_object = nil)
          @key_proc = proc_object if proc_object
          @key_proc
        end

        def scope_class
          CollectionScope
        end
      end
    end

    class ScopeBase
      def initialize(store_class, kwargs, storage_key)
        @store_class = store_class
        @kwargs = kwargs
        @storage_key = storage_key
      end

      def clear_for_event(event)
        return unless @store_class.clear_event == event

        handler = @store_class.clear_handler
        if handler
          instance_exec(nil, &handler)
        else
          clear
        end
      end

      private

      def limit_items(items, limit)
        limited = []
        max_count = limit.to_i

        (items || []).each do |item|
          break if limited.length >= max_count

          limited << item
        end

        limited
      end

      def local_storage
        JS.global[:localStorage]
      end

      def indexed_db_get
        Funicular::Store.mount_indexed_db
        result_key = "_funicontrolStoreResult_#{Time.now.to_i}_#{rand(100_000)}"
        key_json = JSON.generate(@storage_key)
        result_json = JSON.generate(result_key)
        script = JS.document.createElement("script")
        script[:textContent] = <<~JAVASCRIPT
          window.FunicontrolStore.get(#{key_json}).then(function(value) {
            window[#{result_json}] = JSON.stringify({ ok: true, value: value });
          }).catch(function(error) {
            window[#{result_json}] = JSON.stringify({ ok: false, error: String(error) });
          });
        JAVASCRIPT
        JS.document.body.appendChild(script)
        JS.document.body.removeChild(script)

        counter = 0
        raw_result = nil
        while counter < 100
          raw_result = JS.global[result_key.to_sym]
          break if raw_result && !raw_result.to_s.empty?
          counter += 1
          sleep 0.02
        end

        JS.global[result_key.to_sym] = nil
        return nil unless raw_result

        result = JSON.parse(raw_result.to_s)
        result["ok"] ? result["value"] : nil
      rescue
        nil
      end

      def indexed_db_put(value)
        Funicular::Store.mount_indexed_db
        key_json = JSON.generate(@storage_key)
        value_json = JSON.generate(value)
        script = JS.document.createElement("script")
        script[:textContent] = "window.FunicontrolStore.put(#{key_json}, #{value_json});"
        JS.document.body.appendChild(script)
        JS.document.body.removeChild(script)
      rescue
        nil
      end

      def indexed_db_delete
        Funicular::Store.mount_indexed_db
        key_json = JSON.generate(@storage_key)
        script = JS.document.createElement("script")
        script[:textContent] = "window.FunicontrolStore.remove(#{key_json});"
        JS.document.body.appendChild(script)
        JS.document.body.removeChild(script)
      rescue
        nil
      end

      def read_entry
        raw = local_storage&.getItem(@storage_key)
        unless raw
          entry_from_indexed_db = indexed_db_get
          if entry_from_indexed_db
            raw = JSON.generate(entry_from_indexed_db)
            local_storage&.setItem(@storage_key, raw)
          end
        end
        return nil unless raw

        entry = JSON.parse(raw.to_s)
        expires_at = entry["expires_at"]
        if expires_at && Time.now.to_i > expires_at.to_i
          clear
          return nil
        end
        entry
      rescue
        clear
        nil
      end

      def write_entry(value)
        expires_at = nil
        ttl = @store_class.expires_in_seconds
        expires_at = Time.now.to_i + ttl if ttl
        entry = { value: value, expires_at: expires_at }
        local_storage&.setItem(@storage_key, JSON.generate(entry))
        indexed_db_put(entry)
      end

      def delete_entry
        local_storage&.removeItem(@storage_key)
        indexed_db_delete
      end
    end

    class SingletonScope < ScopeBase
      def value
        entry = read_entry
        entry ? entry["value"] : nil
      end

      def value=(next_value)
        if next_value.nil? || next_value == ""
          delete
        else
          write_entry(next_value)
        end
      end

      def delete
        delete_entry
      end

      def clear
        delete
      end

      def present?
        !value.nil?
      end
    end

    class CollectionScope < ScopeBase
      def all
        entry = read_entry
        entry ? (entry["value"] || []) : []
      end

      def replace(items)
        write_entry(items)
      end

      def append(item)
        items = all
        if @store_class.order_name == :prepend
          items = [item] + items
        else
          items << item
        end
        replace(limit_items(items, @store_class.limit_count))
      end

      def remove(id)
        key_proc = @store_class.key
        return unless key_proc

        replace(all.reject { |item| key_proc.call(item).to_s == id.to_s })
      end

      def clear
        delete_entry
      end
    end
  end
end
