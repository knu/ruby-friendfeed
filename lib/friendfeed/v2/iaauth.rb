# -*- mode: ruby -*-
#--
# friendfeed/v2/iaauth.rb - represents an Installed Application Auth client
#++
# Copyright (c) 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'friendfeed/v2/noauth'
require 'friendfeed/v2/oauth_helper'

module FriendFeed
  module V2
    # Represents an Installed Application Auth client
    class IAAuth < NoAuth
      # Creates an authentication client for an installed application
      # with +consumer_token+ and optional +access_token+, which can
      # be obtained by calling the +get_is_access_token+ method.
      def initialize(consumer_token, access_token = nil, options = nil)
        if access_token.is_a?(Hash)
          options, access_token = access_token, nil
        end
        @helper = OAuthHelper.new(consumer_token)
        @helper.access_token = access_token if access_token
        super(options)
      end

      # Performs installed application authentication with given
      # +username+ and +password+, and returns an access token.  The
      # obtained access token is used for the running session.
      #
      # Once this is done, the application should not store the user's
      # password but may instead keep the access token for later use
      # with access_token=.  Access tokens are revoked when the user
      # changes his or her password.
      def get_ia_access_token(username, password)
        @helper.get_ia_access_token(username, password)
      end

      # Gets the access token.
      def access_token
        @helper.access_token
      end

      # Sets the access token.
      def access_token=(access_token)
        @helper.access_token = access_token
      end

      # Performs a GET request.
      def get(uri, headers = nil)
        method, uri, body, headers = @helper.signed_request('GET', abs_uri(uri), nil, headers)
        super(uri, headers)
      end

      # Performs a POST request.
      def post(uri, body = nil, headers = nil)
        method, uri, body, headers = @helper.signed_request('POST', abs_uri(uri), body, headers)
        super(uri, body, headers)
      end
    end
  end
end
