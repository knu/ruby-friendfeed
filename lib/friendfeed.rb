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
  ROOT_URI = URI.parse("https://friendfeed.com/")

  # Client library for FriendFeed API.
  class Client
    attr_reader :nickname

    #
    # Official API
    #

    API_URI = ROOT_URI + "/api/"

    private

    def get_api_agent
      @api_agent ||= WWW::Mechanize.new
    end

    def validate
      call_api('validate')
    end

    def require_api_login
      @nickname or raise 'not logged in'
    end

    public

    # Performs a login with a +nickname+ and +remote key+ and returns
    # self.  This enables call of any official API that requires
    # authentication[6~.  It is not needed to call this method if you
    # have called login(), which internally obtains a remote key and
    # calls this method.  An exception is raised if authentication
    # fails.
    def api_login(nickname, remote_key)
      @nickname = nickname
      @remote_key = remote_key
      @api_agent = get_api_agent()
      @api_agent.auth(@nickname, @remote_key)
      validate

      self
    end

    # Calls an official API specified by a +path+ with optional
    # +get_parameters+ and +post_parameters+, and returns an object
    # parsed from a JSON response.  If +post_parameters+ is given, a
    # POST request is issued.  A GET request is issued otherwise.
    def call_api(path, get_parameters = nil, post_parameters = nil, raw = false)
      api_agent = get_api_agent()

      uri = API_URI + path
      if get_parameters
        uri.query = get_parameters.map { |key, value|
          if array = Array.try_convert(value)
            value = array.join(',')
          end
          URI.encode(key) + "=" + URI.encode(value)
        }.join('&')
      end

      if post_parameters
        body = api_agent.post(uri, post_parameters).body
      else
        body = api_agent.get_file(uri)
      end

      if raw
        body
      else
        JSON.parse(body)
      end
    end

    # Gets profile information of a user of a given +nickname+,
    # defaulted to the authenticated user, in hash.
    def get_profile(nickname = @nickname)
      nickname or require_api_login
      call_api('user/%s/profile' % URI.encode(nickname))
    end

    # Gets an array of profile information of users of given
    # +nicknames+.
    def get_profiles(nicknames)
      call_api('profiles', 'nickname' => nicknames)['profiles']
    end

    # Gets an array of profile information of friends of a user of a
    # given +nickname+ (defaulted to the authenticated user) is
    # subscribing to.
    def get_real_friends(nickname = @nickname)
      nickname or require_api_login
      get_profiles(get_profile(@nickname)['subscriptions'].map { |subscription|
          subscription['nickname']
        })
    end

    # Gets an array of the most recent public entries.
    def get_public_entries()
      call_api('feed/public')['entries']
    end

    # Gets an array of the entries the authenticated user would see on
    # their home page.
    def get_home_entries()
      call_api('feed/home')['entries']
    end

    # Gets an array of the entries for the authenticated user's list
    # of a given +nickname+
    def get_list_entries(nickname)
      call_api('feed/list/%s' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries from a user of a given
    # +nickname+ (defaulted to the authenticated user).
    def get_user_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries from users of given
    # +nicknames+.
    def get_multi_user_entries(nicknames)
      call_api('feed/user', 'nickname' => nicknames)['entries']
    end

    # Gets an array of the most recent entries a user of a given
    # +nickname+ (defaulted to the authenticated user) has commented
    # on.
    def get_user_commented_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/comments' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries a user of a given
    # +nickname+ (defaulted to the authenticated user) has like'd.
    def get_user_liked_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/likes' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries a user of a given
    # +nickname+ (defaulted to the authenticated user) has commented
    # on or like'd.
    def get_user_discussed_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/discussion' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries from friends of a user
    # of a given +nickname+ (defaulted to the authenticated user).
    def get_user_friend_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/friends' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries in a room of a given
    # +nickname+.
    def get_room_entries(nickname)
      call_api('feed/room/%s' % URI.encode(nickname))['entries']
    end

    # Gets an array of the entries the authenticated user would see on
    # their rooms page.
    def get_rooms_entries()
      call_api('feed/rooms')['entries']
    end

    # Gets an entry of a given +entryid+.  An exception is raised when
    # it fails.
    def get_entry(entryid)
      call_api('feed/entry/%s' % URI.encode(entryid))['entries'].first
    end

    # Gets an array of entries of given +entryids+.  An exception is
    # raised when it fails.
    def get_entries(entryids)
      call_api('feed/entry', 'entry_id' => entryids)['entries']
    end

    # Gets an array of entries that match a given +query+.
    def search(query)
      call_api('feed/search', 'q' => query)['entries']
    end

    # Gets an array of entries that link to a given +url+.
    def search_for_url(url, options = nil)
      new_options = { 'url' => url }
      new_options.merge!(options) if options
      call_api('feed/url', new_options)['entries']
    end

    # Gets an array of entries that link to a given +domain+.
    def search_for_domain(url, options = nil)
      new_options = { 'url' => url }
      new_options.merge!(options) if options
      call_api('feed/domain', new_options)['entries']
    end

    # Publishes (shares) a given entry.
    def add_entry(title, options = nil)
      require_api_login
      new_options = { 'title' => title }
      if options
        options.each { |key, value|
          case key = key.to_s
          when 'title', 'link', 'comment', 'room'
            new_options[key] = value
          when 'images'
            value.each_with_index { |value, i|
              if url = String.try_convert(value)
                link = nil
              else
                if array = Array.try_convert(value)
                  value1, value2 = *array
                elsif hash = Hash.try_convert(value)
                  value1, value2 = *hash.values_at('url', 'link')
                else
                  raise TypeError, "Each image must be specified by <image URL>, [<image URL>, <link URL>], or {'url' => <image URL>, 'link' => <link URL>}."
                end
                url = String.try_convert(value1) or
                  raise TypeError, "can't convert #{value1.class} into String"
                link = String.try_convert(value2) or
                  raise TypeError, "can't convert #{value2.class} into String"
              end
              new_options['image%d_url' % i] = url
              new_options['image%d_link' % i] = link if link
            }
          when 'audios'
            value.each_with_index { |value, i|
              if url = String.try_convert(value)
                link = nil
              else
                if array = Array.try_convert(value)
                  value1, value2 = *array
                elsif hash = Hash.try_convert(value)
                  value1, value2 = *hash.values_at('url', 'link')
                else
                  raise TypeError, "Each audio must be specified by <audio URL>, [<audio URL>, <link URL>], or {'url' => <audio URL>, 'link' => <link URL>}."
                end
                url = String.try_convert(value1) or
                  raise TypeError, "can't convert #{value1.class} into String"
                link = String.try_convert(value2) or
                  raise TypeError, "can't convert #{value2.class} into String"
              end
              new_options['audio%d_url' % i] = url
              new_options['audio%d_link' % i] = link if link
            }
          when 'files'
            value.each_with_index { |value, i|
              if file = IO.try_convert(value)
                link = nil
              else
                if array = Array.try_convert(value)
                  value1, value2 = *array
                elsif hash = Hash.try_convert(value)
                  value1, value2 = *hash.values_at('file', 'link')
                else
                  raise TypeError, "Each file must be specified by <file IO>, [<file IO>, <link URL>], or {'file' => <file IO>, 'link' => <link URL>}."
                end
                file = IO.try_convert(value1) or
                  raise TypeError, "can't convert #{value1.class} into IO"
                link = String.try_convert(value2) or
                  raise TypeError, "can't convert #{value2.class} into String"
              end
              new_options['file%d' % i] = file
              new_options['file%d_link' % i] = link if link
            }
          end
        }
      end
      call_api('share', nil, new_options)['entries'].first
    end

    alias publish add_entry
    alias share add_entry

    # Adds a comment to a given entry.
    def add_comment(entryid, body)
      call_api('comment', nil, {
          'entry' => entryid,
          'body' => body,
        })
    end

    # Edits a given comment.
    def edit_comment(entryid, commentid, body)
      call_api('comment', nil, {
          'entry' => entryid,
          'comment' => commentid,
          'body' => body,
        })
    end

    # Deletes a given comment.
    def delete_comment(entryid, commentid)
      call_api('comment/delete', nil, {
          'entry' => entryid,
          'comment' => commentid,
        })
    end

    # Undeletes a given comment that is already deleted.
    def undelete_comment(entryid, commentid)
      call_api('comment/delete', nil, {
          'entry' => entryid,
          'comment' => commentid,
          'undelete' => 'on',
        })
    end

    # Adds a "like" to a given entry.
    def add_like(entryid)
      call_api('like', nil, {
          'entry' => entryid,
        })
    end

    # Deletes an existing "like" from a given entry.
    def delete_like(entryid)
      call_api('like/delete', nil, {
          'entry' => entryid,
        })
    end

    # Deletes an existing entry of a given +entryid+.
    def delete_entry(entryid)
      call_api('entry/delete', nil, {
          'entry' => entryid,
        })
    end

    # Undeletes a given entry that is already deleted.
    def undelete_entry(entryid)
      call_api('entry/delete', nil, {
          'entry' => entryid,
          'undelete' => 'on',
        })
    end

    # Hides an existing entry of a given +entryid+.
    def hide_entry(entryid)
      call_api('entry/hide', nil, {
          'entry' => entryid,
        })
    end

    # Unhides a given entry that is already hidden.
    def unhide_entry(entryid)
      call_api('entry/hide', nil, {
          'entry' => entryid,
          'unhide' => 'on',
        })
    end

    # Gets a picture of a user of a given +nickname+ (defaulted to the
    # authenticated user) in blob.  Size can be 'small' (default),
    # 'medium' or 'large',
    def get_picture(nickname = @nickname, size = 'small')
      call_api('/%s/picture' % URI.escape(nickname), { 'size' => size }, nil, true)
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

    # Gets an array of profile information of the authenticated user's
    # imaginary friends, in a format similar to
    # get_real_friends(). [unofficial]
    def get_imaginary_friends
      agent = get_login_agent()

      page = agent.get(IMAGINARY_URI)
      page.parser.xpath("//div[@class='name']//a[@class='l_person']").map { |person_a|
        get_imaginary_friend(person_a['uid'])
      }
    end

    # Gets profile information of one of the authenticated user's
    # imaginary friends, in a format similar to
    # get_profile(). [unofficial]
    def get_imaginary_friend(id)
      agent = get_login_agent()

      profile_uri = IMAGINARY_URI + ("/users/%s" % URI.encode(id))
      profile_page = agent.get(profile_uri)
      parser = profile_page.parser
      {
        'id' => id,
        'nickname' => parser.xpath("//h1/a/text()").to_s,
        'profileUrl' => profile_uri.to_s,
        'services' => parser.xpath("//div[@class='servicefilter']//a[@class='l_filterservice']").map { |service_a|
          servicename = service_a['servicename']
          serviceid = if servicename == "internal"
                        nil
                      else
                        service_a['serviceid'] ||
                          begin
                            service_uri = profile_uri + ("?service=%s" % URI.encode(servicename))
                            page = agent.get(service_uri)
                            page.parser.xpath("//a[@class='l_refreshfeed']/@serviceid").to_s
                          end
                      end
          {
            'serviceid' => serviceid,
            'name' => servicename,
            'profileUrl' => (profile_uri + service_a['href']).to_s
          }
        },
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

class Array
  def self.try_convert(obj)
    return obj if obj.instance_of?(self)
    return nil if !obj.respond_to?(:to_ary)
    nobj = obj.to_ary 
    return nobj if nobj.instance_of?(self)
    raise TypeError, format("can't convert %s to %s (%s#to_ary gives %s)", obj.class, self.class, obj.class, nobj.class)
  end unless self.respond_to?(:try_convert)
end

class Hash
  def self.try_convert(obj)
    return obj if obj.instance_of?(self)
    return nil if !obj.respond_to?(:to_hash)
    nobj = obj.to_hash 
    return nobj if nobj.instance_of?(self)
    raise TypeError, format("can't convert %s to %s (%s#to_hash gives %s)", obj.class, self.class, obj.class, nobj.class)
  end unless self.respond_to?(:try_convert)
end

class IO
  def self.try_convert(obj)
    return obj if obj.is_a?(self)
    return nil if !obj.respond_to?(:to_io)
    nobj = obj.to_io 
    return nobj if nobj.instance_of?(self)
    raise TypeError, format("can't convert %s to %s (%s#to_io gives %s)", obj.class, self.class, obj.class, nobj.class)
  end unless self.respond_to?(:try_convert)
end

class String
  def self.try_convert(obj)
    return obj if obj.instance_of?(self)
    return nil if !obj.respond_to?(:to_str)
    nobj = obj.to_str 
    return nobj if nobj.instance_of?(self)
    raise TypeError, format("can't convert %s to %s (%s#to_str gives %s)", obj.class, self.class, obj.class, nobj.class)
  end unless self.respond_to?(:try_convert)
end
