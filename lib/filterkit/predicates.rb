module Filterkit
  module Predicates
    class Or
      attr_reader :predicates
      
      def initialize(predicates)
        @predicates = predicates
        @predicates << TruthPredicate.instance if predicates.empty?
      end
      
      def arel
        first, *other = predicates
        other.inject(first.arel) {|compound, predicate| Arel::Predicates::Or.new(compound, predicate.arel)}
      end
    end
    
    class And < Or
      def arel
        first, *other = predicates
        other.inject(first.arel) {|compound, predicate| Arel::Predicates::And.new(compound, predicate.arel)}
      end
    end
    
    class Empty < Predicate
      filters :string
      def filter
        attribute.eq(nil).or(attribute.eq(''))
      end
    end

    class Eq < Predicate
      def self.arguments_for_type(type)
        [Types.lookup(type)]
      end
      
      def filter(value)
        attribute.eq(value)
      end
    end
    
    class In < Predicate
      def self.arguments_for_type(type)
        [Array]
      end
      
      def filter(values)
        attribute.in(values)
      end
    end
    
    # NotEq does not work on joined in associations! 
    # (there may be a company with 2 phonenumbers, "123" and "234", 
    #  - it will be returned as a result when asking phonenumber noteq "234")
    class NotEq < Eq
      def filter(value)
        attribute.not_eq(value)
      end
    end

    class BeginsWith < Predicate
      filters :string, :string
      def filter(string)
        attribute.matches("#{string.gsub('%', '\%')}%")
      end
    end

    class Contains < Predicate
      filters :string, :string
      def filter(string)
        attribute.matches("%#{string.gsub('%', '\%')}%")
      end
    end

    class EndsWith < Predicate
      filters :string, :string
      def filter(string)
        attribute.matches("%#{string.gsub('%', '\%')}")
      end
    end

    # Boolean filters. Could be better: as predicates on the object itself?
    # Instead of Project active is_on => Project is_active | is_not_active
    class IsOn < Predicate
      filters :boolean
      def filter
        attribute.eq(true)
      end
    end

    class IsOff < Predicate
      filters :boolean
      def filter
        attribute.eq(false).or(attribute.eq(nil))
      end
    end
    ##
    
    class Recent < Predicate
      filters :date, :period
      filters :time, :period
      def filter(period)
        attribute.in(period.start..period.stop)
      end
    end

    class CurrentPeriod < Predicate
      filters :date
      filters :time
      def filter
        attribute.in(start..stop)
      end
    end

    class Today < CurrentPeriod
      def start ; Time.zone.now.beginning_of_day ; end
      def stop ; Time.zone.now.end_of_day ; end
    end

    class ThisWeek < CurrentPeriod
      def start ; Time.zone.now.beginning_of_week ; end
      def stop ; Time.zone.now.end_of_week ; end
    end

    class ThisMonth < CurrentPeriod
      def start ; Time.zone.now.beginning_of_month ; end
      def stop ; Time.zone.now.end_of_month ; end
    end

    class ThisQuarter < CurrentPeriod
      def start ; Time.zone.now.beginning_of_quarter ; end
      def stop ; Time.zone.now.end_of_quarter ; end
    end

    class ThisYear < CurrentPeriod
      def start ; Time.zone.now.beginning_of_year ; end
      def stop ; Time.zone.now.end_of_year ; end
    end

    # TODO: fiscal quarter, fiscal year
    # TODO: period (month/year or year)

    class Between < Predicate
      filters :date, :date, :date
      filters :time, :time, :time # Semantics: user needs to specify time, defaults to 00:00.
      filters :integer, :integer, :integer
      filters :decimal, :decimal, :decimal
      def filter(start, stop)
        attribute.gteq(start).and(attribute.lteq(stop))
      end
    end

    class Before < Predicate
      filters :date, :date
      filters :time, :time
      def filter(date)
        attribute.lt(date)
      end
    end

    class After < Predicate
      filters :date, :date
      filters :time, :time
      def filter(date)
        attribute.gt(date)
      end
    end

    class LessThan < Predicate
      filters :integer, :integer
      filters :decimal, :decimal
      filters :float, :float
      def filter(n)
        attribute.lt(n)
      end
    end

    class GreaterThan < Predicate
      filters :integer, :integer
      filters :decimal, :decimal
      filters :float, :float
      def filter(n)
        attribute.gt(n)
      end
    end
  end
end