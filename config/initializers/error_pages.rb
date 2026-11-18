Rails.application.config.after_initialize do
  if defined?(ActionDispatch::DebugView)
    custom_path = Rails.root.join("app/views").to_s
    unless ActionDispatch::DebugView::RESCUES_TEMPLATE_PATHS.include?(custom_path)
      ActionDispatch::DebugView::RESCUES_TEMPLATE_PATHS.unshift(custom_path)
    end
  end
end

