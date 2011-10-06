module Filterkit
  # Raised when initializing a filter with an unknown predicate.
  class UnknownPredicate < StandardError ; end
  # Raised when initializing a filter with an unknown property.
  class UnknownProperty < StandardError ; end
  
  class Filter
    attr_reader :model, :predicates, :orderings
    
    # model :: should have methods: name, primary_key, arel_table and property_named(name).
    # data :: hash with raw filter data, like
    #   {'predicates' => ['and', ['name', 'eq', 'test'], ['price', 'less_than', 100]], 
    #    'order' => [['price', '<'], ['quality', '>']] }
    def initialize(model, data)
      @data = data
      @model = model
      @predicates = build_predicates(data['predicates'])
      @orderings = build_orderings(data['order'])
    end
    
    # Return the intersection of this filter and another.
    def &(filter)
      if model == filter.model
        Filter.new(model, {
          'predicates' => ['and', as_json['predicates'], filter.as_json['predicates']].compact, 
          'order' => as_json['order']
        })
      else
        raise 'cannot intersect filters with two different models'
      end
    end
    
    # Arel relation representing this filter.
    def arel
      @arel ||= begin
        root = model.arel_table
        arel_predicates = predicates.arel
        arel_relations = (arel_predicates.attributes + orderings.map {|o| o.attribute}).map {|a| a.relation}.uniq
        arel_relations.delete(root)
        arel = arel_relations.inject(root) do |combined, relation|
          relation.replace(root, combined) # Use externalize and move where clauses to the join conditions??
        end.uniq_joins
        arel = arel.order(*orderings.map {|o| o.arel})
        arel.where(arel_predicates)
      end
    end
    
    def as_json(options=nil)
      @data
    end
    
    private
    
    def build_predicates(array)
      return TruthPredicate.instance if array.blank?
      case array.first
      when 'or' then Predicates::Or.new(array[1..-1].map {|block| build_predicates(block) })
      when 'and' then Predicates::And.new(array[1..-1].map {|block| build_predicates(block) })
      else build_predicate(*array)
      end
    end
    
    def build_predicate(property_path, predicate_name, *args)
      predicate = Predicate.named(predicate_name) or raise UnknownPredicate, predicate_name
      predicate.new(property_for_path(property_path), args)
    end
    
    def build_orderings(array)
      return [] unless array
      array.map do |property_path, order_spec|
        Ordering.new(property_for_path(property_path), order_spec != '>')
      end
    end
    
    def property_for_path(path)
      path = path.split('.') if path.is_a? String
      PropertyPath.new(model, path)
    end
  end
end