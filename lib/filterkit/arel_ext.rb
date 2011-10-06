# Utility methods to make manipulating arel trees easier.
module Arel
  module Predicates
    class Predicate
      # Array of all attributes used in the predicate.
      def attributes
        []
      end
    end
    class Polyadic
      def attributes
        [] # TODO
      end
    end
    class Binary
      def attributes
        [operand1, operand2].select {|op| op.is_a? Arel::Attribute}
      end
    end
    class Unary
      def attributes
        operand.is_a?(Arel::Attribute) ? [operand] : []
      end
    end
    class CompoundPredicate
      def attributes
        operand1.attributes.concat(operand2.attributes)
      end
    end
  end
  
  class SqlLiteral
    def attributes
      []
    end
  end
  
  class Array
    # Consistent hashing for array relations, arel does not provide it.
    def hash
      array.hash
    end
    
    def eql?(other)
      self == other
    end
  end
  
  module Relation
    def replace(relation, new_relation)
      self == relation ? new_relation : self
    end
    def uniq_joins(*args)
      self
    end
    def prefix(*args)
      self
    end
    # To be compatible with Arel::Table
    def table_alias
      false
    end
  end
  
  class Table
    def prefix(str, relations=[])
      result = table_alias ? self : as("#{str}_#{name}")
      relations << result
      result
    end
    
    # Hackfix arel: cache columns for aliases, so we don't need to query
    # the columns over and over again.
    def as(table_alias)
      t = Table.new(name, options.merge(:as => table_alias))
      t.instance_variable_set(:@columns, columns)
      t
    end
  end
  
  class Join
    def replace(relation, new_relation)
      self.class.new(
        relation1.replace(relation, new_relation), 
        relation2.replace(relation, new_relation), 
        *predicates)
    end
    
    # Rewrite the join tree so there is only one join per table alias.
    # Eliminates duplicate joins.
    # Currently, it only examines the left side of the join tree and assumes
    # the right side is always a table. To improve.
    def uniq_joins(joins_before = {}, joins_after = {}) # relation => predicates
      relation1 = self.relation1.uniq_joins(joins_before, joins_after.merge(relation2 => predicates))
      if predicates_before = joins_before[relation2]
        if predicates_before == predicates
          relation1
        else
          raise 'Ambigous join'
        end
      elsif predicates_after = joins_after[relation2]
        joins_before[relation2] = predicates unless relation2.join?
        predicates_after == predicates ? self : relation1
      else
        self.class.new(relation1, relation2, *predicates)
      end
    end
    
    def prefix(str, relations)
      r1 = relation1.join? ? relation1.prefix(str, relations) : relation1
      self.class.new(r1, relation2.prefix(str, relations), *predicates.map {|p| p.prefix(str, relations)})
    end
  end
  
  class Where
    def replace(old_relation, new_relation)
      self.class.new(relation.replace(old_relation, new_relation), *predicates)
    end
    def uniq_joins(*args)
      self.class.new(relation.uniq_joins(*args), *predicates)
    end
  end
  
  module Predicates
    class Polyadic
      # TODO
    end
    class Unary
      def prefix(*args)
        self.class.new(operand.prefix(*args))
      end
    end
    class Binary
      def prefix(*args)
        self.class.new(operand1.prefix(*args), operand2.prefix(*args))
      end
    end
  end
  
  class Attribute
    def prefix(str, relations=[])
      if original_relation.table_alias
        self
      else
        r = relations.reverse.detect {|r| r.name == original_relation.name} || original_relation
        r[name] # TODO: what about an existing alias on the attribute?
      end
    end
  end
  
  class ::Object
    def prefix(*args)
      self
    end
  end
  
  class Arel::Attributes::Boolean
    alias :type_cast_original :type_cast
    def type_cast(value)
      case value
      when "0" then false
      when "1" then true
      else type_cast_original(value)
      end
    end
  end
  
  class Arel::Attributes::Date < Arel::Attribute
  end
  
  module Sql
    module Attributes
      class << self
        alias :for_original :for
        
        def for(column)
          case column.type
          when :date then Date
          else for_original(column)
          end
        end
      end
      
      class Date < Arel::Attributes::Date
        include Attributes
      end
    end
  end
end