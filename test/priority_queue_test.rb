# encoding: UTF-8

require 'vines/services'
require 'minitest/autorun'

class PriorityQueueTest < MiniTest::Unit::TestCase
  def test_queue_push_sorts
    queue = Vines::Services::PriorityQueue.new
    nums = (0..10_000).map {|i| rand(10_000) }
    popped = []
    EM.run do
      nums.each {|num| queue.push(num) }
      assert_equal nums.size, queue.size
      (nums.size - 1).times do
        queue.pop {|item| popped << item }
      end
      queue.pop {|item| popped << item; EM.stop }
    end
    assert queue.empty?
    assert_equal 0, queue.size
    assert_equal nums.sort, popped
  end
end
