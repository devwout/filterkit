require File.join(File.dirname(__FILE__), '..', 'spec_helper')
require File.join(File.dirname(__FILE__), 'model')

describe Filter do
  
  def filter(model, predicates, order=nil)
    ary = Filter.new(model, {'predicates' => predicates, 'order' => order}).
      arel.project(model.arel_table[:id]).call.array.flatten.map(&:to_i).uniq
    order ? ary : ary.sort
  end
  
  describe 'on table properties' do
    before(:all) do
      ActiveRecord::Base.establish_connection(
        :adapter => 'mysql',
        :username => 'root',
        :encoding => 'utf8',
        :database => 'filterkit_integration'
      )
      Company.delete_all
      @ids = %w(MicroTech Microsoft softworks Greenpeace).map do |name|
        Company.find_or_create_by_name(name).id
      end
    end
    it 'finds rows with a single predicate' do
      filter(Company, ['name', 'eq', 'Greenpeace']).should == [@ids[3]]
    end
    it 'finds all rows when no predicates are given' do
      filter(Company, nil).should == @ids
    end
    it 'finds rows with boolean predicates' do
      filter(Company, ['or', ['name', 'contains', 'soft'], ['name', 'begins_with', 'micro']]).
        should == [@ids[0], @ids[1], @ids[2]]
    end
    it 'finds rows with nested boolean predicates' do
      filter(Company, 
        ['or', ['name', 'contains', 'green'], 
               ['and', ['name', 'begins_with', 'Micro'], ['name', 'contains', 'soft']]]).
        should == [@ids[1], @ids[3]]
    end
    it 'sorts rows ascending when specified' do
      filter(Company, nil, [['name', '<']]).should == [@ids[3], @ids[1], @ids[0], @ids[2]]
    end
    it 'sorts rows descending when specified' do
      filter(Company, nil, [['name', '>']]).should == [@ids[2], @ids[0], @ids[1], @ids[3]]
    end
    it 'finds rows with a single predicate (aliased property)' do
      filter(Company, ['alias', 'eq', 'Greenpeace']).should == [@ids[3]]
    end
  end
  
  def join_data
    Person.delete_all
    Company.delete_all
    Relationship.delete_all
    @jobs = Person.find_or_create_by_last_name('Jobs')
    @donn = Person.find_or_create_by_last_name('Donn')
    @ball = Person.find_or_create_by_last_name('Ballmer')
    @apple = Company.find_or_create_by_name('apple')
    @micro = Company.find_or_create_by_name('micro')
    @pixar = Company.find_or_create_by_name('pixar')
    Relationship.create(:person => @jobs, :function => 'CEO', :company => @apple)
    Relationship.create(:person => @jobs, :function => 'CEO', :company => @pixar)
    Relationship.create(:person => @ball, :function => 'CEO', :company => @micro)
    Relationship.create(:person => @ball, :function => 'CTO', :company => @micro)
    Relationship.create(:person => @donn, :function => 'CFO', :company => @pixar)
    Relationship.create(:person => @donn, :function => 'CTO', :company => @apple)
  end
  
  describe 'on custom joined properties' do
    before(:all) do
      join_data
    end
    it 'finds rows with a single predicate' do
      filter(Person, ['function', 'eq', 'CEO']).should == [@jobs.id, @ball.id]
    end
    it 'finds rows with boolean predicates' do
      filter(Person, ['and', ['function', 'eq', 'CEO'], ['last_name', 'eq', 'jobs']]).should == [@jobs.id]
    end
    it 'finds rows with OR on the joined property' do
      filter(Person, ['or', ['function', 'eq', 'CTO'], ['function', 'eq', 'CFO']]).should == [@donn.id, @ball.id]
    end
    it 'does not find rows with AND on the joined property' do
      filter(Person, ['and', ['function', 'eq', 'CTO'], ['function', 'eq', 'CEO']]).should == []
    end
    it 'sorts rows on the joined property when specified' do
      filter(Person, [], [['function', '>']]).should == [@donn.id, @ball.id, @jobs.id]
    end
  end
  
  describe 'on property paths' do
    before(:all) do
      join_data
    end
    it 'finds rows with a single predicate' do
      filter(Company, ['people.last_name', 'eq', 'Jobs']).should == [@apple.id, @pixar.id]
    end
    it 'finds rows with boolean predicates' do
      filter(Company, 
        ['and', 
          ['people.last_name', 'eq', 'Jobs'], 
          ['name', 'not_eq', 'apple']]).should == [@pixar.id]
    end
    it 'finds rows with OR on the same property path' do
      filter(Company,
        ['or',
          ['people.last_name', 'eq', 'jobs'],
          ['people.last_name', 'eq', 'ballmer']]).should == [@apple.id, @micro.id, @pixar.id]
    end
    it 'does not find rows with AND on the same property path' do
      filter(Company,
        ['and',
          ['people.last_name', 'eq', 'jobs'],
          ['people.last_name', 'eq', 'donn']]).should == []
    end
    it 'finds rows with AND on different property paths of the same related row' do
      filter(Company,
        ['and',
          ['relationships.person.last_name', 'eq', 'donn'],
          ['relationships.function', 'eq', 'CTO']]).should == [@apple.id]
    end
    it 'finds rows with a single predicate on a recursive join' do
      filter(Company, ['people.companies.name', 'eq', 'Apple']).should == [@apple.id, @pixar.id]
    end
    it 'automatically joins in relations whose foreign key we use' do
      filter(Person, ['company_fk.name', 'eq', 'Apple']).should == [@jobs.id, @donn.id]
    end
  end
end