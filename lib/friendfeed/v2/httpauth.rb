# -*- mode: ruby -*-
#--
# friendfeed/v2/httpauth.rb - represents a basic-authenticated HTTP client
#++
# Copyright (c) 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'mechanize'
require 'friendfeed/v2/noauth'

module FriendFeed
  module V2
    class HTTPAuth < NoAuth
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
