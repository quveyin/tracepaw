# frozen_string_literal: true

require 'bcrypt'

class BackfillPetsUser < ActiveRecord::Migration[8.1]
  def up
    conn = ActiveRecord::Base.connection

    say_with_time("Creating admin user if needed (raw SQL)") do
      admin_row = conn.select_one("SELECT id FROM users WHERE email = 'admin@tracepaw.com'")

      unless admin_row
        encrypted = BCrypt::Password.create('password123')
        now = Time.current
        conn.execute <<-SQL
          INSERT INTO users (email, encrypted_password, first_name, last_name, created_at, updated_at)
          VALUES (#{conn.quote('admin@tracepaw.com')}, #{conn.quote(encrypted)}, #{conn.quote('Admin')}, #{conn.quote('TracePaw')}, #{conn.quote(now)}, #{conn.quote(now)})
        SQL
        admin_row = conn.select_one("SELECT id FROM users WHERE email = 'admin@tracepaw.com'")
      end

      admin_id = admin_row['id']

      say_with_time("Assigning orphan pets to admin") do
        conn.execute("UPDATE pets SET user_id = #{admin_id} WHERE user_id IS NULL")
      end

      say_with_time("Enforcing NOT NULL on pets.user_id") do
        change_column_null :pets, :user_id, false
      end
    end
  end

  def down
    say_with_time("Removing NOT NULL constraint on pets.user_id") do
      change_column_null :pets, :user_id, true
    end
  end
end
