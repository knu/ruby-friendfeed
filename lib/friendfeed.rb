# -*- mode: ruby -*-
#--
# friendfeed.rb - provides access to FriendFeed API's
#++
# Copyright (c) 2009, 2010 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

module FriendFeed
  autoload :Client, 'friendfeed/v1'
  autoload :V2, 'friendfeed/v2'
end
