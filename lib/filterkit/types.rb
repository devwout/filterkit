module Filterkit
  module Types
    # TODO: spec!
    def self.lookup(name)
      return name unless name.is_a?(String) or name.is_a?(Symbol)
      name = name.to_s.camelize
      if Arel::Attributes.const_defined?(name)
        Arel::Attributes.const_get(name)
      else
        # TODO: allow for nested constants. const_get only looks up a single constant without namespaces...
        Object.const_get(name)
      end
    end
    
    class Enum
      # Return an array of [value, description] pairs with the available values.
      def self.values
        []
      end
      
      def self.from_filter_json(value)
        value
      end
    end
    
    class Period < Enum
      #values :day, :week, :month, :quarter, :year
      
      def self.from_filter_json(value)
        
      end
      
      # start, stop
    end
  end
end

class Date
  def self.from_filter_json(value)
    if value === String
      # TODO: make sure it works with dates...
      Date.parse(value)
    else
      value
    end
  end
end

class Array
  def self.from_filter_json(value)
    if Array === value
      value
    else
      [value]
    end
  end
end

class Fixnum
  # Required for decimal casting to work on Fixnums.
  def to_d
    to_f.to_d
  end
end

module Arel
  class Attribute
    def self.from_filter_json(value)
      new(nil, nil).type_cast(value)
    end
    def self.value(casted)
      casted
    end
  end
  module Attributes
    class Time
      def self.from_filter_json(value)
        ActiveRecord::ConnectionAdapters::Column.string_to_time(value)
      end
    end
    class Date
      def self.from_filter_json(value)
        ActiveRecord::ConnectionAdapters::Column.string_to_date(value)
      end
    end
  end
end