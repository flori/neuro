require 'test/unit'
require 'neuro'

class TestParity < Test::Unit::TestCase
  include Neuro

  MAX_BITS = 4
  def setup
    filename = 'test_parity.rb.dump'
    if File.exist?(filename)
      File.open(filename) do |f|
         @network = Network.load(f)
      end
    else
      @network = Network.new(MAX_BITS, MAX_BITS * 2, 1)
      @network.debug = STDERR
      @network.debug_step = 1000
      eta = 0.2
      max_error = 1.0E-6
      vectors = all_vectors
      max_count = vectors.size * 10
      count = max_count
      until count < max_count
        count = 0
        vectors.sort_by { rand }.each do |sample|
          desired = [ parity(sample) == 1 ? 0.9 : 0.1 ]
          count += @network.learn(sample, desired, max_error, eta)
        end
      end
      File.open(filename, 'wb') do |f|
        @network.dump(f)
      end
    end
  end

  def parity(vector)
    (vector.inject(1) { |s,x| s * (x < 0.5 ? -1 : 1) }) < 0 ? 1 : 0
  end

  def all_vectors
    vectors = []
    for x in 0...(2 ** MAX_BITS)
      vectors << (0...MAX_BITS).map { |i| x[i].zero? ? 0.0 : 1.0 }.reverse
    end
    vectors
  end

  def test_parities
    all_vectors.each do |vector|
      result, = @network.decide vector
      result_parity = result > ((0.9 - 0.1) / 2) ? 1 : 0
      assert_equal parity(vector), result_parity
    end
  end
end
