#!/usr/bin/env ruby
#--
# friendfeed.rb - provides access to FriendFeed API's
#++
# Copyright (c) 2009 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'rubygems'
require 'json'
require 'mechanize'
require 'uri'

module FriendFeed
  ROOT_URI      = URI.parse("https://friendfeed.com/")

  # Client library for FriendFeed API.
  class Client
    attr_reader :username

    #
    # Official API
    #

    API_URI = ROOT_API + "/api/"

    private

    def get_api_agent
      @api_agent ||= WWW::Mechanize.new
    end

    def validate
      call_api('validate')
    end

    public

    # Performs a login with a +username+ and +remote key+ and returns
    # self.  This enables call of any official API that requires
    # authentication[6~.  It is not needed to call this method if you
    # have called login(), which internally obtains a remote key and
    # calls this method.  An exception is raised if authentication
    # fails.
    def api_login(username, remote_key)
      @username = username
      @remote_key = remote_key
      @api_agent = get_api_agent()
      @api_agent.auth(@username, @remote_key)
      validate

      self
    end

    # Calls an official API specified by a +path+ with optional
    # parameters, and returns an object parsed from a JSON response.
    def call_api(path, parameters = nil)
      api_agent = get_api_agent()

      uri = API_URI + path
      if parameters
        uri.query = parameters.map { |key, value|
          URI.encode(key) + "=" + URI.encode(value)
        }.join('&')
      end
      JSON.parse(api_agent.get_file(uri))
    end

    # Gets profile information of a user, defaulted to the
    # authenticated user, in hash.
    def get_profile(username = @username)
      call_api('user/%s/profile' % username)
    end

    # Gets an array of profile information of users.
    def get_profiles(usernames)
      call_api('profiles', 'nickname' => usernames.join(','))['profiles']
    end

    # Gets an array of profile information of users a user (defaulted
    # to the authenticated user) is subscribing to.
    def get_real_friends(username = @username)
      get_profiles(get_profile(@username)['subscriptions'].map { |subscription|
          subscription['nickname']
        })
    end

    #
    # Unofficial API
    #

    LOGIN_URI     = ROOT_URI + "/account/login"
    IMAGINARY_URI = ROOT_URI + "/settings/imaginary?num=9999"

    private

    def get_login_agent
      @login_agent or raise 'login() must be called first to use this feature'
    end

    public

    # Performs a login with a +username+ and +password+ and returns
    # self.  This enables call of any API, including both official API
    # and unofficial API.
    def login(username, password)
      @username = username
      @password = password
      @login_agent = WWW::Mechanize.new

      page = @login_agent.get(LOGIN_URI)

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } or raise 'Cannot locate a login form'

      login_form.set_fields(:email => @username, :password => @password)

      page = @login_agent.submit(login_form)

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } and raise 'Login failed'

      page = @login_agent.get(ROOT_URI + "/account/api")
      remote_key = page.parser.xpath("//td[text()='FriendFeed remote key:']/following-sibling::td[1]/text()").to_s

      api_login(username, remote_key)
    end

    # Gets an array of profile information of the authenticated user's
    # imaginary friends, in a format similar to
    # get_real_friends(). [unofficial]
    def get_imaginary_friends
      agent = get_login_agent()

      page = agent.get(IMAGINARY_URI)
      page.parser.xpath("//div[@class='name']//a[@class='l_person']").map { |person_a|
        profile_uri = IMAGINARY_URI + person_a['href']
        profile_page = agent.get(profile_uri)
        {
          'id' => person_a['uid'], 
          'nickname' => person_a.text,
          'profileUrl' => profile_uri.to_s,
          'services' => profile_page.parser.xpath("//div[@class='servicefilter']//a[@class='l_filterservice']").map { |service_a|
            {
              'name' => service_a['servicename'],
              'profileUrl' => (profile_uri + service_a['href']).to_s
            }
          },
        }
      }
    end

    # Posts a request to an internal API of FriendFeed and returns
    # either a parser object for an HTML response or an object parsed
    # from a JSON response).  [unofficial]
    def post(uri, query = {})
      agent = get_login_agent()

      page = agent.post(uri, {
          'at' => agent.cookies.find { |cookie|
            cookie.domain == 'friendfeed.com' && cookie.name == 'AT'
          }.value
        }.merge(query))
      if page.respond_to?(:parser)
        parser = page.parser
        messages = parser.xpath("//div[@id='errormessage']/text()")
        messages.empty? or
          raise messages.map { |message| message.to_s }.join(" ")
        parser
      else
        json = JSON.parse(page.body)
        message = json['error'] and
          raise message
        json
      end
    end

    # Creates an imaginary friend of a given +username+ and returns a
    # unique ID string on success.  Like other methods in general, an
    # exception is raised on failure. [unofficial]
    def create_imaginary_friend(username)
      post(ROOT_URI + '/a/createimaginary', 'name' => username).xpath("//a[@class='l_userunsubscribe']/@uid").to_s
    end

    # Renames an imaginary friend specified by a unique ID to a given
    # +username+. [unofficial]
    def rename_imaginary_friend(id, username)
      post(ROOT_URI + '/a/imaginaryname', 'user' => id, 'name' => username)
    end

    # Adds a Twitter service to an imaginary friend specified by a
    # unique ID. [unofficial]
    def add_twitter_to_imaginary_friend(id, twitter_name)
      post(ROOT_URI + '/a/configureservice', 'stream' => id,
        'service' => 'twitter','username' => twitter_name)
    end

    # Unsubscribe from a user specified by a unique ID. [unofficial]
    def unsubscribe_from_user(id)
      post(ROOT_URI + '/a/userunsubscribe', 'user' => id)
    end
  end
end
