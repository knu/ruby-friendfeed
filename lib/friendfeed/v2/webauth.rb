# -*- mode: ruby -*-
#--
# friendfeed/v2/webauth.rb - represents a web-authenticated HTTP agent
#++
# Copyright (c) 2009, 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'friendfeed/v2/basicauth'
require 'json'
require 'mechanize'
require 'uri'

module FriendFeed
  module V2
    # Represents a web-authenticated HTTP agent for calling unofficial APIs.
    class WebAuth < BasicAuth
      ROOT_URI  = URI.parse("https://friendfeed.com/")
      LOGIN_URI = ROOT_URI + "/account/login?v=2"

      # Creates a web-authenticated HTTP agent, with given +username+
      # and +password+.  A FriendFeed V2 client object initialized
      # with this object can call unofficial APIs in addition to
      # official APIs.
      def initialize(username, password, options = nil)
        @web_agent = Mechanize.new

        page = @web_agent.get(LOGIN_URI)

        login_form = page.forms.find { |form|
          LOGIN_URI + form.action == LOGIN_URI
        } or raise 'Cannot locate a login form'

        login_form.set_fields(:email => nickname, :password => password)

        page = login_form.submit

        login_form = page.forms.find { |form|
          LOGIN_URI + form.action == LOGIN_URI
        } and raise 'Login failed'

        page = @web_agent.get(ROOT_URI + "/account/api")
        remotekey = page.parser.xpath("(//table[@class='remotekey']//td[@class='value'])[2]/text()").to_s

        super(nickname, remotekey, options)
      end

      attr_reader :web_agent

      # Posts a request to an internal API of FriendFeed and returns
      # either a parser object for an HTML response or an object parsed
      # from a JSON response).  [unofficial]
      def web_post(uri, query = {})
        agent = web_agent()

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
    end
  end
end
