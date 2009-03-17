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

  class Client
    attr_reader :username

    #
    # Official API
    #

    private

    def get_api_agent
      @api_agent or raise 'login() or api_login() must be called first to use this feature'
    end

    public

    def api_login(username, remote_key)
      @username = username
      @remote_key = remote_key
      @api_agent = WWW::Mechanize.new
      @api_agent.auth(@username, @remote_key)
      validate

      self
    end

    def call_api(path, parameters = nil)
      api_agent = get_api_agent()

      uri = ROOT_URI + "/api/" + path
      if parameters
        uri.query = parameters.map { |key, value|
          URI.encode(key) + "=" + URI.encode(value)
        }.join('&')
      end
      JSON.parse(api_agent.get_file(uri))
    end

    def validate
      call_api('validate')
    end

    def get_profile(username = @username)
      call_api('user/%s/profile' % username)
    end

    def get_profiles(usernames)
      call_api('profiles', 'nickname' => usernames.join(','))['profiles']
    end

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

    def get_agent
      @agent or raise 'login() must be called first to use this feature'
    end

    public

    def login(username, password)
      @username = username
      @password = password
      @agent = WWW::Mechanize.new

      page = @agent.get(LOGIN_URI)

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } or raise 'Cannot locate a login form'

      login_form.set_fields(:email => @username, :password => @password)

      page = @agent.submit(login_form)

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } and raise 'Login failed'

      page = @agent.get(ROOT_URI + "/account/api")
      remote_key = page.parser.xpath("//td[text()='FriendFeed remote key:']/following-sibling::td[1]/text()").to_s

      api_login(username, remote_key)
    end

    def get_imaginary_friends
      agent = get_agent()

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

    def post(uri, query = {})
      agent = get_agent()

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

    def create_imaginary_friend(username)
      post(ROOT_URI + '/a/createimaginary', 'name' => username).xpath("//a[@class='l_userunsubscribe']/@uid").to_s
    end

    def add_twitter_to_imaginary_friend(id, twitter_name)
      post(ROOT_URI + '/a/configureservice', 'stream' => id,
        'service' => 'twitter','username' => twitter_name)
    end

    def unsubscribe_from_user(username)
      post(ROOT_URI + '/a/userunsubscribe', 'user' => username)
    end
  end
end
