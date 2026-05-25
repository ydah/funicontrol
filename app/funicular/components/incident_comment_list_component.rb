class IncidentCommentListComponent < ApplicationComponent
  def render
    div(class: "comment-list") do
      if (props[:comments] || []).empty?
        p(class: "muted") { "No comments yet." }
      end
      (props[:comments] || []).each do |comment|
        div(class: "comment") do
          div(class: "row spread") do
            span(class: "comment-author") { value(comment, :author_name).to_s }
            span(class: "muted") { format_time(value(comment, :created_at)) }
          end
          p { value(comment, :body).to_s }
        end
      end
    end
  end
end
