# Copyright 2008, Engine Yard, Inc.
#
# This file is part of Vertebra.
#
# Vertebra is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Vertebra is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Vertebra.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'amalgalite'

class PersistentQueues
  SCHEMA = <<-SQL
    create table queues(
      id integer primary key,
      q,
      msg
    );
  SQL

  SELECT = 'select id, msg from queues where q=$q limit 1'
  DELETE = 'delete from queues where id=$id'
  INSERT = 'insert into queues(q, msg) values ($q, $msg)'

  def pop(queue)
    row = nil
    @db.transaction {
      row = @db.execute(SELECT, '$q' => queue)[0]
      return unless row
      id = row[0]
      @db.execute(DELETE, '$id' => id)
    }
    unmarshal(row[1])
  rescue
    nil
  end

  def push(queue, msg)
    @db.transaction {
      @db.execute(INSERT, '$q' => queue, '$msg' => marshal(msg))
    }
  end

  def inspect_queue(queue)
    rows = @db.execute('select * from queues')
    p rows
  end

  def initialize(path = default_path)
    @path = path
    setup!
  end

  def setup!
    @db = Amalgalite::Database.new @path
    unless @db.schema.tables['queues']
      @db.execute SCHEMA
      @db = Amalgalite::Database.new @path
    end
  end

  def marshal(string)
    [Marshal.dump(string)].pack('m*')
  end

  def unmarshal(str)
    Marshal.load(str.unpack("m")[0])
  end

end


if __FILE__ == $0
  q = PersistentQueues.new 'q.db'
  start = Time.now
  [*0..99].each do |a|
    q.push 'iqs', "some stanza: #{a}"
    q.push 'msg', "some stanza: #{a}"
    q.push 'auth', "some stanza: #{a}"
  end

  puts "Pushed 300 messages in: #{Time.now - start}"

  100.times {
    q.pop('iqs')
    q.pop('msg')
    q.pop('auth')
  }
  puts "Took: #{Time.now - start}"
  q.inspect_queue 'iqs'
end
