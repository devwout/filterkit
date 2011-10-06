require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Predicate do
  
  class RspecTest < Predicate
    filters :string, :integer, :integer
    filters :boolean
  end
  class RspecTestInherit < RspecTest
    filters :float, :float
  end
  module Rspec
    class RspecTestCustom < Predicate ; end
  end
  class Filterkit::Predicates::RspecTest2 < Predicate ; end
      
  describe '.named' do
    it 'looks up inherited predicates by name' do
      Predicate.named('rspec_test').should == RspecTest
    end
    
    it 'looks up deeply inherited predicates by name' do
      Predicate.named('rspec_test_inherit').should == RspecTestInherit
    end
    
    it 'looks up inherited predicates in different modules' do
      Predicate.named('rspec/rspec_test_custom').should == Rspec::RspecTestCustom
    end
    
    it 'uses Filterkit::Predicates as the default namespace for lookup' do
      Predicate.named('rspec_test2').should == Filterkit::Predicates::RspecTest2
    end
    
    it 'returns nil when no predicate was found with the given name' do
      Predicate.named('clown').should be_nil
    end
  end
  
  describe '.arguments_for_type' do
    it 'returns an array of the argument types declared for the given type' do
      RspecTest.arguments_for_type(:string).should == [Arel::Attributes::Integer, Arel::Attributes::Integer]
      RspecTest.arguments_for_type(:boolean).should == []
      RspecTestInherit.arguments_for_type(:float).should == [Arel::Attributes::Float]
    end
    
    it 'returns nil when the predicate cannot handle the given type' do
      RspecTest.arguments_for_type(:float).should == nil
    end
    
    it 'walks up the inheritance tree to get the argument types of the parent' do
      RspecTestInherit.arguments_for_type(:string).should == [Arel::Attributes::Integer, Arel::Attributes::Integer]
      RspecTest.filters(:decimal, :string)
      RspecTestInherit.arguments_for_type(:decimal).should == [Arel::Attributes::String]
    end
    
    it 'freezes the array of arguments so the caller cannot mess with them' do
      args = RspecTest.arguments_for_type(:string)
      args.should be_frozen
      lambda { args.push(:test) }.should raise_error(TypeError)
    end
  end
  
  let(:property) { BasicModel.property_named(:test) }
  
  describe '#attribute' do
    it 'returns the property attribute' do
      predicate = RspecTest.new(property, [])
      predicate.attribute.should == property.attribute
      predicate.attribute.should be_kind_of(Arel::Attribute)
    end
  end
  
  describe '#arguments' do
    it 'returns the arguments typecasted' do
      RspecTest.new(property, ['1','2']).arguments.should == [1,2]
    end
  end
  
  describe '#arel' do
    it 'raises an error when the filter method is not overridden' do
      lambda { RspecTest.new(property, [1,1]).arel }.should raise_error(NotImplementedError)
    end
    
    it 'returns an arel predicate' do
      Predicates::Eq.new(property, ['test']).arel.should be_kind_of(Arel::Predicates::Predicate)
    end
  end
end

describe TruthPredicate do
  it 'is a singleton' do
    TruthPredicate.instance.object_id.should == TruthPredicate.instance.object_id
    lambda { TruthPredicate.new }.should raise_error(NoMethodError)
  end
  
  it 'returns an arel predicate that evaluates to true' do
    Arel::Array.new([[1, 'test']], []).where(TruthPredicate.instance.arel).call.length.should == 1
  end
end