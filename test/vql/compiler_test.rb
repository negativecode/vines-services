# encoding: UTF-8

require 'vines/services'
require 'minitest/autorun'

describe Vines::Services::VQL::Compiler do
  def setup
    @compiler = Vines::Services::VQL::Compiler.new
    @query = "foo.bar like ' spam ' and (age < 42 or age > 99)"
  end

  def test_to_js_raises
    assert_raises(ArgumentError) { @compiler.to_js(nil) }
    assert_raises(ArgumentError) { @compiler.to_js(' ') }
  end

  def test_to_sql_raises
    assert_raises(ArgumentError) { @compiler.to_sql(nil) }
    assert_raises(ArgumentError) { @compiler.to_sql(' ') }
  end

  def test_to_js
    js = @compiler.to_js(@query)
    expected = %q{
      function(doc) {
        if (doc.type != 'System') return;
        try {
          var match = (doc.ohai.foo.bar.indexOf(' spam ') !== -1) && ((doc.ohai.age < 42) || (doc.ohai.age > 99));
          if (match) {
            var name = doc['_id'].replace('system:', '');
            var os = doc.ohai.kernel.os.toLowerCase().replace('gnu/', '');
            emit(name, os);
          }
        } catch(e) {
          log(e.message);
        }
      }
    }
    assert_equal strip(expected), strip(js)
  end

  def test_to_full_js
    service = Struct.new(:id, :code)
    services = [service.new(42, 'fqdn is "www"'), service.new(1, 'age > 42')]
    js = @compiler.to_full_js(services)
    expected = %q{
      function(doc) {
        if (doc.type != 'System') return;
        var name = doc['_id'].replace('system:', '');
        var os = doc.ohai.kernel.os.toLowerCase().replace('gnu/', '');

        try {
          var match = (doc.ohai.fqdn === "www");
          if (match) {
            emit([0, '42'], {name: name, os: os});
            emit([1, name], '42');
          }
        } catch(e) {
          log(e.message);
        }

        try {
          var match = (doc.ohai.age > 42);
          if (match) {
            emit([0, '1'], {name: name, os: os});
            emit([1, name], '1');
          }
        } catch(e) {
          log(e.message);
        }

      }
    }
    assert_equal strip(expected), strip(js)
  end

  def test_to_sql
    sql, params = @compiler.to_sql(@query)
    expected = %q{
      select name, os from systems
      inner join attributes a0 on id=a0.system_id and a0.key=?
      inner join attributes a1 on id=a1.system_id and a1.key=?
      inner join attributes a2 on id=a2.system_id and a2.key=?
      where a0.value like ? and (cast(a1.value as number) < ? or cast(a2.value as number) > ?)
      order by name
    }
    assert_equal strip(expected), strip(sql)
    assert_equal ['foo.bar', 'age', 'age', '% spam %', '42', '99'], params
  end

  private

  def strip(str)
    str.strip.gsub(/[ ]{2,}/, '')
  end
end
