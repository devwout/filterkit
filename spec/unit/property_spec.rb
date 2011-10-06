require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Property do
  it 'raises an error when initialized with a blank attribute' do
    lambda { Property.new(BasicModel, :test, nil, nil) }.should raise_error
  end
  
  it 'raises a TypeError when initialized with an attribute that is not an Arel::Attribute' do
    lambda { Property.new(BasicModel, :test, nil, BasicModel.arel_table) }.should raise_error(TypeError)
  end
  
  it 'accepts a lambda as its attribute and calls it when asked for the attribute' do
    prop = Property.new(BasicModel, :test, nil, lambda { BasicModel.arel_table[:test] })
    prop.attribute.should == BasicModel.arel_table[:test]
  end
  
  it 'delays evaluation of the attribute until it is asked for it' do
    prop = Property.new(BasicModel, :test, nil, lambda { raise 'test' })
    lambda { prop.attribute }.should raise_error
  end
  
  it 'converts its name to a symbol' do
    Property.new(BasicModel, 'test', nil, BasicModel.arel_table[:test]).name.should == :test
  end
end

describe PropertyPath do
  let(:single_pp) { PropertyPath.new(BasicModel, ['test']) }
  let(:multi_pp) { PropertyPath.new(PathModel, ['self', 'self', 'value']) }
  let(:join_pp) { PropertyPath.new(PathModel, ['self', 'basic']) }
  
  it 'raises UnknownProperty when one of the properties in the path does not exist' do
    lambda { PropertyPath.new(PathModel, ['self', 'blabla']) }.should raise_error(UnknownProperty)
  end
  
  describe '#path' do
    it 'returns an array of properties' do
      single_pp.path.length.should == 1
      single_pp.path.first.should be_kind_of(Property)
      multi_pp.path.length.should == 3
      multi_pp.path.each {|p| p.should be_kind_of(Property)}
      join_pp.path.length.should == 2
      join_pp.path.each {|p| p.should be_kind_of(Property)}
    end
  end
  
  describe '#model' do
    it 'returns the base model of the first property' do
      single_pp.model.should == BasicModel
      multi_pp.model.should == PathModel
      join_pp.model.should == PathModel
    end
  end
  
  describe '#name' do
    it 'returns the name of each property, joined with underscores as a symbol' do
      single_pp.name.should == :test
      multi_pp.name.should == :self_self_value
      join_pp.name.should == :self_basic
    end
  end
  
  describe '#type' do
    it 'returns the type of the last property in the path' do
      single_pp.type.should == Arel::Attributes::String
      multi_pp.type.should == Arel::Attributes::String
      join_pp.type.should == BasicModel
    end
  end
  
  describe '#attribute' do
    it 'returns the arel attribute of the last property in the path' do
      single_pp.attribute.should == BasicModel.arel_table[:test]
      multi_pp.attribute.name.should == :value
      join_pp.attribute.name.should == :id
    end
    
    xit 'augments the relation of the attribute with the intermediate joins' do
      single_pp.attribute.relation.should == BasicModel.arel_table
      multi_pp.attribute.relation.should_not == PathModel.arel_table
      join_pp.attribute.relation.should_not == BasicModel.arel_table
      # Problem here is that the attributes that are in the relation do not refer to the relation itself,
      # so attribute.position_of(att) returns nil in row.rb
      join_pp.attribute.relation.take(1).call.map(&:tuple).should ==
        [[1, 'one', 2, 1, # main table
          2, 'two', 3, 1, # self join 1
          1, 'test']]     # join basic
      multi_pp.attribute.relation.where(PathModel.arel_table[:id].eq(1)).call.map(&:tuple).should ==
        [[1, 'one', 2, 1, # main table
          2, 'two', 3, 1, # self join 1
          3, 'three', 4, 1]] # self join 2
    end
    
    xit 'augments the relation of a foreign key attribute with a join to its table iff it is not the last property' do
      PropertyPath.new(PathModel, ['basic_fk']).attribute.relation.should == PathModel.arel_table
      PropertyPath.new(PathModel, ['basic_fk', 'test']).attribute.relation.should == 
        PathModel.arel_table.outer_join(BasicModel.arel_table).
        on(PathModel.arel_table[:basic_id].eq(BasicModel.arel_table[:id]))
    end
  end
end