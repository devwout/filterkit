require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe ActiveRecord::Base do
  
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => 'testdb.sqlite')
    ActiveRecord::Schema.define do
      create_table :widgets, :force => true do |t|
        t.string :name
        t.integer :language
        t.integer :creator_id
        t.date :first_contact
      end
      create_table :users, :force => true do |t|
        t.string :login
      end
    end
    
    class Language ; end
    
    class Widget < ActiveRecord::Base
      belongs_to :creator, :class_name => "User"
      define_properties do
        property :alias, String, arel_table[:name]
      end
      define_properties do
        property :language, Language
      end
    end
    
    class User < ActiveRecord::Base ; end
  end
  
  describe '.property_named' do
    it 'returns a property based on the database definition when not declared otherwise' do
      property = Widget.property_named(:name)
      property.should_not be_nil
      property.name.should == :name
      property.model.should == Widget
      property.type.should == Arel::Attributes::String
      property.attribute.should be_kind_of(Arel::Attribute)
    end
    it 'returns a date property when a date is detected in the database schema' do
      property = Widget.property_named(:first_contact)
      property.should_not be_nil
      property.name.should == :first_contact
      property.model.should == Widget
      property.type.should == Arel::Attributes::Date
      property.attribute.should be_kind_of(Arel::Attribute)
    end
    it 'returns nil when no property exists with the given name' do
      Widget.property_named(:bogus).should be_nil
    end
    it 'returns a property when declared in the model' do
      property = Widget.property_named(:alias)
      property.should_not be_nil
      property.name.should == :alias
      property.model.should == Widget
      property.type.should == String
      property.attribute.should == Widget.arel_table[:name]
    end
    it 'favors declared properties over database definitions' do
      property = Widget.property_named(:language)
      property.should_not be_nil
      property.name.should == :language
      property.type.should == Language
      property.attribute.should == Widget.arel_table[:language]
    end
    it 'returns a property to the id of the related model when given a relation name' do
      property = Widget.property_named(:creator)
      property.should_not be_nil
      property.name.should == :creator
      property.type.should == User
      # !! when replacing .outer_join with .join, it also works. Arel comparison is wrong!
      property.attribute.should == 
        Widget.arel_table.outer_join(User.arel_table).
        on(Widget.arel_table[:creator_id].eq(User.arel_table[:id]))[User.arel_table[:id]]
    end
  end
  
  describe '.arel' do
    it 'raises an error when an association is not found' do
      lambda { Widget.arel(:nonexistent) }.should raise_error(Filterkit::UnknownProperty)
    end
  end
    
end