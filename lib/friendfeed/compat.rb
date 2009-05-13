#!/usr/bin/env ruby
#--
# friendfeed/compat.rb - defines compatibility methods for older Ruby
#++
# Copyright (c) 2009 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

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

class Array
  def self.try_convert(obj)
    return obj if obj.instance_of?(self)
    return nil if !obj.respond_to?(:to_ary)
    nobj = obj.to_ary 
    return nobj if nobj.instance_of?(self)
    raise TypeError, format("can't convert %s to %s (%s#to_ary gives %s)", obj.class, self.class, obj.class, nobj.class)
  end unless self.respond_to?(:try_convert)
end
