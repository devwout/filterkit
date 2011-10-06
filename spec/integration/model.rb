ActiveRecord::Base.establish_connection(
  :adapter => 'mysql',
  :username => 'root',
  :encoding => 'utf8',
  :database => 'filterkit_integration'
)

ActiveRecord::Schema.define do
  create_table :companies, :force => true do |t|
    t.string :name
    t.timestamps
  end
  create_table :relationships, :force => true do |t|
    t.belongs_to :company, :person
    t.string :function
    t.timestamps
  end
  create_table :people, :force => true do |t|
    t.string :first_name, :last_name
    t.timestamps
  end
end

class Company < ActiveRecord::Base
  has_many :relationships
  has_many :people, :through => :relationships
  
  property :alias, :string, arel[:name]
end

class Relationship < ActiveRecord::Base
  belongs_to :company
  belongs_to :person
end

class Person < ActiveRecord::Base
  has_many :relationships
  has_many :companies, :through => :relationships
  
  property :function, :string, arel(:relationships)[:function]
  property :company_fk, :company, arel(:relationships)[:company_id]
  
  named_scope :recent, lambda {|n| {:order => 'id desc', :limit => n}}
end