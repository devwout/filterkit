require File.join(File.dirname(__FILE__), '..', 'spec_helper')
require File.join(File.dirname(__FILE__), 'model')

describe 'ActiveRecord::Base.filter' do
  before(:all) do
    ActiveRecord::Base.establish_connection(
      :adapter => 'mysql',
      :username => 'root',
      :encoding => 'utf8',
      :database => 'filterkit_integration'
    )
    @people = [['George', 'Bush'], ['Barack', 'Obama'], ['Bill', 'Clinton'], ['John', 'Kennedy']].
      map do |first, last|
        Person.find_or_create_by_first_name_and_last_name first, last
      end
  end
  it 'finds models using the given filter' do
    f = Filter.new(Person, 'predicates' => ['first_name', 'begins_with', 'B'])
    Person.filter(f).should == [@people[1], @people[2]]
  end
  it 'returns an empty array when the filter has no results' do
    f = Filter.new(Person, 'predicates' => ['first_name', 'eq', 'Jack'])
    Person.filter(f).should == []
  end
  it 'can be combined with named scopes' do
    f = Filter.new(Person, 'predicates' => ['first_name', 'begins_with', 'B'])
    Person.filter(f).recent(1).should == [@people[2]]
  end
end