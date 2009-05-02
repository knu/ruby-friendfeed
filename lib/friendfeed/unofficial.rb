#!/usr/bin/env ruby
#--
# friendfeed/unofficial.rb - provides access to FriendFeed unofficial API's
#++
# Copyright (c) 2009 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'friendfeed'
require 'rubygems'
require 'json'
require 'mechanize'
require 'uri'

module FriendFeed
  class Client
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

    # Performs a login with a +nickname+ and +password+ and returns
    # self.  This enables call of any API, including both official API
    # and unofficial API.
    def login(nickname, password)
      @nickname = nickname
      @password = password
      @login_agent = WWW::Mechanize.new

      page = @login_agent.get(LOGIN_URI)

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } or raise 'Cannot locate a login form'

      login_form.set_fields(:email => @nickname, :password => @password)

      page = login_form.submit

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } and raise 'Login failed'

      page = @login_agent.get(ROOT_URI + "/account/api")
      remote_key = page.parser.xpath("//td[text()='FriendFeed remote key:']/following-sibling::td[1]/text()").to_s

      api_login(nickname, remote_key)
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

    # Creates an imaginary friend of a given +nickname+ and returns a
    # unique ID string on success.  Like other methods in general, an
    # exception is raised on failure. [unofficial]
    def create_imaginary_friend(nickname)
      post(ROOT_URI + '/a/createimaginary', 'name' => nickname).xpath("//a[@class='l_userunsubscribe']/@uid").to_s
    end

    # Renames an imaginary friend specified by a unique ID to a given
    # +nickname+. [unofficial]
    def rename_imaginary_friend(id, nickname)
      post(ROOT_URI + '/a/imaginaryname', 'user' => id, 'name' => nickname)
    end

    # Adds a feed to an imaginary friend specified by a unique ID.
    # Specify 'isstatus' => 'on' to display entries as messages (no
    # link), and 'importcomment' => 'on' to include entry description
    # as a comment. [unofficial]
    def add_service_to_imaginary_friend(id, service, options = nil)
      params = {
        'stream' => id,
        'service' => service,
      }
      params.update(options) if options
      post(ROOT_URI + '/a/configureservice', params)
    end

    # Edits a service of an imaginary friend specified by a unique
    # ID. [unofficial]
    def edit_service_of_imaginary_friend(id, serviceid, service, options = nil)
      params = {
        'stream' => id,
        'service' => service,
        'serviceid' => serviceid,
        'url' => url,
      }
      params.update(options) if options
      post(ROOT_URI + '/a/configureservice', params)
    end

    # Removes a service of an imaginary friend specified by a unique
    # ID.  Specify 'deleteentries' => 'on' to delete entries
    # also. [unofficial]
    def remove_service_from_imaginary_friend(id, serviceid, service, options = nil)
      params = {
        'stream' => id,
        'service' => service,
        'serviceid' => serviceid,
      }
      params.update(options) if options
      post(ROOT_URI + '/a/removeservice', params)
    end

    # Adds a feed to an imaginary friend specified by a unique ID.
    # Specify 'isstatus' => 'on' to display entries as messages (no
    # link), and 'importcomment' => 'on' to include entry description
    # as a comment. [unofficial]
    def add_feed_to_imaginary_friend(id, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      add_service_to_imaginary_friend(id, 'feed', options)
    end

    # Adds a Twitter service to an imaginary friend specified by a
    # unique ID. [unofficial]
    def add_twitter_to_imaginary_friend(id, twitter_name)
      add_service_to_imaginary_friend(id, 'twitter', 'username' => twitter_name)
    end

    # Edits a feed of an imaginary friend specified by a unique ID.
    # Specify 'isstatus' => 'on' to display entries as messages (no
    # link), and 'importcomment' => 'on' to include entry description
    # as a comment. [unofficial]
    def edit_feed_of_imaginary_friend(id, serviceid, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      add_service_to_imaginary_friend(id, 'feed', options)
    end

    # Edits a Twitter service of an imaginary friend specified by a
    # unique ID.  Specify 'isstatus' => 'on' to display entries as
    # messages (no link), and 'importcomment' => 'on' to include entry
    # description as a comment. [unofficial]
    def edit_twitter_of_imaginary_friend(id, serviceid, twitter_name)
      edit_service_of_imaginary_friend(id, serviceid, 'twitter', 'username' => twitter_name)
    end

    # Removes a feed from an imaginary friend specified by a unique
    # ID.  Specify 'deleteentries' => 'on' to delete entries
    # also. [unofficial]
    def remove_feed_from_imaginary_friend(id, serviceid, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      remove_service_from_imaginary_friend(id, serviceid, 'feed', options = nil)
    end

    # Removes a Twitter service from an imaginary friend specified by
    # a unique ID.  Specify 'deleteentries' => 'on' to delete entries
    # also. [unofficial]
    def remove_twitter_from_imaginary_friend(id, serviceid, twitter_name)
      params = { 'username' => twitter_name }
      params.update(options) if options
      remove_service_from_imaginary_friend(id, serviceid, 'twitter', options = nil)
    end

    # Changes the picture of an imaginary friend. [unofficial]
    def change_picture_of_imaginary_friend(id, io)
      post(ROOT_URI + '/a/changepicture', 'stream' => id,
        'picture' => io)
    end

    # Removes an imaginary friend specified by a unique
    # ID. [unofficial]
    def remove_imaginary_friend(id)
      post(ROOT_URI + '/a/userunsubscribe', 'user' => id)
    end
  end
end
