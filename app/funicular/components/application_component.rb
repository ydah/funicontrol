class ApplicationComponent < Funicular::Component
  STATUS_LABELS = {
    "idle" => "Idle",
    "running" => "Running",
    "slow" => "Slow",
    "stopped" => "Stopped",
    "emergency" => "Emergency",
    "inspection_required" => "Inspection required",
    "maintenance" => "Maintenance"
  }

  SEVERITY_LABELS = {
    "low" => "Low",
    "medium" => "Medium",
    "high" => "High",
    "critical" => "Critical"
  }

  def render_shell(title, &block)
    div(class: "app-shell") do
      header(class: "topbar") do
        div do
          h1 { "Funicontrol" }
          span(class: "subtitle") { "Mt. Ruby cable control" }
        end
        div(class: "topbar-pills") do
          span(class: "system-pill") { network_label }
          span(class: "system-pill") { "score mode" } if score_mode?
          span(class: "system-pill") { title }
        end
      end
      div(class: "workspace") do
        component(NavigationComponent)
        section(class: "screen") do
          h2(class: "screen-title") { title }
          block&.call
        end
      end
    end
  end

  def value(object, key)
    return nil unless object

    if object.is_a?(Hash)
      return hash_value(object, key)
    end

    bracket_value = indexed_value(object, key)
    return bracket_value unless bracket_value.nil?
    return object.send(key) if object.respond_to?(key)

    nil
  end

  def object_id(object)
    integer_value(value(object, :id))
  end

  def status_label(status)
    STATUS_LABELS[status.to_s] || status.to_s
  end

  def severity_label(severity)
    SEVERITY_LABELS[severity.to_s] || severity.to_s
  end

  def format_time(timestamp)
    text = timestamp.to_s
    return "now" if text.empty?
    return text[11, 8] if text.length >= 19

    text
  end

  def replace_by_id(items, item)
    item_id = object_id(item)
    items.map do |existing|
      (object_id(existing) == item_id) ? item : existing
    end
  end

  def prepend_unique(items, item, limit = 100)
    item_id = object_id(item)
    next_items = [item] + items.reject { |existing| object_id(existing) == item_id }
    limit_collection(next_items, limit)
  end

  def merge_unique_by_id(items, incoming, limit = 100)
    seen = {}
    merged = []

    (incoming || []).each do |item|
      item_id = object_id(item)
      next if item_id <= 0 || seen[item_id]

      seen[item_id] = true
      merged << item
    end

    (items || []).each do |item|
      item_id = object_id(item)
      next if item_id <= 0 || seen[item_id]

      seen[item_id] = true
      merged << item
    end

    limit_collection(merged, limit)
  end

  def limit_collection(items, limit)
    limited = []
    max_count = limit.to_i

    (items || []).each do |item|
      break if limited.length >= max_count

      limited << item
    end

    limited
  end

  def normalize_errors(errors)
    normalized = {}
    return normalized unless errors

    errors.each do |key, messages|
      normalized[key.to_sym] = messages.is_a?(Array) ? messages.join(", ") : messages.to_s
    end
    normalized
  end

  def percent_position(item)
    number = numeric_value(value(item, :position))
    number = 0.0 if number < 0.0
    number = 1.0 if number > 1.0
    (number * 100).round(1)
  end

  def cable_url
    protocol = (JS.global.location.protocol.to_s == "https:") ? "wss://" : "ws://"
    "#{protocol}#{JS.global.location.host}/cable"
  end

  def upload_form(method, url, fields, file_field: nil, file_global_key: nil, &block)
    result_key = "_funicontrolUploadResult_#{Time.now.to_i}_#{rand(100_000)}"
    event_name = "#{result_key}_event"
    safe_fields = {}
    fields.each do |key, field_value|
      next if key.to_s == "photo"
      next if key.to_s == "photo_name"

      safe_fields[key.to_s] = field_value
    end

    script = JS.document.createElement("script")
    script[:textContent] = <<~JAVASCRIPT
      window.addEventListener(#{JSON.generate(event_name)}, function handler(event) {
        window.removeEventListener(#{JSON.generate(event_name)}, handler);
        window[#{JSON.generate(result_key)}] = JSON.stringify(event.detail);
      });
      window.FunicontrolUpload.submitWithEvent(
        #{JSON.generate(method.to_s.upcase)},
        #{JSON.generate(url)},
        #{JSON.generate(safe_fields)},
        #{JSON.generate(file_field)},
        #{JSON.generate(file_global_key)},
        #{JSON.generate(event_name)}
      );
    JAVASCRIPT
    JS.document.body.appendChild(script)
    JS.document.body.removeChild(script)

    counter = 0
    raw_result = nil
    while counter < 200
      raw_result = JS.global[result_key.to_sym]
      break if raw_result && !raw_result.to_s.empty?
      counter += 1
      sleep 0.05
    end
    JS.global[result_key.to_sym] = nil

    result = raw_result ? JSON.parse(raw_result.to_s) : {"ok" => false, "data" => {"errors" => {"base" => ["Upload timed out"]}}}
    block&.call(result)
  end

  def serialize_collection(items)
    (items || []).map do |item|
      {
        id: object_id(item),
        name: value(item, :name),
        position: numeric_value(value(item, :position)),
        direction: value(item, :direction),
        speed: numeric_value(value(item, :speed)),
        status: value(item, :status)
      }
    end
  end

  def network_label
    offline? ? "offline" : "online"
  end

  def offline?
    navigator = JS.global[:navigator]
    return false unless navigator

    navigator[:onLine] == false
  end

  def score_mode?
    return true if query_param("mode").to_s == "score"

    prefs = OperatorPrefsStore.where.value || {}
    value(prefs, :score_mode).to_s == "true"
  end

  def query_param(name)
    search = JS.global.location.search.to_s
    return nil if search.empty?

    search.sub(/^\?/, "").split("&").each do |part|
      key, value = part.split("=", 2)
      return JS.global.decodeURIComponent(value.to_s).to_s if key == name.to_s
    end
    nil
  end

  def hash_value(hash, key)
    string_key = key.to_s
    symbol_key = key.to_sym
    return hash[string_key] if hash.key?(string_key)
    return hash[symbol_key] if hash.key?(symbol_key)

    nil
  end

  def indexed_value(object, key)
    return nil unless object.respond_to?(:[])

    [key.to_sym, key.to_s].each do |lookup_key|
      candidate = object[lookup_key]
      return candidate unless candidate.nil?
    rescue
      next
    end

    nil
  end

  def numeric_value(raw)
    return 0.0 if raw.nil?

    raw.to_s.to_f
  end

  def integer_value(raw)
    return 0 if raw.nil?

    raw.to_s.to_i
  end
end
