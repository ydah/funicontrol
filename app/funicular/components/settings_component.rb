class SettingsComponent < ApplicationComponent
  def initialize_state
    {
      prefs: default_prefs,
      saved: false
    }
  end

  def component_mounted
    stored = prefs_store.value
    patch(prefs: stored) if stored
  end

  def render
    render_shell("Settings") do
      div(class: "panel settings-panel") do
        h3 { "Operator Preferences" }
        form_for(:prefs, on_submit: :save_prefs, class: "stack") do |f|
          field_group("Theme") do
            f.select(:theme, [[ "dark", "Dark" ], [ "light", "Light" ]], class: "input")
          end
          field_group("Density") do
            f.select(:density, [[ "comfortable", "Comfortable" ], [ "compact", "Compact" ]], class: "input")
          end
          div(class: "field inline") do
            f.checkbox(:sound_enabled)
            label { "Sound enabled" }
          end
          f.submit("Save settings", class: "button primary")
        end
        p(class: "notice") { "Saved locally" } if state.saved
        div(class: "row") do
          button(class: "button secondary", onclick: :clear_local_data) { "Clear local data" }
        end
      end
    end
  end

  def field_group(label_text, &block)
    div(class: "field") do
      label(class: "field-label") { label_text }
      block.call
    end
  end

  def save_prefs(form_data)
    prefs_store.value = form_data
    patch(saved: true)
  end

  def clear_local_data
    Funicular::Store.dispatch(:logout)
    prefs_store.value = default_prefs
    patch(prefs: default_prefs, saved: true)
  end

  def prefs_store
    OperatorPrefsStore.where
  end

  def default_prefs
    {
      theme: "dark",
      density: "comfortable",
      sound_enabled: true
    }
  end
end
