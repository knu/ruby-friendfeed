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
require 'friendfeed/compat'

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

    def call_subscription_api(path)
      require_api_login

      uri = API_URI + path

      agent = WWW::Mechanize.new
      agent.auth('username', @nickname)
      JSON.parse(agent.post(uri, { 'apikey' => @remote_key }).body)
    end

    public

    attr_reader :nickname, :remote_key

    # Performs a login with a +nickname+ and +remote key+ and returns
    # self.  This enables call of any official API that requires
    # authentication.  It is not needed to call this method if you
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

    # Edits profile information of the authenticated user.  The fields
    # "name" and "picture" are supported.
    def edit_profile(hash)
      nickname or require_api_login
      call_api('user/%s/profile' % URI.encode(nickname), nil, hash)
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
      nicknames = []
      get_profile(@nickname)['subscriptions'].each { |subscription|
        if nickname = subscription['nickname']
          nicknames << nickname
        end
      }
      get_profiles(nicknames)
    end

    # Gets an array of profile information of the authenticated user's
    # imaginary friends.
    def get_imaginary_friends
      nickname or require_api_login
      profiles = []
      get_profile(@nickname)['subscriptions'].each { |subscription|
        if subscription['nickname'].nil?
          profiles << get_profile(subscription['id'])
        end
      }
      profiles
    end

    # Gets profile information of one of the authenticated user's
    # imaginary friends.
    def get_imaginary_friend(id)
      get_profile(id)
    end

    # Gets an array of the most recent public entries.
    def get_public_entries()
      call_api('feed/public')['entries']
    end

    # Gets an array of the entries the authenticated user would see on
    # their home page.
    def get_home_entries()
      require_api_login
      call_api('feed/home')['entries']
    end

    # Gets an array of the entries for the authenticated user's list
    # of a given +nickname+
    def get_list_entries(nickname)
      require_api_login
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
      require_api_login
      call_api('comment', nil, {
          'entry' => entryid,
          'body' => body,
        })
    end

    # Edits a given comment.
    def edit_comment(entryid, commentid, body)
      require_api_login
      call_api('comment', nil, {
          'entry' => entryid,
          'comment' => commentid,
          'body' => body,
        })
    end

    # Deletes a given comment.
    def delete_comment(entryid, commentid)
      require_api_login
      call_api('comment/delete', nil, {
          'entry' => entryid,
          'comment' => commentid,
        })
    end

    # Undeletes a given comment that is already deleted.
    def undelete_comment(entryid, commentid)
      require_api_login
      call_api('comment/delete', nil, {
          'entry' => entryid,
          'comment' => commentid,
          'undelete' => 'on',
        })
    end

    # Adds a "like" to a given entry.
    def add_like(entryid)
      require_api_login
      call_api('like', nil, {
          'entry' => entryid,
        })
    end

    # Deletes an existing "like" from a given entry.
    def delete_like(entryid)
      require_api_login
      call_api('like/delete', nil, {
          'entry' => entryid,
        })
    end

    # Deletes an existing entry of a given +entryid+.
    def delete_entry(entryid)
      require_api_login
      call_api('entry/delete', nil, {
          'entry' => entryid,
        })
    end

    # Undeletes a given entry that is already deleted.
    def undelete_entry(entryid)
      require_api_login
      call_api('entry/delete', nil, {
          'entry' => entryid,
          'undelete' => 'on',
        })
    end

    # Hides an existing entry of a given +entryid+.
    def hide_entry(entryid)
      require_api_login
      call_api('entry/hide', nil, {
          'entry' => entryid,
        })
    end

    # Unhides a given entry that is already hidden.
    def unhide_entry(entryid)
      require_api_login
      call_api('entry/hide', nil, {
          'entry' => entryid,
          'unhide' => 'on',
        })
    end

    # Gets a picture of a user of a given +nickname+ (defaulted to the
    # authenticated user) in blob.  Size can be 'small' (default),
    # 'medium' or 'large',
    def get_picture(nickname = @nickname, size = 'small')
      nickname or require_api_login
      call_api('/%s/picture' % URI.escape(nickname), { 'size' => size }, nil, true)
    end

    # Gets a picture of a room of a given +nickname+ in blob.  Size
    # can be 'small' (default), 'medium' or 'large',
    def get_room_picture(nickname, size = 'small')
      call_api('/rooms/%s/picture' % URI.escape(nickname), { 'size' => size }, nil, true)
    end

    # Gets profile information of a room of a given +nickname+ in
    # hash.
    def get_room_profile(nickname)
      call_api('room/%s/profile' % URI.encode(nickname))
    end

    # Gets profile information of the authenticated user's list of a
    # given +nickname+ in hash.
    def get_list_profile(nickname)
      call_api('list/%s/profile' % URI.encode(nickname))
    end

    # Subscribes to a user of a given +nickname+ and returns a status
    # string.
    def subscribe_to_user(nickname)
      call_subscription_api('user/%s/subscribe' % URI.encode(nickname))['status']
    end

    # Unsubscribes from a user of a given +nickname+ and returns a
    # status string.
    def unsubscribe_from_user(nickname)
      call_subscription_api('user/%s/subscribe?unsubscribe=1' % URI.encode(nickname))['status']
    end

    # Subscribes to a room of a given +nickname+ and returns a status
    # string.
    def subscribe_to_room(nickname)
      call_subscription_api('room/%s/subscribe' % URI.encode(nickname))['status']
    end

    # Unsubscribes from a room of a given +nickname+ and returns a
    # status string.
    def unsubscribe_from_room(nickname)
      call_subscription_api('room/%s/subscribe?unsubscribe=1' % URI.encode(nickname))['status']
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
