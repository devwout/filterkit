# Simple pretty print implementation for Arel.
# Allows to inspect an arel tree without clutter.

require 'pp'

class Class
  # Attributes declared by an arel class.
  # These are the interesting parts to print on composite objects.
  def arel_attributes
    instance_variable_get(:@attributes) || superclass.arel_attributes
  end
end

module Arel
  class Table
    def pretty_print(q)
      q.text(table_alias ? "#{table_alias}/#{name}" : name.to_s)
    end
  end
  class Attribute
    def pretty_print(q)
      table_name = original_relation.table_alias || original_relation.name
      table_name += "(#{original_relation.object_id})" if original_relation.is_a?(Alias)
      attr_name = self.alias ? "#{self.alias}/#{name}" : name.to_s
      q.text("#{table_name}.#{attr_name}")
    end
  end
  class Value
    def pretty_print(q)
      q.pp value
    end
  end
  class Nil
    def pretty_print(q)
      q.text "Nil"
    end
  end
  def self.pp_recursive(q, obj)
    q.group(1, obj.class.name.demodulize + '(', ' )') do
      obj.class.arel_attributes.map {|attribute| obj.send(attribute)}.flatten.each do |value|
        q.breakable
        q.pp value
      end
    end
  end
  module Relation
    def pretty_print(q)
      Arel.pp_recursive(q, self)
    end
  end
  module Predicates
    class Predicate
      def pretty_print(q)
        Arel.pp_recursive(q, self)
      end
    end
  end
  class Ordering
    def pretty_print(q)
      Arel.pp_recursive(q, self)
    end
  end
end