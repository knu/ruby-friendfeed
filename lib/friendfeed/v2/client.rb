# -*- mode: ruby -*-
#--
# friendfeed/v2.rb - provides access to FriendFeed V2 API
#++
# Copyright (c) 2009, 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'json'
require 'mechanize'
require 'uri'
require 'friendfeed/compat'
require 'friendfeed/v2/object'
require 'friendfeed/v2/noauth'

module FriendFeed
  module V2
    # Client library for FriendFeed V2 API.
    class Client
      attr_reader :nickname

      #
      # Official API
      #

      API_URI = URI.parse("http://friendfeed-api.com/v2/")

      # Creates a V2 Client object, optionally initialized with an
      # +auth+ object.
      def initialize(auth = nil)
        if auth
          login(auth)
        else
          @auth = NoAuth.new
          @auth.base_uri = API_URI
        end
      end

      def login(auth)
        @auth = auth
        @auth.base_uri = API_URI
        validate
      end

      # Calls an official API at a +path+ with optional +body+, which
      # can either be a parameter hash or a body string.  If +body+ is
      # given, a POST request is issued.  A GET request is issued
      # otherwise.
      #
      # Returns an object (usually a hash) parsed from a JSON
      # response, or a response body string if the response is not
      # JSON.
      def call_api(path, body = nil)
        if body
          response = @auth.post(path, body)
        else
          response = @auth.get(path)
        end

        case response['Content-Type']
        when 'text/javascript'
          response.body
        else
          JSON.parse(response.body)
        end
      end

      # Gets feed identified by a given +id+,
      # defaulted to the authenticated user, in hash.
      def get_feed(id = nil, options = nil)
        case id
        when nil
          id = @nickname
        when Hash
          options = id if options.nil?
        end
        Object::Feed.create call_api(compose_uri('feed/%s' % id, options)), self
      end

      # Gets feed identified by a given +id+,
      # defaulted to the authenticated user, in hash.
      def get_entry(id, options = nil)
        Object::Entry.create call_api(compose_uri('entry/%s' % id, options)), self
      end

      def decode_short(short_id, options = nil)
        Object::Entry.create call_api(compose_uri('short/%s' % short_id, options)), self
      end

      def encode_short(entry_id, options = nil)
        Object::Entry.create call_api('short', merge_hashes({ :entry => entry_id }, options)), self
      end

      private

      def merge_hashes(*hashes)
        hashes.inject({}) { |i, j|
          i.update(j) if j
          i
        }
      end

      def compose_uri(path, parameters = nil)
        uri = URI.parse(path)
        if parameters
          uri.query = parameters.map { |key, value|
            key = key.to_s
            if array = Array.try_convert(value)
              value = array.join(',')
            else
              value = value.to_s
            end
            URI.encode(key) + "=" + URI.encode(value)
          }.join('&')
        end
        uri
      end
    end
  end
end
