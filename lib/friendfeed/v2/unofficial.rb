# -*- mode: ruby -*-
#--
# friendfeed/unofficial.rb - provides access to FriendFeed unofficial API's
#++
# Copyright (c) 2009, 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'json'
require 'mechanize'
require 'uri'
require 'friendfeed/v2'
require 'friendfeed/v1'

module FriendFeed
  module V2
    # Unofficial API implementation.
    module UnofficialAPI 
      protected

      # Gets a list of services of a user or a room of a given
      # +nickname+, defaulted to the authenticated user.
      def get_service(nickname = nil)
        nickname ||= @nickname
        agent = get_web_agent()

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
        when 'text', 'hidden'
          hash[input['name']] = input['value']
        when 'radio', 'checkbox'
          if input['checked']
            value = input['value'] || 'on'
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
    def edit_group(id, options)
      params = get_group(id)
      params.update(options)
      post(EDIT_GROUP_URI, params)
    end

    # Gets information of a service specified by a unique
    # ID. [unofficial]
    def get_service(id, serviceid)
      parser = post(ROOT_URI + '/a/servicedialog',
        'serviceid' => serviceid, 'stream' => id)['html_parser']
      form = parser.at("//form[1]")
      hash = { 'stream' => id }
      form.xpath(".//input").each { |input|
        case input['type'].downcase
        when 'text', 'hidden'
          hash[input['name']] = input['value']
        when 'radio', 'checkbox'
          if input['checked']
            value = input['value'] || 'on'
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
    def edit_service(id, serviceid, options = nil)
      params = get_service(id, serviceid)
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
    def add_twitter(id, twitter_name, options = nil)
      params = { 'username' => twitter_name }
      params.update(options) if options
      add_service(id, 'twitter', params)
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
