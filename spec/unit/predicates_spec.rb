require File.join(File.dirname(__FILE__), '..', 'spec_helper')

# Patch the arel memory engine to deal with sql LIKE string specifiers.
class Arel::Predicates::Match
  def eval(row)
    regex = operand2.eval(row)
    if regex.is_a? String
      regex = Regexp.new(
        Regexp.escape(regex).
        gsub(/(^|[^\\])_/, '\1.').
        gsub(/(^|[^\\])%/, '\1.*').
        gsub(/\\\\([%_])/, '\1'))
    end
    operand1.eval(row) =~ regex
  end
end
# Patch the arel compound predicate to avoid infinite recursion.
class Arel::Predicates::CompoundPredicate
  def eval(row)
    Kernel.eval "operand1.eval(row) #{operator} operand2.eval(row)", binding
  end
end
# Patch arel Time attribute, add typecast.
class Arel::Attributes::Time
  def type_cast(value)
    ActiveRecord::ConnectionAdapters::Column.string_to_time(value)
  end
end

describe Predicates do
  let(:strings) do
    Arel::Array.new(
      [['quick'], ['brown'], ['fox'], [nil], ['']],
      [[:string, Arel::Attributes::String]]
    )
  end
  
  # Return the result rows of table as an array of arrays
  # after applying a new predicate of +predicate_class+
  # to the first attribute of the table, with +args+.
  def results(table, predicate_class, *args)
    predicate = predicate_class.new(first_property(table), args)
    table.where(predicate.arel).call.map(&:tuple)
  end
  
  # Create a property with the first attribute of the given table.
  def first_property(table)
    attribute = table.attributes.first
    Property.new(Object, attribute.name, attribute.name, attribute)
  end
  
  describe Predicates::Eq do
    it 'accepts strings equal to the given string' do
      results(strings, Predicates::Eq, 'quick').should == [['quick']]
    end
    it 'accepts nil values when nil is given' do
      results(strings, Predicates::Eq, nil).should == [[nil]]
    end
  end
  
  describe Predicates::In do
    it 'accepts string that are included in the array' do
      results(strings, Predicates::In, ['quick', 'brown']).should == [['quick'], ['brown']]
    end
    
    it 'converts a non-array argument to an array' do
      results(strings, Predicates::In, 'fox').should == [['fox']]
    end
  end
  
  describe Predicates::Empty do
    it 'accepts empty strings and nil values' do
      results(strings, Predicates::Empty).should == [[nil], ['']]
    end
  end
  
  describe Predicates::BeginsWith do
    it 'accepts strings starting with the given characters' do
      results(strings, Predicates::BeginsWith, 'br').should == [['brown']]
    end
    it 'accepts strings equal to the given characters' do
      results(strings, Predicates::BeginsWith, 'quick').should == [['quick']]
    end
  end
  
  describe Predicates::EndsWith do
    it 'accepts strings ending with the given characters' do
      results(strings, Predicates::EndsWith, 'ox').should == [['fox']]
    end
    it 'accepts strings equal to the given characters' do
      results(strings, Predicates::EndsWith, 'quick').should == [['quick']]
    end
  end
  
  describe Predicates::Contains do
    it 'accepts strings containing the given characters' do
      results(strings, Predicates::Contains, 'ow').should == [['brown']]
    end
    it 'accepts strings equal to the given characters' do
      results(strings, Predicates::Contains, 'quick').should == [['quick']]
    end
    it 'accepts strings starting with the given characters' do
      results(strings, Predicates::Contains, 'qui').should == [['quick']]
    end
    it 'accepts strings ending with the given characters' do
      results(strings, Predicates::Contains, 'own').should == [['brown']]
    end
  end
  
  let(:dates) do
    Arel::Array.new(
      [['2009-01-10'], ['2009-12-31'], ['2010-02-15'], ['2010-03-01'], ['2010-03-14'], ['2010-03-15'], 
       ['2010-03-20'], ['2010-03-21'], ['2010-03-22'], ['2010-03-31'], ['2010-04-01'], ['2010-05-10'],
       ['2010-06-30'], ['2010-07-01']],
      [[:date, Arel::Attributes::Time]]
    )
  end
  
  # Spec Time predicates with CET timezone = UTC+1 (with daylight savings).
  # To make sure the queries take the default time zone into account when filtering.
  # We interpret the arguments to Time predicates as local time.
  # Saved queries may return different results depending on the user's timezone.
  ActiveRecord::Base.default_timezone = :utc
  Time.zone_default = Time.__send__(:get_zone, "Paris")
  
  let(:times) do
    Arel::Array.new(
      [['2010-01-01 12:30'], 
       ['2010-01-31 23:00'],
       ['2010-02-01 02:00'],
       ['2010-02-01 13:30'], 
       ['2010-02-01 21:59'],
       ['2010-02-01 23:00'],
       ['2010-02-06 11:25'],
       ['2010-02-07 22:59'],
       ['2010-02-07 23:00']],
      [[:time, Arel::Attributes::Time]]
    )
  end
  
  describe Predicates::Today do
    it 'accepts dates that are today' do
      Time.stub(:now => Time.zone.parse('2010-03-20 12:00:00'))
      results(dates, Predicates::Today).should == [['2010-03-20']]
    end
    it 'accepts timestamps from today' do
      Time.stub(:now => Time.zone.parse('2010-02-01 12:00:00'))
      results(times, Predicates::Today).should == [
        ['2010-01-31 23:00'], ['2010-02-01 02:00'], ['2010-02-01 13:30'], ['2010-02-01 21:59']]
    end
  end
  
  describe Predicates::ThisWeek do
    it 'accepts dates from monday to sunday this week' do
      Time.stub(:now => Time.zone.parse('2010-03-20 12:00:00'))
      results(dates, Predicates::ThisWeek).should == [['2010-03-15'], ['2010-03-20'], ['2010-03-21']]
    end
    it 'accepts timestamps from this week' do
      Time.stub(:now => Time.zone.parse('2010-02-01 12:00:00'))
      results(times, Predicates::ThisWeek).should == [
        ['2010-01-31 23:00'], ['2010-02-01 02:00'], ['2010-02-01 13:30'], ['2010-02-01 21:59'],
        ['2010-02-01 23:00'], ['2010-02-06 11:25'], ['2010-02-07 22:59']]
    end
  end
  
  describe Predicates::ThisMonth do
    it 'accepts dates from the 1st to the last day of the current month' do
      Time.stub(:now => Time.zone.parse('2010-03-20 12:00:00'))
      results(dates, Predicates::ThisMonth).should == [
        ['2010-03-01'], ['2010-03-14'], ['2010-03-15'], 
        ['2010-03-20'], ['2010-03-21'], ['2010-03-22'], ['2010-03-31']]
    end
  end
  
  describe Predicates::ThisQuarter do
    it 'accepts dates from the current civil quarter (01-03, 04-06, 07-09, 10-12)' do
      Time.stub(:now => Time.zone.parse('2010-04-22 12:00:00'))
      results(dates, Predicates::ThisQuarter).should == [['2010-04-01'], ['2010-05-10'], ['2010-06-30']]
    end
  end
  
  describe Predicates::ThisYear do
    it 'accepts dates from the current civil year' do
      Time.stub(:now => Time.zone.parse('2009-12-30 12:00:00'))
      results(dates, Predicates::ThisYear).should == [["2009-01-10"], ["2009-12-31"]]
    end
  end
  
  describe Predicates::Between do
    it 'accepts dates between two given dates, inclusive' do
      results(dates, Predicates::Between, Date.civil(2010,03,20), Date.civil(2010,03,22)).should == [
        ['2010-03-20'], ['2010-03-21'], ['2010-03-22']]
    end
    it 'accepts timestamps between two given times' do
      results(times, Predicates::Between, 
        Time.zone.parse('2010-02-01 00:00'), 
        Time.zone.parse('2010-02-01 14:29')).
        should == [['2010-01-31 23:00'], ['2010-02-01 02:00']]
    end
  end
  
  describe Predicates::Before do
    it 'accepts dates that are at least one day earlier than the given date' do
      results(dates, Predicates::Before, Date.civil(2009,12,31)).should == [['2009-01-10']]
    end
    it 'accepts timestamps that are before the given timestamp' do
      results(times, Predicates::Before, Time.zone.parse('2010-02-01 00:00')).should == [['2010-01-01 12:30']]
    end
  end
  
  describe Predicates::After do
    it 'accepts dates that are at least one day after the given date' do
      results(dates, Predicates::After, Date.civil(2010,06,30)).should == [['2010-07-01']]
    end
    # TODO: maybe relook this and make it >= ? Isn't that more useful?
    it 'accepts timestamps that are after the given timestamp' do
      results(times, Predicates::After, Time.zone.parse('2010-02-07 23:59')).should == [['2010-02-07 23:00']]
    end
  end
  
  let(:numbers) do
    Arel::Array.new(
      [[1], [2], [3.3], [4.4], [5.5], [6], [7]],
      [[:float, Arel::Attributes::Float]]
    )
  end
  
  describe Predicates::GreaterThan do
    it 'accepts numbers greater than the given number' do
      results(numbers, Predicates::GreaterThan, 5).should == [[5.5], [6], [7]]
      results(numbers, Predicates::GreaterThan, 5.5).should == [[6], [7]]
    end
  end
  
  describe Predicates::LessThan do
    it 'accepts numbers less than the given number' do
      results(numbers, Predicates::LessThan, 4.4).should == [[1], [2], [3.3]]
    end
  end
  
  describe Predicates::Or do
    it 'accepts values accepted by one of its predicates' do
      numbers.where(Predicates::Or.new([
        Predicates::LessThan.new(first_property(numbers), [0]),
        Predicates::GreaterThan.new(first_property(numbers), [6])
      ]).arel).call.map(&:tuple).should == [[7]]
    end
    it 'accepts all values when no predicates are given' do
      numbers.where(Predicates::Or.new([]).arel).call.length.should == 7
    end
    it 'allows predicates with sql literals' do
      predicate = OpenStruct.new(:arel => Arel::SqlLiteral.new('1 = 1'))
      Predicates::Or.new([predicate, predicate]).arel.to_sql.should == "(1 = 1 OR 1 = 1)"
    end
  end
  
  describe Predicates::And do
    it 'accepts values accepted by all of its predicates' do
      numbers.where(Predicates::And.new([
        Predicates::LessThan.new(first_property(numbers), [6]),
        Predicates::GreaterThan.new(first_property(numbers), [4])
      ]).arel).call.map(&:tuple).should == [[4.4], [5.5]]
    end
    it 'accepts all values when no predicates are given' do
      numbers.where(Predicates::And.new([]).arel).call.length.should == 7
    end
    it 'allows predicates with sql literals' do
      predicate = OpenStruct.new(:arel => Arel::SqlLiteral.new('1 = 1'))
      Predicates::And.new([predicate, predicate]).arel.to_sql.should == "(1 = 1 AND 1 = 1)"
    end
  end
end