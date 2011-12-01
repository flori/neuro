#!/usr/bin/env ruby

require 'neuro'
require 'enumerator'

class OCR
  include Neuro

  class Character
    def initialize(char, number, vector)
      @char, @number, @vector = char, number, vector
    end

    attr_reader :char, :number, :vector

    def to_s
      result = ''
      @vector.each_slice(5) do |row|
        row.each { |pixel| result << (pixel < 0 ? ' ' : '*') }
        result << "\n"
      end
      result
    end

    def dup
      self.class.new(@char.dup, @number, @vector.dup)
    end
  end

  CHAR_BTIMAP = [
    "_***__****__*****_****__*****_*****_*****_*___*_____*_____*_*___*_*_____*___*_****__*****_*****_*****_*****_*****_*****_*___*_*___*_*___*_*___*_*___*_*****_",
    "*___*_*___*_*_____*___*_*_____*_____*_____*___*_____*_____*_*___*_*_____**_**_*___*_*___*_*___*_*___*_*___*_*_______*___*___*_*___*_*___*_*___*_*___*_____*_",
    "*___*_*___*_*_____*___*_*_____*_____*_____*___*_____*_____*_*__*__*_____*_*_*_*___*_*___*_*___*_*___*_*___*_*_______*___*___*_*___*_*___*__*_*__*___*____*__",
    "*****_****__*_____*___*_****__****__*_***_*****_____*_____*_***___*_____*___*_*___*_*___*_*****_**__*_****__*****___*___*___*_*___*_*___*___*___*****___*___",
    "*___*_*___*_*_____*___*_*_____*_____*___*_*___*_____*_____*_*__*__*_____*___*_*___*_*___*_*_____*_*_*_*___*_____*___*___*___*_*___*_*_*_*__*_*______*__*____",
    "*___*_*___*_*_____*___*_*_____*_____*___*_*___*_____*_____*_*___*_*_____*___*_*___*_*___*_*_____*__**_*___*_____*___*___*___*__*_*__**_**_*___*_____*_*_____",
    "*___*_****__*****_****__*****_*_____*****_*___*_____*_*****_*___*_****__*___*_*___*_*****_*_____*****_*___*_*****___*____****___*___*___*_*___*******_*****_",
  ]

  CHARACTERS = []
  ('A'..'Z').each_with_index do |char, number|
    vector = []
    7.times do |j|
      c = CHAR_BTIMAP[j][6 * number, 5]
      vector += c.split(//).map { |x| x == '*' ? 1.0 : -1.0 }
    end
    CHARACTERS << Character.new(char, number, vector)
  end

  def initialize
    filename = File.basename($0) + '.dump'
    if File.exist?(filename)
      File.open(filename, 'rb') do |f|
        @network = Network.load(f)
      end
    else
      STDERR.puts "Wait a momemt until the network has learned enough..."
      @network = Network.new(5 * 7, 70, 26)
      @network.debug = STDERR
      @network.debug_step = 100
      max_error = 1.0E-5
      eta = 0.2
      max_count = CHARACTERS.size * 10
      count = max_count
      until count < max_count
        count = 0
        CHARACTERS.sort_by { rand }.each do |character|
          count += @network.learn(character.vector,
            make_result_vector(character.number), max_error, eta)
        end
      end
      STDERR.print "Dumping network (learned #{@network.learned} times)... "
      File.open(filename, 'wb') do |f|
        @network.dump(f)
      end
      STDERR.puts "done!"
    end
  end

  attr_reader :network

  def make_result_vector(number)
    Array.new(CHARACTERS.size) { |i| number == i ? 0.9 : 0.1 }
  end

  def vector_to_number(vector)
    vector.enum_for(:each_with_index).max[1]
  end

  def vector_to_char(vector)
    number = vector_to_number(vector)
    CHARACTERS[number]
  end

  def categorize(scan_vector)
    decision = @network.decide(scan_vector)
    vector_to_char(decision)
  end

  def self.noisify(character, percentage)
    char = CHARACTERS.find { |c| c.char == character }
    copy = char.dup
    pixels = (copy.vector.size * (percentage / 100.0)).round
    pixels.times do
      picked = rand(copy.vector.size)
      copy.vector[picked] = copy.vector[picked] < 0.0 ? 1.0 : -1.0
    end
    copy
  end
end

if $0 == __FILE__
  ocr = OCR.new
  loop do
    puts "", "Input a character from 'A'-'Z': "
    c = gets or break
    c.chomp!
    c.tr!('a-z', 'A-Z')
    break unless /^[A-Z]$/.match(c)
    input_char = OCR.noisify(c, 5)
    puts "Noisy Character:", input_char, ""
    rec_char = ocr.categorize(input_char.vector)
    puts "Understood '#{rec_char.char}':", rec_char
  end
end
