class NewsmastMastodon::ArticleNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: "default", retry: false, dead: true

  def perform(article_data)
    NewsmastMastodon::ArticleNotificationService.new.call(article_data)
  rescue => e
    Rails.logger.error "[NewsmastMastodon::ArticleNotificationWorker] Error processing : #{e.message}\n#{e.backtrace.join("\n")}"
    { status: :error, error: e.message }
  end
end
