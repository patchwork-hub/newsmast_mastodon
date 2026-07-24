# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::Overrides::NotifyServiceExtension, type: :service do
  let(:service_class) do
    Class.new do
      include NewsmastMastodon::Overrides::NotifyServiceExtension

      attr_reader :drop_options

      private

      def drop?
        @drop_options = @options
        true
      end
    end
  end

  it "forwards keyword options to the host notification conditions" do
    recipient = instance_double("Account", user: Object.new)
    notification = instance_double("Notification")

    stub_const("Notification", class_double("Notification", new: notification))

    service = service_class.new
    service.call(recipient, :mention, Object.new, silenced: true)

    expect(service.drop_options).to eq(silenced: true)
  end
end
