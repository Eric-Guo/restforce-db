require "active_record"

ActiveRecord::Base.logger = Logger.new("/dev/null")
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:",
)

ActiveRecord::Schema.define do

  create_table :custom_objects do |table|
    table.column :name,            :string
    table.column :example,         :string
    table.column :user_id,         :integer
    table.column :salesforce_id,   :string
    table.column :synchronized_at, :datetime
    table.timestamps null: false
  end

  add_index :custom_objects, :salesforce_id

  create_table :users do |table|
    table.column :email,           :string
    table.column :salesforce_id,   :string
    table.column :synchronized_at, :datetime
    table.timestamps null: false
  end

  add_index :users, :salesforce_id

end

# :nodoc:
class CustomObject < ActiveRecord::Base

  belongs_to :user

end

class User < ActiveRecord::Base; end
