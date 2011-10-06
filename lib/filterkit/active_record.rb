require 'activerecord'

class ActiveRecord::Base
  class << self
    def filter(filter)
      ids = filter.arel.project(arel_table[primary_key]).call.array.flatten
      scoped(:conditions => { primary_key => ids })
    end
    
    def define_properties(&block)
      (@filter_property_definitions ||= []) << block
    end
    
    def property(name, type, attribute=arel_table[name])
      properties[name.to_sym] = Filterkit::Property.new(self, name, type, attribute)
    end
    
    def properties
      @filter_properties ||= {}
    end
    
    # +name+ :: Symbol
    def property_named(name)
      @filter_property_definitions.shift.call until @filter_property_definitions.blank?
      properties[name] || default_property_named(name)
    end
    
    def arel_table
      @arel_table ||= Arel::Table.new(table_name, :engine => arel_engine)
    end

    def arel_engine
      # Not correct when working with multiple connections.
      @@arel_engine ||= Arel::Sql::Engine.new(ActiveRecord::Base)
    end
    
    # Return an arel relation that joins the specified relations based on ActiveRecord reflection.
    def arel(*path)
      klass = self
      path.inject(arel_table) do |relation, segment|
        reflection = klass.reflect_on_association(segment.to_sym)
        raise Filterkit::UnknownProperty, "#{klass.name} has no association named #{segment}." unless reflection
        if reflection.through_reflection
          reflections = [reflection.source_reflection]
          while reflection = reflection.through_reflection
            reflections.unshift(reflection)
          end
        else
          reflections = [reflection]
        end
        reflections.inject(relation) do |relation, reflection|
          type_constraint = nil
          case reflection.macro
          when :belongs_to
            raise 'cannot join polymorphic belongs_to associations' if reflection.options[:polymorphic]
            local_key = klass.arel_table[reflection.primary_key_name]
            other_key = reflection.klass.arel_table[reflection.options[:primary_key] || reflection.klass.primary_key]
          when :has_and_belongs_to_many
            join_table = Arel::Table.new(reflection.options[:join_table], :engine => arel_engine)
            relation = relation.outer_join(join_table).on(
              klass.arel_table[klass.primary_key].eq(join_table[reflection.primary_key_name]))
            local_key = join_table[reflection.association_foreign_key]
            other_key = reflection.klass.arel_table[reflection.klass.primary_key]
          else
            local_key = klass.arel_table[reflection.options[:primary_key] || klass.primary_key]
            if poly_prefix = reflection.options[:as]
              other_key = reflection.klass.arel_table["#{poly_prefix}_id"]
              type_constraint = reflection.klass.arel_table["#{poly_prefix}_type"].eq(klass.base_class.name)
            else
              other_key = reflection.klass.arel_table[reflection.primary_key_name]
            end
          end
          klass = reflection.klass
          join_condition = local_key.eq(other_key)
          join_condition = join_condition.and(type_constraint) if type_constraint
          relation.outer_join(reflection.klass.arel_table).on(join_condition)
        end
      end
    end
    
    def from_filter_json(value)
      value # value is primary key. we don't cast to the object itself because it requires an extra DB lookup.
    end
    
    private
    
    def default_property_named(name)
      if attribute = arel_table[name]
        Filterkit::Property.new(self, name, attribute.class.name.demodulize.underscore, attribute)
      elsif association = reflect_on_association(name)
        klass = association.klass
        Filterkit::Property.new(self, name, klass, arel(name)[klass.arel_table[klass.primary_key]])
      end
    end
  end
end