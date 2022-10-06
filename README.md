# activerecord-cubrid2-adapter
Cubrid database connector for ruby, and active_record, depends on 'cubrid' gem

DESCRIPTION
-----------

Cubrid2 ActiveRecord adapter privides Cubrid database from Ruby on Rails applications. Now works with Ruby on Rails 6.0 and it is working with Cubrid database versions 9.x to higher. 

INSTALLATION
------------

```ruby
# Use cubrid as the database for Active Record
gem 'cubrid' # cubrid interface gem, based on native CCI C interface 
gem 'activerecord-cubrid2-adapter'
```
Currently Rails <6.0, Windows, JRuby is not testes.

### Without Rails and Bundler

If you want to use ActiveRecord and Cubrid2 adapter without Rails and Bundler then install it just as a gem:

```bash
gem install activerecord-cubrid2-adapter
```

USAGE
-----

### Database connection

In Rails application `config/database.yml` use 'cubrid2' as adapter name, e.g.

```yml
development:
  adapter: cubrid2
  host: localhost
  database: testdb
  username: user
  password: secret
```

EXAMPLE
-------------

Check test_activerecord.rb in the tests directory.


LINKS
-----

* Source code: https://github.com/damulhan/activerecord-cubrid2-adapter
* Active Record – Object-relational mapping in Rails: https://github.com/rails/rails/tree/main/activerecord 
* Cubrid Ruby GEM: https://github.com/CUBRID/cubrid-ruby 
* Cubrid Homepage: https://www.cubrid.org

