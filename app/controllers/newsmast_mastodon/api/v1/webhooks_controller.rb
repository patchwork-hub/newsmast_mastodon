module NewsmastMastodon::Api::V1
  class WebhooksController < ::Api::BaseController
    before_action :authenticate_ghost_request!, only: [ :handle_ghost ]
    before_action :authenticate_wordpress_request!, only: [ :handle_wordpress ]

    # manage Ghost webhook
    def handle_ghost
      ghost_post_articles = params[:post]
      if ghost_post_articles.present?
        ghost_post_data = {
          "title" => ghost_post_articles[:current][:title],
          "article_id" => ghost_post_articles[:current][:id].to_s
        }
        NewsmastMastodon::GhostNotificationWorker.perform_async(ghost_post_data)
        render json: { message: "Webhook received" }, status: :ok
      else
        render json: { error: "No post data found" }, status: :unprocessable_entity
      end
    rescue => e
      render json: { errors: e.message }, status: :internal_server_error
    end

    # manage WordPress webhook
    def handle_wordpress
      wordpress_post = params.to_unsafe_h
      if wordpress_post.present?
        wordpress_post_data = {
          "title" => wordpress_post[:post][:post_title],
          "article_id" => wordpress_post[:post_id].to_s
        }
        NewsmastMastodon::ArticleNotificationWorker.perform_async(wordpress_post_data)
        render json: { message: "Webhook received" }, status: :ok
      else
        render json: { error: "No article data" }, status: :unprocessable_entity
      end
    end

    private

    def authenticate_ghost_request!
      sig_header = request.headers["HTTP_X_GHOST_SIGNATURE"]
      if sig_header.blank?
        render json: { error: "Missing Signature" }, status: :unauthorized
        return
      end

      # Parse signature and timestamp
      # Format: "sha256=hash, t=12345"
      parts = sig_header.split(", ").map { |p| p.split("=") }.to_h
      received_hash = parts["sha256"]
      timestamp = parts["t"]

      # Extract Raw Body
      request.body.rewind
      raw_body = request.body.read
      request.body.rewind # Reset for Rails params usage

      # Verify HMAC (Ghost format: body + timestamp)
      secret = ENV["GHOST_WEBHOOK_SECRET"]
      if secret.blank?
        raise "GHOST_WEBHOOK_SECRET environment variable is missing"
      end
      data_to_sign = "#{raw_body}#{timestamp}"
      expected_hash = OpenSSL::HMAC.hexdigest("sha256", secret, data_to_sign)

      # Compare
      unless ActiveSupport::SecurityUtils.secure_compare(expected_hash, received_hash)
        render json: { error: "Invalid Signature" }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "Error processing : #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { errors: e.message }, status: :internal_server_error
    end

    def authenticate_wordpress_request!
      wp_webhook_token = ENV["WP_WEBHOOK_TOKEN"]
      if wp_webhook_token.blank?
        raise "WP_WEBHOOK_TOKEN environment variable is missing"
      end

      authorized = Rack::Utils.secure_compare(
        params[:auth_token].to_s,
        wp_webhook_token.to_s
      )

      unless authorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "Error processing : #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { errors: e.message }, status: :internal_server_error
    end
  end
end
