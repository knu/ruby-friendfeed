# -*- mode: ruby -*-
#--
# friendfeed/v2/noauth.rb - represents a non-authenticated HTTP agent
#++
# Copyright (c) 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'mechanize'

module FriendFeed
  module V2
    # Represents a non-authenticated HTTP agent
    class NoAuth
      def initialize(options = nil)
        @mechanize = Mechanize.new
      end

      attr_accessor :base_uri

      # Performs a GET request.
      def get(uri, headers = nil)
        parse_response(@mechanize.get(:url => abs_uri(uri), :headers => headers))
      end

      # Performs a POST request.
      def post(uri, body = nil, headers = nil)
        parse_response(@mechanize.post(abs_uri(uri), body, headers || {}))
      end

      private

      def abs_uri(uri)
        if @base_uri
          @base_uri + uri
        else
          uri
        end
      end

      def parse_response(response)
        if !response.respond_to?(:[])
          def response.[](key)
            header[key]
          end
        end
        response
      end
    end
  end
end
