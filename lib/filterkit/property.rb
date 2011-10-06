module Filterkit
  class Property
    attr_reader :model, :name
    
    def initialize(model, name, type, attribute)
      @model = model
      @name = name.to_sym
      @delayed_type = type
      if attribute.is_a? Proc
        @delayed_attribute = attribute
      else
        @attribute = attribute
        @attribute or raise "Unknown attribute #{name} on #{model.name}"
        raise TypeError, "attribute should be an Arel::Attribute" unless @attribute.is_a?(Arel::Attribute)
      end
    end
    
    def type
      @type ||= Types.lookup(@delayed_type)
    end
    
    def attribute
      @attribute ||= @delayed_attribute.call
    end
    
    def ==(other)
      Property === other and
      name == other.name and
      type == other.type and
      model == other.model and
      attribute == other.attribute
    end
  end
  
  class PropertyPath
    attr_reader :model, :name, :path
    
    # path :: Array of property names, like ['people', 'creator', 'login'].
    def initialize(model, path)
      @model = model
      @name = path.join('_').to_sym
      @path = path.map do |segment|
        property = model.property_named(segment.to_sym) or raise UnknownProperty, "#{model}.#{segment}"
        model = property.type
        property
      end
    end
    
    def type
      path.last.type
    end
    
    def attribute
      @attribute ||= begin
        prefix = path.map {|p| p.name if p.attribute.relation.join?}.compact.join('_')
        if prefix.blank?
          path.last.attribute
        else
          rel = relation
          path.last.attribute.prefix(prefix, @table_map).bind(rel)
        end
      end
    end
    
    private
    
    def relation
      cur_path = []
      path.inject(model.arel_table) do |arel, property|
        relation = property.attribute.relation
        cur_path << property.name if relation.join?
        unless property.equal? path.last
          type = property.type
          primary_key = type.arel_table[type.primary_key]
          unless relation[primary_key]
            relation = relation.outer_join(type.arel_table).on(property.attribute.eq(primary_key))
          end
        end
        relation = relation.replace(property.model.arel_table, arel)
        @table_map = []
        relation = relation.prefix(cur_path.join('_'), @table_map) unless cur_path.empty?
        relation
      end
    end
  end
end