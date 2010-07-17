# -*- mode: ruby -*-
#--
# friendfeed/v2/basicauth.rb - represents a basic-authenticated HTTP client
#++
# Copyright (c) 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'friendfeed/v2/noauth'

module FriendFeed
  module V2
    # Represents a basic-authenticated HTTP client.
    class BasicAuth < NoAuth
      # Creates a basic-authenticated HTTP client, with given
      # +username+ and +password+.  Note that +password+ must be the
      # user's remote key if this client is used for the official
      # FriendFeed API.
      def initialize(username, password, options = nil)
        super(options)
        @mechanize.auth(username, password)
        @username = username
        @password = password
      end

      attr_accessor :username, :password
    end
  end
end
