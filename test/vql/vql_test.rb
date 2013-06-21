# encoding: UTF-8

require 'vines/services'
require 'minitest/autorun'

describe VinesQL do
  def setup
    Citrus.load(File.expand_path('../../../lib/vines/services/vql/vql.citrus', __FILE__))
  end

  def test_negative_number
    match = VinesQL.parse('foo < -42 ')
    assert_equal '(doc.ohai.foo < -42)', match.js
    assert_equal 'cast(value as number) < ?', match.sql
    assert_equal ['foo', '-42'], match.params

    match = VinesQL.parse('foo < -0.5 ')
    assert_equal '(doc.ohai.foo < -0.5)', match.js
    assert_equal 'cast(value as number) < ?', match.sql
    assert_equal ['foo', '-0.5'], match.params

    assert_raises(Citrus::ParseError) { VinesQL.parse('12 < -') }
    assert_raises(Citrus::ParseError) { VinesQL.parse('12 < --1') }
  end

  def test_less_than
    match = VinesQL.parse('foo < 1 ')
    assert_equal '(doc.ohai.foo < 1)', match.js
    assert_equal 'cast(value as number) < ?', match.sql
    assert_equal ['foo', '1'], match.params

    match = VinesQL.parse('foo<=1 ')
    assert_equal '(doc.ohai.foo <= 1)', match.js
    assert_equal 'cast(value as number) <= ?', match.sql
    assert_equal ['foo', '1'], match.params

    match = VinesQL.parse('foo < 1.5 ')
    assert_equal '(doc.ohai.foo < 1.5)', match.js
    assert_equal 'cast(value as number) < ?', match.sql
    assert_equal ['foo', '1.5'], match.params

    assert_raises(Citrus::ParseError) { VinesQL.parse('12 < 42') }
  end

  def test_greater_than
    match = VinesQL.parse('foo > 1')
    assert_equal '(doc.ohai.foo > 1)', match.js
    assert_equal 'cast(value as number) > ?', match.sql
    assert_equal ['foo', '1'], match.params

    match = VinesQL.parse('foo>=1')
    assert_equal '(doc.ohai.foo >= 1)', match.js
    assert_equal 'cast(value as number) >= ?', match.sql
    assert_equal ['foo', '1'], match.params

    match = VinesQL.parse('foo > 1.5')
    assert_equal '(doc.ohai.foo > 1.5)', match.js
    assert_equal 'cast(value as number) > ?', match.sql
    assert_equal ['foo', '1.5'], match.params

    assert_raises(Citrus::ParseError) { VinesQL.parse('12 > 42') }
  end

  def test_is
    match = VinesQL.parse('foo.bar is 13')
    assert_equal '(doc.ohai.foo.bar === 13)', match.js
    assert_equal 'value=?', match.sql
    assert_equal ['foo.bar', '13'], match.params

    match = VinesQL.parse('foo.bar is 13.5')
    assert_equal '(doc.ohai.foo.bar === 13.5)', match.js
    assert_equal 'value=?', match.sql
    assert_equal ['foo.bar', '13.5'], match.params

    match = VinesQL.parse('foo.bar is true')
    assert_equal '(doc.ohai.foo.bar === true)', match.js
    assert_equal 'value=?', match.sql
    assert_equal ['foo.bar', 'true'], match.params

    match = VinesQL.parse('foo.bar is false')
    assert_equal '(doc.ohai.foo.bar === false)', match.js
    assert_equal 'value=?', match.sql
    assert_equal ['foo.bar', 'false'], match.params

    match = VinesQL.parse('foo.bar is null')
    assert_equal '(doc.ohai.foo.bar === null)', match.js
    assert_equal 'value is null', match.sql
    assert_equal ['foo.bar'], match.params

    match = VinesQL.parse('foo.bar is " bar "')
    assert_equal '(doc.ohai.foo.bar === " bar ")', match.js
    assert_equal 'value=?', match.sql
    assert_equal ['foo.bar', ' bar '], match.params

    assert_raises(Citrus::ParseError) { VinesQL.parse('12 is 42') }
  end

  def test_is_not
    match = VinesQL.parse('foo.bar is not 13')
    assert_equal '(doc.ohai.foo.bar !== 13)', match.js
    assert_equal 'value <> ?', match.sql
    assert_equal ['foo.bar', '13'], match.params

    match = VinesQL.parse('foo.bar is not 13.5')
    assert_equal '(doc.ohai.foo.bar !== 13.5)', match.js
    assert_equal 'value <> ?', match.sql
    assert_equal ['foo.bar', '13.5'], match.params

    match = VinesQL.parse('foo.bar is not true')
    assert_equal '(doc.ohai.foo.bar !== true)', match.js
    assert_equal 'value <> ?', match.sql
    assert_equal ['foo.bar', 'true'], match.params

    match = VinesQL.parse('foo.bar is not false')
    assert_equal '(doc.ohai.foo.bar !== false)', match.js
    assert_equal 'value <> ?', match.sql
    assert_equal ['foo.bar', 'false'], match.params

    match = VinesQL.parse('foo.bar is not null')
    assert_equal '(doc.ohai.foo.bar !== null)', match.js
    assert_equal 'value is not null', match.sql
    assert_equal ['foo.bar'], match.params

    match = VinesQL.parse('foo.bar is not " bar "')
    assert_equal '(doc.ohai.foo.bar !== " bar ")', match.js
    assert_equal 'value <> ?', match.sql
    assert_equal ['foo.bar', ' bar '], match.params

    assert_raises(Citrus::ParseError) { VinesQL.parse('12 is not 42') }
  end

  def test_like
    match = VinesQL.parse('foo.bar like " bar "')
    assert_equal '(doc.ohai.foo.bar.indexOf(" bar ") !== -1)', match.js
    assert_equal 'value like ?', match.sql
    assert_equal ['foo.bar', '% bar %'], match.params
    assert_raises(Citrus::ParseError) { VinesQL.parse('12 like 42') }
    assert_raises(Citrus::ParseError) { VinesQL.parse('foo.bar like 42') }
  end

  def test_not_like
    match = VinesQL.parse('foo.bar not like " bar "')
    assert_equal '(doc.ohai.foo.bar.indexOf(" bar ") === -1)', match.js
    assert_equal 'value not like ?', match.sql
    assert_equal ['foo.bar', '% bar %'], match.params
    assert_raises(Citrus::ParseError) { VinesQL.parse('12 not like 42') }
    assert_raises(Citrus::ParseError) { VinesQL.parse('foo.bar not like 42') }
  end

  def test_starts_with
    match = VinesQL.parse('foo.bar starts with " bar "')
    assert_equal '(doc.ohai.foo.bar.lastIndexOf(" bar ", 0) === 0)', match.js
    assert_equal 'value like ?', match.sql
    assert_equal ['foo.bar', ' bar %'], match.params
    assert_raises(Citrus::ParseError) { VinesQL.parse('12 starts with 42') }
    assert_raises(Citrus::ParseError) { VinesQL.parse('foo.bar starts with 42') }
  end

  def test_ends_with
    match = VinesQL.parse('foo.bar ends with " bar "')
    assert_equal '(doc.ohai.foo.bar.match(" bar " + \'$\'))', match.js
    assert_equal 'value like ?', match.sql
    assert_equal ['foo.bar', '% bar '], match.params
    assert_raises(Citrus::ParseError) { VinesQL.parse('12 ends with 42') }
    assert_raises(Citrus::ParseError) { VinesQL.parse('foo.bar ends with 42') }
  end

  def test_group
    match = VinesQL.parse('(foo is 12 or bar is 42) and spam > 0')
    assert_equal '((doc.ohai.foo === 12) || (doc.ohai.bar === 42)) && (doc.ohai.spam > 0)', match.js
    assert_equal '(value=? or value=?) and cast(value as number) > ?', match.sql
    assert_equal ['foo', '12', 'bar', '42', 'spam', '0'], match.params
  end

  def test_complex_syntax_with_extra_whitespace
    syntax = %q{
      name  like  'abc'  and
      (
        address.city  is  'LA'  or
        address.city  is  not 'NYC'
      )  or
      ssn  not     like  '123'
      and  status  starts  with    "valid"
      and  status  ends    with    " test "
      or   ( age      >    42 )
    }.strip

    js =
      "(doc.ohai.name.indexOf('abc') !== -1) && " +
      "((doc.ohai.address.city === 'LA') || (doc.ohai.address.city !== 'NYC')) || " +
      "(doc.ohai.ssn.indexOf('123') === -1) && " +
      "(doc.ohai.status.lastIndexOf(\"valid\", 0) === 0) && " +
      "(doc.ohai.status.match(\" test \" + '$')) || " +
      "((doc.ohai.age > 42))"

    sql =
      "value like ? and " +
      "(value=? or value <> ?) or " +
      "value not like ? and " +
      "value like ? and " +
      "value like ? or " +
      "(cast(value as number) > ?)"

    params = [
      'name', '%abc%',
      'address.city', 'LA',
      'address.city', 'NYC',
      'ssn', '%123%',
      'status', 'valid%',
      'status', '% test ',
      'age', '42']

    match = VinesQL.parse(syntax)
    assert_equal js, match.js
    assert_equal sql, match.sql
    assert_equal params, match.params
  end

  def test_invalid_syntax
    assert_raises(Citrus::ParseError) do
      VinesQL.parse('some bogus syntax!')
    end
  end

  def test_params_are_strings_not_matches
    match = VinesQL.parse('foo < 42 and bar is "foo" and spam is not true')
    assert_equal ['foo', '42', 'bar', 'foo', 'spam', 'true'], match.params
    # were incorrectly returned as Citrus::Match objects
    match.params.each do |p|
      assert_equal String, p.class
    end
  end
end
