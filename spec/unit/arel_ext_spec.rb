require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe 'arel_ext' do
  let(:rel1) { Arel::Array.new([[1]], [[:id, Arel::Attributes::Integer]]) }
  let(:rel2) { Arel::Array.new([[2]], [[:id, Arel::Attributes::Integer]]) }
  let(:rel3) { Arel::Array.new([[3]], [[:id, Arel::Attributes::Integer]]) }
  
  describe Arel::Join do
    let(:join) { rel1.join(rel2).on }
  
    describe '#replace' do
      it 'replaces the first relation when given' do
        replaced = join.replace(rel1, rel3)
        replaced.should_not == join
        replaced.relation1.should == rel3
        replaced.relation2.should == rel2
      end
      it 'replaces the second relation when given' do
        replaced = join.replace(rel2, rel3)
        replaced.should_not == join
        replaced.relation1.should == rel1
        replaced.relation2.should == rel3
      end
      it 'replaces nothing when a different relation is given' do
        replaced = join.replace(rel3, rel2)
        replaced.should == join
        replaced.relation1.should == rel1
        replaced.relation2.should == rel2
      end
      it 'is recursive' do
        replaced = join.join(rel3).on.replace(rel1, rel2)
        replaced.relation1.relation1.should == rel2
        replaced.relation1.relation2.should == rel2
        replaced.relation2.should == rel3
      end
    end
    
    describe '#uniq_joins' do
      it 'removes duplicate joins on the right when they have no predicates' do
        j2 = join.join(rel2.dup).on
        uniq = j2.uniq_joins
        uniq.should == join
      end
      it 'removes duplicate joins on the right when they have the same predicates' do
        join = rel1.join(rel2).on(rel1[:id].eq(rel2[:id]))
        j2 = join.join(rel2).on(rel1[:id].eq(rel2[:id]))
        j2.uniq_joins.should == join
      end
      it 'raises an error when it includes two joins on the same table alias with different predicates' do
        join = rel1.
          join(rel2).on(rel1[:id].eq(rel2[:id]), rel1[:id].eq(1)).
          join(rel3).on(rel1[:id].eq(rel3[:id])).
          join(rel2).on(rel2[:id].eq(rel3[:id]))
        lambda { join.uniq_joins }.should raise_error(StandardError)
      end
      it 'returns the join itself when all joins are on unique relations' do
        join.uniq_joins.should == join
      end
      it 'returns the join itself when there are duplicate but aliased relations' do
        j2 = join.join(rel2.alias).on
        j2.uniq_joins.should == j2
      end
    end
  end

  describe Arel::Where do
    let(:where) { rel1.where(rel1[:id].eq(1)) }
    
    describe '#replace' do
      it 'replaces its relation, keeping the predicates' do
        replaced = where.replace(rel1, rel2)
        replaced.should_not == where
        replaced.relation.should == rel2
        replaced.predicates.length.should == 1
      end
      it 'replaces nothing when a different relation is given' do
        where.replace(rel2, rel3).should == where
      end
      it 'is recursive' do
        replaced = where.where(rel1[:id].eq(2)).replace(rel1, rel2)
        replaced.relation.relation.should == rel2
      end
    end
    
    describe '#uniq_joins' do
      it 'removes duplicate joins from its relation' do
        rel1.join(rel2).on.join(rel2).on.where(rel1[:id].eq(1)).uniq_joins.should ==
          rel1.join(rel2).on.where(rel1[:id].eq(1))
      end
      it 'returns the same when no joins are in its relation' do
        where.uniq_joins.should == where
      end
    end
  end
  
  # TODO: implement & spec From, Group, Having, Lock, Order, Project, Skip, Take (#replace and #uniq_joins)
  
  describe Arel::Array do
    describe '#replace' do
      it 'returns the replacement when equal to the first relation' do
        rel1.replace(rel1, rel2).should == rel2
      end
      it 'returns self when not equal to the first relation' do
        rel1.replace(rel2, rel3).should == rel1
      end
    end
    
    describe '#uniq_joins' do
      it 'returns itself' do
        rel1.uniq_joins.should == rel1
      end
    end
    
    describe '#hash' do
      it 'returns the same for duplicates' do
        rel1.hash.should == rel1.dup.hash
      end
    end
    
    describe '#eql?' do
      it 'returns true for duplicates' do
        rel1.eql?(rel1.dup).should be_true
      end
      it 'returns false for different arrays' do
        rel1.eql?(rel2).should be_false
      end
    end
  end
  
  describe Arel::Table do
    let(:dummy_engine) { 
      engine = Struct.new(:connection).new(nil) 
      def engine.columns(*args) ; [] ; end
      engine
    }
    let(:table1) { Arel::Table.new(:table1, :engine => dummy_engine) }
    let(:table2) { Arel::Table.new(:table2, :engine => dummy_engine) }
    
    describe '#replace' do
      it 'returns the replacement when equal to the first relation' do
        table1.replace(table1, table2).should == table2
      end
      it 'returns self when not equal to the first relation' do
        table1.replace(table2, table2).should == table1
      end
      it 'returns self when the first relation has a different alias' do
        table1.replace(table1.as(:alias), table2).should == table1
      end
    end
    
    describe '#uniq_joins' do
      it 'returns itself' do
        table1.uniq_joins.should == table1
      end
    end
  end
  
  describe Arel::Predicates::Binary do
    let(:classes) { 
      [Arel::Predicates::Equality, Arel::Predicates::Inequality, 
       Arel::Predicates::GreaterThanOrEqualTo, Arel::Predicates::GreaterThan, 
       Arel::Predicates::LessThanOrEqualTo, Arel::Predicates::LessThan, 
       Arel::Predicates::Match, Arel::Predicates::NotMatch, 
       Arel::Predicates::In, Arel::Predicates::NotIn]
    }
    describe '#attributes' do
      it 'returns an array with both operands when they are attributes' do
        classes.each do |klass|
          klass.new(rel1[:id], rel2[:id]).attributes.should == [rel1[:id], rel2[:id]]
        end
      end
      it 'returns an array with the first operand when it is an attribute' do
        classes.each do |klass|
          klass.new(rel1[:id], 1).attributes.should == [rel1[:id]]
        end
      end
      it 'returns an empty array when no operand is an attribute' do
        classes.each do |klass|
          klass.new(1, 1).attributes.should == []
        end
      end
    end
  end
  
  describe Arel::Predicates::Unary do
    let(:classes) { [Arel::Predicates::Not] }
    describe '#atributes' do
      it 'returns an array with the operand when it is an attribute' do
        classes.each {|klass| klass.new(rel1[:id]).attributes.should == [rel1[:id]] }
      end
      it 'returns an empty array when the operand is not an attribute' do
        classes.each {|klass| klass.new(true).attributes.should == [] }
      end
    end
  end
  
  describe Arel::Predicates::CompoundPredicate do
    let(:classes) { [Arel::Predicates::And, Arel::Predicates::Or] }
    
    describe '#attributes' do
      it 'returns the attributes of both operands' do
        classes.each do |klass|
          klass.new(
            Arel::Predicates::Inequality.new(rel1[:id], rel2[:id]),
            Arel::Predicates::Equality.new(rel3[:id], 1)
          ).attributes.should == [rel1[:id], rel2[:id], rel3[:id]]
        end
      end
      it 'returns an empty array when both operands have no attributes' do
        classes.each do |klass|
          klass.new(
            Arel::Predicates::Equality.new(1, 1), 
            Arel::Predicates::Equality.new("test", "x")
          ).attributes.should == []
        end
      end
      it 'is recursive' do
        classes.each do |klass|
          klass.new(
            Arel::Predicates::Or.new(
              Arel::Predicates::Equality.new(rel1[:id], 1),
              Arel::Predicates::Equality.new(rel1[:id], rel2[:id])),
            Arel::Predicates::Inequality.new(rel3[:id], 2)
          ).attributes.should == [rel1[:id], rel1[:id], rel2[:id], rel3[:id]]
        end
      end
    end
  end
end