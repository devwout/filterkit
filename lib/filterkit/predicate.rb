module Filterkit
  class Predicate
    def self.filters(type, *args)
      @type_map[type] = args
    end
    
    def self.arguments_for_type(type)
      if Predicate == self
        nil
      else
        @type_map[type] || superclass.arguments_for_type(type)
      end
    end
  
    def self.predicate_name
      name.sub(/^Filterkit::Predicates::/, '').underscore
    end
    
    # Predicate class for which +predicate_name+ is +name+.
    def self.named(name)
      @@predicate_map[name]
    end
    
    def self.inherited(subclass)
      (@@predicate_map ||= {})[subclass.predicate_name] = subclass
      subclass.instance_variable_set(:@type_map, TypeMap.new)
    end
  
    attr_reader :property, :attribute
  
    def initialize(property, arguments)
      raise TypeError unless arguments.is_a? Array
      @property = property
      @attribute = property.attribute
      @raw_arguments = arguments
    end
    
    def arguments
      # TODO: check arguments & perform casting when initializing the predicate? 
      @arguments ||= begin
        types = self.class.arguments_for_type(property.type)
        raise "Unsupported property type #{property.type} for #{self.class.name}" unless types
        unless types.length == @raw_arguments.length
          raise "Wrong number of attributes for property type #{property.type}"
        end
        [@raw_arguments, types].transpose.map do |raw_arg, type|
          type.from_filter_json(raw_arg)
        end
      end
    end
  
    # Return an arel predicate for filtering.
    def filter(*args)
      raise NotImplementedError, 'Subclass should implement.'
    end
    
    def arel
      filter(*arguments)
    end
    
    protected
    
    # Get the arel table for +name+. Makes joining extra tables less verbose.
    def table(name)
      Arel::Table.new(name, :engine => attribute.relation.engine)
    end
    
    # Get the arel table for +name+, scoped by the property so it does not collide with other joins.
    def scoped_table(name)
      table(name).as("#{property.name}_#{name}")
    end
  end
  
  # Dummy predicate that will return an arel predicate which always evaluates to true.
  class TruthPredicate
    include Singleton
    
    def arel
      @truth ||= Arel::Predicates::Equality.new(1,1)
    end
  end
end