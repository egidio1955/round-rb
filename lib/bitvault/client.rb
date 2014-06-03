require "patchboard"
require "base64"

module BitVault

  class Patchboard < Patchboard

    BASE_URL = ::API_HOST if defined? ::API_HOST
    BASE_URL ||= 'http://bitvault.pandastrike.com/'

    def self.authed_client(options = {})
      @@patchboard ||= self.discover(BASE_URL, :namespace => self::Resources) { BitVault::Patchboard::Context.new }
      raise 'No credentials supplied' unless options[:email] or options[:app_url]
      client = @@patchboard.spawn
      if options[:email] && options[:password]
        client.context.set_basic(options[:email], options[:password])
      elsif options[:app_url] && options[:app_url]
        client.context.set_token(options[:app_url], options[:api_token])
      end
      client
    end

    module Resources; end

    class Client < Patchboard::Client
      def user
        unless @user
          user_resource = self.resources.login(email: self.context.email).get
          @user = User.new(resource: user_resource)
        end
        
        @user
      end

      def application
        unless @application
          application_resource = self.resources.application(self.context.app_url).get
          @application = BitVault::Application.new(resource: application_resource)
        end

        @application
      end
    end

    # A class providing the `authorizer` method to allow for distinct
    # authentication contexts.  This may later be useful for many
    # other purposes.  It will be used in Patchboard#spawn, which
    # returns a "sub-client".
    class Context
      attr_accessor :email, :password, :api_token, :app_url

      def set_basic(email, password)
        @email = email
        @password = password
        @basic = Base64.encode64("#{email}:#{password}").gsub("\n", "")
      end

      def set_token(app_url, api_token)
        @app_url = app_url
        @api_token = api_token
      end

      # Provided with the authentication scheme for an Authorization
      # header, the resource instance on which an action is being called,
      # and the name of the action, the `authorizer` method returns
      # the credential to be used for the Authorization header value.
      #
      # This particular Context class, obviously, isn't doing anything
      # fancy with the authorizer.  More advanced applications, though,
      # can reflect on the arguments to do very granular authorization.
      def authorizer(scheme, resource, action)
        case scheme
        when "Basic"
          raise "Must call set_basic(email, password) first" unless @basic
          @basic
        when "BitVault-Token"
          raise "Must call set_token(api_token) first" unless @api_token
          @api_token
        end
      end

      def inspect
        # Hide the secret token when printed
        id = "%x" % (self.object_id << 1)
        %Q(#<#{self.class}:0x#{id})
      end
    end

  end

end

