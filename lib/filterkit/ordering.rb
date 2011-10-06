module Filterkit
  class Ordering
    attr_reader :property, :attribute, :ascending
    
    def initialize(property, ascending)
      @property = property
      @attribute = property.attribute
      @ascending = (ascending == true)
    end
    
    # Arel ordering for the attribute.
    def arel
      ascending ? attribute.asc : attribute.desc
    end
  end
end