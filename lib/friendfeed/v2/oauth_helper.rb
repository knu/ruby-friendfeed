# -*- mode: ruby -*-
#--
# friendfeed/v2/oauth_helper.rb - defines helper classes for the FriendFeed flavored OAuth
#++
# Copyright (c) 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'cgi'
require 'open-uri'
require 'openssl'
require 'securerandom'
require 'uri'

module FriendFeed
  module V2
    # A helper class that implements FriendFeed's modified OAuth protocol(s).
    #    
    # cf. http://friendfeed.com/api/documentation#authentication
    class OAuthHelper
      OAUTH_BASE_URI = URI.parse('https://friendfeed.com/account/oauth/')

      # Creates a FriendFeed OAuth client initialized with a given
      # +consumer_token+, which may either be a two element array of
      # key and secret, or +OAuthToken+.
      def initialize(consumer_token)
        @consumer_token = OAuthToken[*consumer_token]
      end

      # Obtains an access token with given +username+ and +password+.
      # This implies +access_token=+.
      def get_ia_access_token(username, password)
        @access_token = oauth_parse_response(ia_access_token_uri(username, password).read)
      end

=begin
      def get_request_token()
        @request_token = oauth_parse_response(request_token_uri().read)
      end

      def get_access_token(request_token)
        @access_token = oauth_parse_response(access_token_uri().read)
      end
=end

      # Returns the access token as +OAuthToken+.
      attr_reader :access_token

      # Specifies a previously obtained access +token+ for use in the
      # current session.  A token may be given as an array or an
      # +OAuthToken+.
      def access_token=(token)
        @access_token = OAuthToken[*token]
      end

      # Takes an HTTP request information and returns the signed
      # request.  Output is a tuple of the same columns as the input.
      def signed_request(method, uri, body = nil, headers = nil)
        # Add the OAuth resource request signature if we have credentials
        if @access_token
          parameters = {}
          if query = uri.query
            parameters.update(CGI.parse(query))
          end            
          case method
          when 'POST', 'PUT'
            if body.is_a?(Hash) && !body.any? { |k, v| v.is_a?(IO) }
              parameters.update(body)
            end
          end
          uri = uri.dup
          uri.query = resource_access_query(method, uri, parameters)
        end
        return [method, uri, body, headers]
      end

      private

      def ia_access_token_uri(username, password)
        uri = OAUTH_BASE_URI + 'ia_access_token'
        parameters = {
          'oauth_consumer_key' => @consumer_token.key,
          'oauth_signature_method' => 'HMAC-SHA1',
          'oauth_timestamp' => Time.new.to_i.to_s,
          'oauth_nonce' => SecureRandom.uuid,
          'oauth_version' => '1.0',
          'ff_username' => username,
          'ff_password' => password,
        }
        parameters['oauth_signature'] = oauth_signature('GET', uri, parameters)
        uri.query = oauth_escape_parameters(parameters)
        return uri
      end

=begin
      def request_token_uri()
        uri = OAUTH_BASE_URI + 'request_token'
        # http://oauth.net/core/1.0a/#rfc.section.6.1
        # http://oauth.net/core/1.0a/#rfc.section.6.1.1
        parameters = {
          'oauth_consumer_key' => @consumer_token.key,
          'oauth_signature_method' => 'HMAC-SHA1',
          'oauth_timestamp' => Time.new.to_i.to_s,
          'oauth_nonce' => SecureRandom.uuid,
          'oauth_version' => '1.0',
        }
        parameters['oauth_signature'] = oauth_signature('GET', uri, parameters)
        uri.query = oauth_escape_parameters(parameters)
        return uri
      end

      def authorization_uri()
        uri = OAUTH_BASE_URI + 'authorize'
        # http://oauth.net/core/1.0a/#rfc.section.6.2
        # http://oauth.net/core/1.0a/#rfc.section.6.2.1
        uri.query = oauth_escape_parameters('oauth_token' => @request_token.key)
        return uri
      end

      def access_token_uri()
        uri = OAUTH_BASE_URI + 'access_token'
        # http://oauth.net/core/1.0/#rfc.section.6.3
        # http://oauth.net/core/1.0/#rfc.section.6.3.1
        parameters = {
          'oauth_consumer_key' => @consumer_token.key,
          'oauth_token' => @request_token.key,
          'oauth_signature_method' => 'HMAC-SHA1',
          'oauth_timestamp' => Time.new.to_i.to_s,
          'oauth_nonce' => SecureRandom.uuid,
          'oauth_version' => '1.0',
          # oauth_verifier is missing from this API.
        }
        parameters['oauth_signature'] = oauth_signature('GET', uri, parameters)
        uri.query = oauth_escape_parameters(parameters)
        return uri
      end
=end

      def resource_access_query(method, uri, parameters = {})
        parameters = {
          'oauth_consumer_key' => @consumer_token.key,
          'oauth_token' => @access_token.key,
          'oauth_signature_method' => 'HMAC-SHA1',
          'oauth_timestamp' => Time.new.to_i.to_s,
          'oauth_nonce' => SecureRandom.uuid,
          'oauth_version' => '1.0',
        }.update(parameters)
        parameters['oauth_signature'] = oauth_signature(method, uri, parameters, @access_token)
        return oauth_escape_parameters(parameters)
      end

      def oauth_signature(method, uri, parameters = {}, token = nil)
        # http://oauth.net/core/1.0a/#rfc.section.9.1.2
        normalized_uri = uri.dup
        normalized_uri.scheme = normalized_uri.scheme.downcase
        normalized_uri.host = normalized_uri.host.downcase
        # http://oauth.net/core/1.0a/#rfc.section.9.1.3
        base_string = [
          method.to_s.upcase,
          normalized_uri.to_s,
          # http://oauth.net/core/1.0/#rfc.section.9.1.1
          oauth_escape_parameters(parameters)
        ].map { |s| oauth_escape(s) }.join('&')

        # http://oauth.net/core/1.0/#rfc.section.9.2
        key = [@consumer_token.secret, token ? token.secret : ''].join('&')
        # http://oauth.net/core/1.0/#rfc.section.9.2.1
        return OpenSSL::HMAC.base64digest("SHA1", key, base_string)
      end

      def hash_flatten_each(hash)
        block_given? or return to_enum(__method__, hash)
        hash.each { |key, value|
          if value.is_a?(Array)
            value.each { |element|
              yield key, element
            }
          else
            yield key, value
          end
        }
        self
      end

      def oauth_escape(string)
        # http://oauth.net/core/1.0a/#rfc.section.5.1
        URI.escape(string, /[^A-Za-z0-9\-._~]/)
      end

      def oauth_escape_parameters(parameters)
        hash_flatten_each(parameters).sort_by { |k, v| [k.to_s, v] }.map { |k, v|
          oauth_escape(k.to_s) << '=' << oauth_escape(v)
        }.join('&')
      end

      def oauth_parse_response(body)
        # http://oauth.net/core/1.0a/#rfc.section.5.3
        # http://oauth.net/core/1.0a/#rfc.section.6.3.2
        parameters = CGI.parse(body)
        values = %w[oauth_token oauth_token_secret].map { |key|
          parameters.delete(key).first
        }
        token = OAuthToken[*values]
        parameters.each_pair { |key, value|
          token.extra[key] = value.first
        }
        return token
      end
    end

    class OAuthToken
      attr_reader :key, :secret, :extra

      def initialize(key, secret)
        @key = key
        @secret = secret
        @extra = {}
      end

      def to_a
        [@key, @secret]
      end

      alias to_ary to_a

      class << self
        alias [] new
      end
    end
  end
end

module SecureRandom
  def self.uuid
      str = self.random_bytes(16)
      str[6] = (str[6] & 0x0f) | 0x40
      str[8] = (str[8] & 0x3f) | 0x80

      ary = str.unpack("NnnnnN")
      "%08x-%04x-%04x-%04x-%04x%08x" % ary
  end unless self.respond_to?(:uuid)
end

class OpenSSL::HMAC
  def self.base64digest(*args)
    bin = digest(*args)
    [bin].pack((len = bin.bytesize) > 45 ? "m#{len+2}" : "m").chomp
  end unless self.respond_to?(:base64digest)
end
