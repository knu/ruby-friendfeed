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

        type, *extensions = response['Content-Type'].split(/;\s*/)
        parameters = {}
        extensions.each { |extension|
          key, value = extension.split('=')
          parameters[key] = value
        }

        case type
        when 'text/javascript'
          JSON.parse(response.body)
        else
          response.body
        end
      end

      # Validates authentication credentials.
      def validate(options = nil)
        Object::Feed.create call_api(compose_uri('validate', options)), self
      end

      # Gets a feed identified by a given +id+.  The +id+ can be an
      # array such as [username, :friends] or [:list, list_id,
      # :summary, n], which elements are joined with slash.
      def get_feed(id, options = nil)
        Object::Feed.create call_api(compose_uri('feed/%s' % join(id, '/'), options)), self
      end

      # Gets an entry identified by a given +id+.
      def get_entry(id, options = nil)
        Object::Entry.create call_api(compose_uri('entry/%s' % join(id, '/'), options)), self
      end

      # Gets an entry that an ff.im +short_id+ points to.
      def decode_short(short_id, options = nil)
        Object::Entry.create call_api(compose_uri('short/%s' % short_id, options)), self
      end

      # Gets an entry identified by a given +entry_id+.  The resulted
      # entry has short_id and short_url in it.
      def encode_short(entry_id, options = nil)
        Object::Entry.create call_api('short', merge_hashes({ :entry => entry_id }, options)), self
      end

      # Gets the feed lists in the side bar of the authenticated user.
      def get_feedlist(id, options = nil)
       Object::FeedList.create call_api('feedlist'), self
      end

      # Gets the information about a feed specified by a given +id+.
      def get_feedinfo(id, options = nil)
       Object::Feed.create call_api('feedinfo/%s' % id), self
      end

      private

      # If an array-like is given, join with delimiter.  Convert to
      # string otherwise.
      def join(object, delimiter = ',')
        if array = Array.try_convert(object)
          array.join(delimiter)
        else
          object.to_s
        end
      end

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
            value = join(value)
            URI.encode(key) + "=" + URI.encode(value)
          }.join('&')
        end
        uri
      end
    end

    autoload :HTTPAuth, 'friendfeed/v2/httpauth'
    autoload :IAAuth, 'friendfeed/v2/iaauth'
  end
end
