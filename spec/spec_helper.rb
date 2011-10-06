require 'rubygems'
gem 'activerecord', '2.3.5'
gem 'arel-compat'
require 'activerecord'
require 'arel'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'filterkit'

include Filterkit

# Minimal model for use with the filter library.
class BasicModel
  def self.arel_table
    Arel::Array.new([[1, 'test']], [[:id, Arel::Attributes::Integer], [:test, Arel::Attributes::String]])
  end
  
  def self.primary_key ; :id ; end
  
  def self.property_named(name)
    if name == :id
      Filterkit::Property.new(self, name, :integer, arel_table[:id])
    else
      Filterkit::Property.new(self, name, :string, arel_table[:test])
    end
  end
end

# Model with relations to self and BasicModel, for testing join paths.
class PathModel
  def self.arel_table
    Arel::Array.new(
      [[1, 'one', 2, 1],
       [2, 'two', 3, 1],
       [3, 'three', 4, 1],
       [4, 'four', nil, nil]],
      [[:id, Arel::Attributes::Integer], 
       [:value, Arel::Attributes::String],
       [:self_id, Arel::Attributes::Integer],
       [:basic_id, Arel::Attributes::Integer]]
    )
  end
  
  def self.primary_key ; :id ; end
  
  def self.property_named(name)
    selfalias = arel_table.alias
    basictable = BasicModel.arel_table
    case name
    when :id then Filterkit::Property.new(self, name, :integer, arel_table[name])
    when :value then Filterkit::Property.new(self, name, :string, arel_table[name])
    when :self  then Filterkit::Property.new(self, name, self, arel_table.join(selfalias).on(arel_table[:self_id].eq(selfalias[:id]))[selfalias[:id]])
    when :basic then Filterkit::Property.new(self, name, BasicModel, arel_table.join(basictable).on(arel_table[:basic_id].eq(basictable[:id]))[basictable[:id]])
    when :basic_fk then Filterkit::Property.new(self, name, BasicModel, arel_table[:basic_id])
    end
  end
end