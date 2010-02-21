# -*- mode: ruby -*-
#--
# friendfeed/object.rb - represents FriendFeed API result objects
#++
# Copyright (c) 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'ostruct'
require 'time'
require 'uri'

module FriendFeed
  module V2
    class Object < OpenStruct
      def initialize(hash, client = nil)
        klass = self.class
        new_hash = {}
        booleans = []
        hash.each_pair { |key, value|
          key, value = klass.normalize_token(key), convert_value(value)
          new_hash[key] = value
          case value
          when true, false
            booleans << key
          end
        }
        super(new_hash)
        parse_as_boolean(*booleans)
        @client = client
      end

      attr_reader :client

      def id
        @table[__method__]
      end

      def convert_value(object)
        case object
        when Hash
          self.class.new(object, @client)
        when Array
          object.map { |element|
            convert_value(element)
          }
        else
          object
        end
      end

      def self.normalize_token(token)
        new_token = token.to_s.tr('-', '_')
        new_token.gsub!(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        new_token.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
        new_token.downcase!
        new_token.to_sym
      end

      attr_accessor :data_type

      def data_type_name
        return nil if !@data_type
        @data_type_name ||= @data_type.to_s.sub!(/.*::/, '')
      end

      def inspect
        string = super
        if @data_type
          string.sub!(/ /) { '[' << data_type_name << '] ' }
        end
        string
      end

      def error?
        !error_code.nil?
      end

      def parse_as_boolean(*keys)
        def_method = class << self; method(:define_method); end
        keys.each { |key|
          next if !respond_to?(key)
          pred = "#{key}?".to_sym
          next if respond_to?(pred)
          value = !!table[key]
          def_method[pred, proc { value }]
        }
        self
      end

      def parse_as_enum(*keys)
        def_method = class << self; method(:define_method); end
        keys.each { |key|
          next if !respond_to?(key)
          pred = "#{sym}?".to_sym
          next if respond_to?(pred)
          value = table[key]
          sym = self.class.normalize_token(value)
          def_method[pred, proc { true }]
        }
        self
      end

      def parse_as_time(*keys)
        keys.each { |key|
          if value = table[key]
            table[key] = Time.parse(value)
          end
        }
        self
      end

      def parse_as_uri(*keys)
        keys.each { |key|
          if value = table[key]
            table[key] = URI.parse(value)
          end
        }
        self
      end

      def parse_as(mod, *keys)
        keys.each { |key|
          if value = table[key]
            value.extend(mod)
          end
        }
        self
      end

      def parse_as_array_of(mod, *keys)
        keys.each { |key|
          if array = table[key]
            array.each { |element|
              element.extend(mod)
            }
          end
        }
        self
      end

      module DataType
        def self.included(mod)
          def mod.create(hash, client = nil)
            Object.new(hash, client).extend(self).tap { |object|
              object.data_type = self
            }
          end
        end
      end

      # Represents a feed object.  The following fields are defined:
      #
      #   id, name, description, type, private, commands, entries;
      #   subscriptions, subscribers, admins, feeds, services;
      #   realtime
      module Feed
        include DataType

        def self.extended(object)
          object.parse_as_enum(:type)
          object.parse_as_boolean(:private)
          object.parse_as_array_of(Entry, :entries)
          object.parse_as_array_of(Feed, :subscriptions, :subscribers, :admins, :feeds)
          object.parse_as_array_of(Service, :services)
        end
      end

      # Represents an entry object.  The following fields are defined:
      #
      #     url, date, body, from, to, comments, likes, thumbnails, files,
      #     via, geo, commands; short_id, short_url; fof, fof_html; address_html;
      #     created, updated
      module Entry
        include DataType

        def self.extended(object)
          object.parse_as_uri(:url, :short_url)
          object.parse_as_time(:date)
          object.parse_as(Feed, :from)
          object.parse_as_array_of(Feed, :to)
          object.parse_as_array_of(Comment, :comments)
          object.parse_as_array_of(Like, :likes)
          object.parse_as_array_of(Thumbnail, :thumbnails)
          object.parse_as_array_of(File, :files)
          object.parse_as(Via, :via)
          object.parse_as(FoF, :fof)
          object.parse_as_boolean(:created, :updated)
        end
      end

      # Represents a comment object.  The following fields are defined:
      #
      #     id, date, body, from, via, commands; placeholder, num
      #     created, updated
      module Comment
        include DataType

        def self.extended(object)
          object.parse_as_time(:date)
          object.parse_as(Feed, :from)
          object.parse_as(Via, :via)
          object.parse_as_boolean(:placeholder, :created, :updated)
        end
      end

      # Represents a thumbnail object.  The following fields are defined:
      #
      #     url, link, width, height, player
      module Thumbnail
        include DataType

        def self.extended(object)
          object.parse_as_uri(:url, :link)
        end
      end

      # Represents a file object.  The following fields are defined:
      #
      #     url, type, name, icon, size
      module File
        include DataType

        def self.extended(object)
          object.parse_as_uri(:url, :icon)
        end
      end

      # Represents a like object.  The following fields are defined:
      #
      #     date, from
      #     created, updated
      module Like
        include DataType


        def self.extended(object)
          object.parse_as_time(:date)
          object.parse_as(Feed, :from)
          object.parse_as_boolean(:created, :updated)
        end
      end

      # Represents a via object.  The following fields are defined:
      #
      #     name, url
      module Via
        include DataType

        def self.extended(object)
          object.parse_as_uri(:url)
        end
      end

      # Represents an FoF object.  The following fields are defined:
      #
      #     type, from
      module FoF
        include DataType

        def self.extended(object)
          object.parse_as_enum(:type)
          object.parse_as(:Feed, :from)
        end
      end

      # Represents a service object.  The following fields are defined:
      #
      #     id, name, url, icon, profile, username
      module Service
        include DataType

        def self.extended(object)
          object.parse_as_enum(:id)
          object.parse_as_uri(:url, :icon, :profile)
        end
      end

      # Represents a feed list object.  The following fields are defined:
      #
      #     main, lists, groups, searches, sections
      module FeedList
        include DataType

        def self.extended(object)
          object.parse_as_array_of(Feed, :main, :lists, :groups, :searches)
          object.parse_as_array_of(Section, :sections)
        end
      end

      # Represents a section object.  The following fields are defined:
      #
      #     name, id, feeds
      module Section
        include DataType

        def self.extended(object)
          object.parse_as_enum(:id)
          object.parse_as_array_of(Feed, :feeds)
        end
      end
    end
  end
end
