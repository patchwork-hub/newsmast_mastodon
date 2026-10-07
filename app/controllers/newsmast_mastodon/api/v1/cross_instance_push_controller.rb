module NewsmastMastodon::Api::V1
  # Receives cross-instance push requests from a trusted partner instance and
  # enqueues delivery to the target local account's registered devices.
  #
  # Auth: HMAC-SHA256 signature over "raw_body + timestamp", shared secret
  # configured via CROSS_INSTANCE_PUSH_SECRET. See CrossInstancePushClient for
  # the corresponding sending-side implementation.
  class CrossInstancePushController < ::Api::BaseController
    MAX_TITLE_LENGTH = 255
    MAX_BODY_LENGTH = 1000
    MAX_DATA_KEYS = 10
    MAX_DATA_VALUE_LENGTH = 500
    SIGNATURE_TOLERANCE = 300 # seconds

    before_action :authenticate_cross_instance_request!

    def create
      puts "Received cross-instance push request with params=#{params.to_unsafe_h}"
      unless valid_params?
        render json: { error: "Invalid request" }, status: :unprocessable_entity
        return
      end

      puts "Calling CrossInstancePushWorker with sanitized data=#{sanitized_data}"

      NewsmastMastodon::CrossInstancePushWorker.perform_async(
        params[:username].to_s,
        params[:title].to_s,
        params[:body].to_s,
        sanitized_data
      )

      render json: { message: "accepted" }, status: :accepted
    end

    private

    def valid_params?
      params[:username].present? &&
        params[:title].to_s.length.between?(1, MAX_TITLE_LENGTH) &&
        params[:body].to_s.length.between?(1, MAX_BODY_LENGTH) &&
        data_param.size <= MAX_DATA_KEYS &&
        data_param.values.all? { |value| value.to_s.length <= MAX_DATA_VALUE_LENGTH }
    end

    def data_param
      params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : {}
    end

    def sanitized_data
      data_param.to_h.transform_values(&:to_s)
    end

    def authenticate_cross_instance_request!
      sig_header = request.headers["X-Signature"]
      if sig_header.blank?
        render json: { error: "Missing signature" }, status: :unauthorized
        return
      end

      parts = sig_header.split(", ").map { |part| part.split("=", 2) }.to_h
      received_hash = parts["sha256"]
      timestamp = parts["t"]

      if received_hash.blank? || timestamp.blank?
        render json: { error: "Malformed signature" }, status: :unauthorized
        return
      end

      unless valid_timestamp?(timestamp)
        render json: { error: "Stale request" }, status: :unauthorized
        return
      end

      secret = ENV["CROSS_INSTANCE_PUSH_SECRET"]
      if secret.blank?
        Rails.logger.error("CROSS_INSTANCE_PUSH_SECRET environment variable is missing")
        render json: { error: "Not configured" }, status: :internal_server_error
        return
      end

      request.body.rewind
      raw_body = request.body.read
      request.body.rewind

      expected_hash = OpenSSL::HMAC.hexdigest("sha256", secret, "#{raw_body}#{timestamp}")

      unless ActiveSupport::SecurityUtils.secure_compare(expected_hash, received_hash)
        render json: { error: "Invalid signature" }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "[CrossInstancePushController] Error verifying signature: #{e.message}"
      render json: { error: "Invalid request" }, status: :unauthorized
    end

    def valid_timestamp?(timestamp)
      (Time.now.to_i - Integer(timestamp, 10)).abs <= SIGNATURE_TOLERANCE
    rescue ArgumentError, TypeError
      false
    end
  end
end
