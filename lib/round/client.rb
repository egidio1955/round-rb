require "patchboard"
require "base64"
require "date"

module Round

  def self.url
    "https://api-develop.gem.co"
  end

  def self.client(url=nil)
    url ||= Round.url
    @patchboard ||= ::Patchboard.discover(url) { Client::Context.new }
    Client.new(@patchboard.spawn)
  end

  class Client

    def initialize(patchboard_client)
      @patchboard_client = patchboard_client
    end

    def authenticate_application(app_url, api_token, instance_id)
      @patchboard_client
        .context
        .authorize(Context::Scheme::APPLICATION, api_token: api_token, instance_id: instance_id)
      self.application(app_url)
    end

    def authenticate_developer(email, privkey)
      @patchboard_client
        .context
        .authorize(Context::Scheme::DEVELOPER, email: email, privkey: privkey)
      self.developer(email)
    end

    def authenticate_device(email, api_token, user_token, device_id)
      @patchboard_client
        .context
        .authorize(Context::Scheme::DEVICE, api_token: api_token, user_token: user_token, device_id: device_id)
      self.user(email)
    end

    def authenticate_otp(api_token, key = nil, secret = nil)
      @patchboard_client
        .context
        .authorize(Context::Scheme::OTP, api_token: api_token, key: key, secret: secret)
    end

    def resources
      @patchboard_client.resources
    end

    def developers
      DeveloperCollection.new(resource: resources.developers, client: self)
    end

    def developer(email)
      Developer.new(resource: resources.developer_query(email: @developer_email).get, client: self)
    end

    def users
      UserCollection.new(resource: resources.users, client: self)
    end

    def application(app_url)
      Application.new(resource: resources.application(app_url), client: self)
    end

    def user(email)
      User.new(resource: resources.user_query(email: email), client: self)
    end

    class Context
      module Scheme
        DEVELOPER = "Gem-Developer"
        DEVELOPER_SESSION = "Gem-Developer-Session"
        DEVICE = "Gem-Device"
        APPLICATION = "Gem-Application"
        USER = "Gem-User"
        OTP = "Gem-OOB-OTP"
      end

      SCHEMES = [Scheme::DEVELOPER, Scheme::DEVELOPER_SESSION, 
        Scheme::DEVICE, Scheme::APPLICATION, Scheme::USER, Scheme::OTP]

      attr_accessor :schemes

      def initialize
        @schemes = {}
      end

      def authorize(scheme, params)
        raise ArgumentError, "Unknown auth scheme" unless SCHEMES.include?(scheme)
        @schemes[scheme] = params
      end

      def compile_params(params)
        if params.empty?
          # crappy alternative to raising an error when there are no params
          # TODO: probably should raise an error
          "data=none"
        else
          params.map {|key, value|
            #super hacky. but it's late.
            value.tr!('=', '') if key.eql?(:signature)
            %Q[#{key}="#{value}"]}.join(", ")
        end
      end

      def authorizer(options = {})
        schemes, resource, action, request = options.values_at(:schemes, :resource, :action, :request)
        schemes = [schemes] if schemes.is_a? String
        schemes.each do |scheme|
          if params = @schemes[scheme]
            credential = nil
            if scheme.eql?(Scheme::DEVELOPER)
              params = { 
                email: params[:email],
                signature: developer_signature(request[:body], params[:privkey])
              }
            end
            credential = compile_params(params)
            return [scheme, credential]
          end
        end
        raise "Action: #{action}.  No authorization available for '#{schemes}'"
      end

      def developer_signature(request_body, privkey)
        body = request_body ? JSON.parse(request_body) : {}
        key = OpenSSL::PKey::RSA.new privkey
        today = Date.today.strftime('%Y/%m/%d')
        content = "#{body.to_json}-#{today}"
        signature = key.sign(OpenSSL::Digest::SHA256.new, content)
        Base64.urlsafe_encode64(signature)
      end

      def inspect
        # Hide the secret token when printed
        id = "%x" % (self.object_id << 1)
        %Q(#<#{self.class}:0x#{id})
      end
    end
  end

end
