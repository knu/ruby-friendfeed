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

    LOGIN_URI     = ROOT_URI + "/account/login?v=2"

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
      @login_agent = Mechanize.new

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
      remote_key = page.parser.xpath("(//table[@class='remotekey']//td[@class='value'])[2]/text()").to_s

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
        }.update(query))
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
        if html_frag = json['html']
          html_body = '<html><body>' << html_frag << '</body></html>'
          json['html_parser'] = Mechanize.html_parser.parse(html_body)
        end
        json
      end
    end

    # Gets a list of services of a user or a room of a given
    # +nickname+, defaulted to the authenticated user.
    def get_services(nickname = @nickname)
      agent = get_login_agent()

      services_uri = ROOT_URI + ("/%s/services" % URI.encode(nickname))
      parser = agent.get(services_uri).parser

      active_servicelist = parser.xpath("//*[@class='active']//ul[@class='servicelist']")

      if !active_servicelist.empty?
        services = active_servicelist.xpath("./li/a").map { |a|
          {
            'service' => a['class'].split.find { |a_class|
              a_class != 'l_editservice' && a_class != 'service'
            },
            'serviceid' => a['serviceid'].to_s,
          }
        }
        profile_uri = ROOT_URI + ("/%s" % URI.encode(nickname))
        agent.get(profile_uri).parser.xpath("//div[@class='servicespreview']/a").each_with_index { |a, i|
          href = (profile_uri + a['href'].to_s).to_s
          break if profile_uri.route_to(href).relative?
          services[i]['profileUrl'] = href
        }
      else
        services = parser.xpath("//ul[@class='servicelist']/li/a").map { |a|
          {
            'service' => a['class'].split.find { |a_class|
              a_class != 'service'
            },
            'profileUrl' => (services_uri + a['href'].to_s).to_s,
          }
        }
      end
      services
    end

    # Creates a new feed of a given (unique) +nickname+ and display
    # +name+, and returns a unique ID string on success.  The +type+
    # can be one of "group", "microblog" and "public".  Like other
    # methods in general, an exception is raised on
    # failure. [unofficial]
    def create_group(nickname, name, type = 'group')
      post(ROOT_URI + '/a/createfeed', 'nickname' => nickname, 'name' => name, 'type' => type).xpath("(//a[@class='l_feedinvite'])[1]/@sid").to_s
    end

    EDIT_GROUP_URI = ROOT_URI + '/a/editprofile'

    # Gets profile information of a group specified by a unique
    # ID. [unofficial]
    def get_group(id)
      parser = post(ROOT_URI + '/a/profiledialog', 'stream' => id)['html_parser']
      form = parser.xpath("//form[1]")
      hash = { 'stream' => id }
      form.xpath(".//input").each { |input|
        case input['type'].downcase
        when 'text'
          hash[input['name']] = input['value']
        when 'radio', 'checkbox'
          if input['checked']
            value = input['value']
            if value && !value.empty?
              hash[input['name']] = value
            end
          end
        end
      }
      form.xpath(".//textarea").each { |input|
        hash[input['name']] = input.text
      }
      hash
    end

    # Edits profile information of a group specified by a unique ID.
    # Supported fields are 'nickname', 'name', 'description', 'access'
    # ('private', 'semipublic' or 'public'), and 'anyoneinvite' (none
    # or '1').  [unofficial]
    def edit_group(id, hash)
      param_hash = get_group(id)
      param_hash.update(hash)
      post(EDIT_GROUP_URI, param_hash)
    end

    # Adds a feed to the authenticated user, a group or an imaginary
    # friend specified by a unique ID.  Specify 'isstatus' => 'on' to
    # display entries as messages (no link), and 'importcomment' =>
    # 'on' to include entry description as a comment. [unofficial]
    def add_service(id, service, options = nil)
      params = {
        'stream' => id,
        'service' => service,
      }
      params.update(options) if options
      post(ROOT_URI + '/a/configureservice', params)
    end

    # Edits a service of the authenticated user, a group or an
    # imaginary friend specified by a unique ID. [unofficial]
    def edit_service(id, serviceid, service, options = nil)
      params = {
        'stream' => id,
        'service' => service,
        'serviceid' => serviceid,
      }
      params.update(options) if options
      post(ROOT_URI + '/a/configureservice', params)
    end

    # Removes a service of the authenticated user, a group or an
    # imaginary friend specified by a unique ID.  Specify
    # 'deleteentries' => 'on' to delete entries also. [unofficial]
    def remove_service(id, serviceid, service, options = nil)
      params = {
        'stream' => id,
        'service' => service,
        'serviceid' => serviceid,
      }
      params.update(options) if options
      post(ROOT_URI + '/a/removeservice', params)
    end

    # Refreshes a feed of the authenticated user, a group or an
    # imaginary friend specified by a unique ID. [unofficial]
    def refresh_service(id, serviceid, service, options = nil)
      params = {
        'stream' => id,
        'serviceid' => serviceid,
      }
      params.update(options) if options
      post(ROOT_URI + '/a/crawlservice', params)
    end

    # Adds a feed to the authenticated user, a group or an imaginary
    # friend specified by a unique ID.  Specify 'isstatus' => 'on' to
    # display entries as messages (no link), and 'importcomment' =>
    # 'on' to include entry description as a comment. [unofficial]
    def add_feed(id, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      add_service(id, 'feed', options)
    end

    # Adds a blog feed to the authenticated user, a group or an
    # imaginary friend specified by a unique ID.  Specify 'multiauth'
    # => 'on' when the blog has multiple authors, and 'author' =>
    # '(name)' to limit entries to those written by a specific
    # author. [unofficial]
    def add_blog(id, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      add_service(id, 'blog', options)
    end

    # Adds a Twitter service to the authenticated user, a group or an
    # imaginary friend specified by a unique ID. [unofficial]
    def add_twitter(id, twitter_name)
      add_service(id, 'twitter', 'username' => twitter_name)
    end

    # Edits a feed of the authenticated user, a group or an imaginary
    # friend specified by a unique ID.  Specify 'isstatus' => 'on' to
    # display entries as messages (no link), and 'importcomment' =>
    # 'on' to include entry description as a comment. [unofficial]
    def edit_feed(id, serviceid, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      edit_service(id, 'feed', options)
    end

    # Adds a blog feed to the authenticated user, a group or an
    # imaginary friend specified by a unique ID.  Specify 'multiauth'
    # => 'on' when the blog has multiple authors, and 'author' =>
    # '(name)' to limit entries to those written by a specific
    # author. [unofficial]
    def edit_blog(id, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      edit_service(id, 'blog', options)
    end

    # Edits a Twitter service of the authenticated user, a group or an
    # imaginary friend specified by a unique ID.  Specify 'isstatus'
    # => 'on' to display entries as messages (no link), and
    # 'importcomment' => 'on' to include entry description as a
    # comment. [unofficial]
    def edit_twitter(id, serviceid, twitter_name)
      edit_service(id, serviceid, 'twitter', 'username' => twitter_name)
    end

    # Removes a feed from the authenticated user, a group or an
    # imaginary friend specified by a unique ID.  Specify
    # 'deleteentries' => 'on' to delete entries also. [unofficial]
    def remove_feed(id, serviceid, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      remove_service(id, serviceid, 'feed', options = nil)
    end

    # Removes a blog feed from the authenticated user, a group or an
    # imaginary friend specified by a unique ID.  Specify
    # 'deleteentries' => 'on' to delete entries also. [unofficial]
    def remove_blog(id, serviceid, url, options = nil)
      params = { 'url' => url }
      params.update(options) if options
      remove_service(id, serviceid, 'blog', options = nil)
    end

    # Removes a Twitter service from the authenticated user, a group
    # or an imaginary friend specified by a unique ID.  Specify
    # 'deleteentries' => 'on' to delete entries also. [unofficial]
    def remove_twitter(id, serviceid, twitter_name, options = nil)
      params = { 'username' => twitter_name }
      params.update(options) if options
      remove_service(id, serviceid, 'twitter', options = nil)
    end

    # Changes the picture of the authenticated user, a group or an
    # imaginary friend. [unofficial]
    def change_picture(id, io)
      post(ROOT_URI + '/a/changepicture', 'stream' => id,
        'picture' => io)
    end

    # Unsubscribe from a friend, a group or an imaginary friend
    # specified by a unique ID. [unofficial]
    def unsubscribe_from(id)
      post(ROOT_URI + '/a/unsubscribe', 'stream' => id)
    end

    # Creates an imaginary friend of a given +nickname+ and returns a
    # unique ID string on success.  Like other methods in general, an
    # exception is raised on failure. [unofficial]
    def create_imaginary_friend(nickname)
      post(ROOT_URI + '/a/createimaginary', 'name' => nickname).xpath("//*[@id='serviceseditor']/@streamid").to_s
    end

    # Renames an imaginary friend specified by a unique ID to a given
    # +nickname+. [unofficial]
    def rename_imaginary_friend(id, nickname)
      parser = post(ROOT_URI + '/a/profiledialog', 'stream' => id)['html_parser']
      form = parser.xpath("//form[1]")
      hash = { 'stream' => id }
      form.xpath(".//input").each { |input|
        case input['type'].downcase
        when 'text'
          hash[input['name']] = input['value']
        end
      }
      form.xpath(".//textarea").each { |input|
        hash[input['name']] = input.text
      }
      hash['name'] = nickname
      post(ROOT_URI + '/a/editprofile', hash)
    end
  end
end
