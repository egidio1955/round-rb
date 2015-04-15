module Round
  class Application < Round::Base
    association :users, 'Round::UserCollection'
    association :wallets, 'Round::WalletCollection'

    def authorize_instance(name)
      @resource.authorize_instance(name: name)
    end

    def wallets
      Round::WalletCollection.new(resource: @resource.wallets, client: @client, uses_app: true)
    end

    def user_from_key(key)
      users.detect { |u| u.key == key }
    end

    def self.hash_identifier
      'name'
    end

  end

  class ApplicationCollection < Round::Collection

    def content_type
      Round::Application
    end

    def create(name, callback_url = nil)
      params = { name: name }
      params.merge!(callback_url: callback_url) if callback_url
      app_resource = @resource.create(params)
      app = Round::Application.new(resource: app_resource, client: @client)
      add(app)
      app
    end

  end
end
