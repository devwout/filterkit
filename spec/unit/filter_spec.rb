require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Filter do
  let(:complex_filter_data) { 
    {'predicates' => 
      ['and', 
        ['value', 'begins_with', 't'], 
        ['or', 
          ['self.id', 'greater_than', '2'],
          [['basic', 'value'], 'eq', 'val']]]}
  }
  let(:complex_filter) { Filter.new(PathModel, complex_filter_data) }
  let(:empty_filter) { Filter.new(BasicModel, {}) }
  let(:filter_data) { {'predicates' => ['test', 'eq', 'xxx'], 'order' => [['test', '>'], ['id', '<']] } }
  let(:filter) { Filter.new(BasicModel, filter_data) }
  
  it 'raises UnknownPredicate when initialized with a non-existing predicate name' do
    lambda { Filter.new(BasicModel, 'predicates' => ['test', 'bleh']) }.should raise_error(UnknownPredicate)
  end
  
  describe '#model' do
    it 'returns the model' do
      empty_filter.model.should == BasicModel
      complex_filter.model.should == PathModel
    end
  end
  
  describe '#predicates' do
    it 'returns a single predicate when there is one condition' do
      filter.predicates.should be_kind_of(Predicates::Eq)
      filter.predicates.attribute.should == BasicModel.arel_table[:test]
      filter.predicates.arguments.should == ['xxx']
    end
    it 'returns a combined predicate when and/or conditions are given' do
      andp = complex_filter.predicates
      andp.should be_kind_of(Predicates::And)
      andp.predicates.length.should == 2
      orp = andp.predicates.last
      orp.should be_kind_of(Predicates::Or)
      orp.predicates.length.should == 2
      path1 = orp.predicates.first.property.path
      path1.length.should == 2
      path1.first.name.should == :self
      path1.last.name.should == :id
      path2 = orp.predicates.last.property.path
      path2.length.should == 2
      path2.first.name.should == :basic
      path2.last.name.should == :value
    end
    it 'returns a TruthPredicate when empty' do
      empty_filter.predicates.should == TruthPredicate.instance
    end
  end
  
  describe '#orderings' do
    it 'returns an array of orderings' do
      filter.orderings.length.should == 2
      filter.orderings.first.attribute.should == BasicModel.arel_table[:test]
      filter.orderings.last.attribute.should == BasicModel.arel_table[:id]
      filter.orderings.first.ascending.should be_false
      filter.orderings.last.ascending.should be_true
    end
    it 'returns an empty array when empty or no orderings are specified' do
      empty_filter.orderings.should == []
      complex_filter.orderings.should == []
    end
  end
  
  # Cannot test this properly since grouping is not implemented in the Arel Memory engine
  describe '#arel' do
    it 'returns an arel relation' do
      filter.arel.should be_kind_of(Arel::Relation)
      empty_filter.arel.should be_kind_of(Arel::Relation)
      complex_filter.arel.should be_kind_of(Arel::Relation)
    end
    
    it 'returns an arel relation equivalent to the model arel_table when empty' do
      # empty_filter.arel.call.should == BasicModel.arel_table.call
    end
  end
  
  describe '#&' do
    it 'returns the intersection of two filters, ignoring the ordering of the second filter' do
      i = filter & Filter.new(BasicModel, {'predicates' => ['id', 'eq', nil], 'order' => [['test', '<']]})
      i.as_json['predicates'].should == ['and', ['test', 'eq', 'xxx'], ['id', 'eq', nil]]
      i.as_json['order'].should == [['test', '>'], ['id', '<']]
    end
    
    it 'handles empty filters' do
      i = filter & empty_filter
      i.as_json['predicates'].should == ['and', ['test', 'eq', 'xxx']]
      i.as_json['order'].should == [['test', '>'], ['id', '<']]
    end
    
    it 'raises an error when a filter is given with different model' do
      lambda { filter & complex_filter }.should raise_error(StandardError)
    end
  end
  
  describe '#to_json' do
    it 'returns a json string of the filter data' do
      JSON.parse(filter.to_json).should == filter_data
      JSON.parse(complex_filter.to_json).should == complex_filter_data
    end
    it 'returns an empty json hash when empty' do
      empty_filter.to_json.should == '{}'
    end
  end
end