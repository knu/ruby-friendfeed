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
      # +username+ and +remotekey+.
      def initialize(username, remotekey, options = nil)
        super(options)
        @mechanize.auth(username, remotekey)
        @username = username
        @remotekey = remotekey
      end

      attr_accessor :username, :remotekey
    end
  end
end
