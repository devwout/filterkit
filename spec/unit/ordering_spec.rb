require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Ordering do
  let(:property) { BasicModel.property_named(:test) }
  
  describe '#arel' do
    it 'returns an Arel::Ascending on the property attribute for ascending ordering' do
      arel = Ordering.new(property, true).arel
      arel.should be_kind_of(Arel::Ascending)
      arel.attribute.should == property.attribute
    end
    
    it 'returns an Arel::Descending on the property attribute for descending ordering' do
      arel = Ordering.new(property, false).arel
      arel.should be_kind_of(Arel::Descending)
      arel.attribute.should == property.attribute
    end
  end
  
  describe '#attribute' do
    it 'returns the property attribute' do
      att = Ordering.new(property, true).attribute
      att.should == property.attribute
      att.should be_kind_of(Arel::Attribute)
    end
  end 
end