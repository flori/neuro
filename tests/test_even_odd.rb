#
# Stupid little test, that finds out if 5-bit numbers are even or odd.
#
require 'test/unit'
require 'neuro'

class TestEvenOdd < Test::Unit::TestCase
  include Neuro

  @@even = [
   [ 0, 0, 1, 1, 0 ],
   [ 1, 1, 0, 1, 0 ],
   [ 1, 0, 1, 1, 0 ],
   [ 0, 1, 0, 1, 0 ],
   [ 1, 0, 1, 0, 0 ],
   [ 0, 1, 0, 1, 0 ],
  ]

  @@odd = [
   [ 1, 0, 0, 1, 1 ],
   [ 1, 1, 1, 0, 1 ],
   [ 0, 0, 0, 1, 1 ],
   [ 0, 1, 0, 0, 1 ],
   [ 0, 1, 0, 1, 1 ],
   [ 1, 1, 1, 1, 1 ],
  ]

  def setup
    @eta = 0.2
    filename = 'test_even_odd.rb.dump'
    if File.exist?(filename)
      File.open(filename) do |f|
        @network = Network.load(f)
      end
    else
      @network = Network.new(5, 2, 1)
      @network.debug = STDERR
      @network.debug_step = 1000
      max_error = 1.0E-5
      max_count = (@@even.size + @@odd.size) * 10
      count = max_count
      until count < max_count
        count = 0
        desired = [ 0.9 ]
        @@even.each do |sample|
          count += @network.learn(sample, desired, max_error, @eta)
        end
        desired = [ 0.1 ]
        @@odd.each do |sample|
          count += @network.learn(sample, desired, max_error, @eta)
        end
      end
      File.open(filename, 'wb') do |f|
        @network.dump(f)
      end
    end
  end

  def test_hypothesis
    for x in 0..31
      vector = (0..4).map { |i| x[i] }.reverse
      result, = @network.decide vector
      bit = (result - 0.9).abs < @eta ? 0 : 1
      assert_equal x[0], bit
    end
  end
end
