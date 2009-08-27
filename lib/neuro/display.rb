#!/usr/bin/env ruby

require 'gnomecanvas2'
require 'gconf2'
require 'neuro'

module Neuro::Display
  include Gnome
  include Gtk

  module Draw
    WIDTH   = 32
    HEIGHT  = 32
    XGAP    = 128
    YGAP    = 64

    LAYERS = {
      :input_layer  => XGAP + XGAP / 2,
      :hidden_layer => XGAP * 2 + XGAP / 2 + WIDTH,
      :output_layer => XGAP * 3 + XGAP / 2 + WIDTH * 2,
    }

    def position(layer = @layer, i = @i)
      x = LAYERS[layer]
      y = (i + 1) * YGAP + i * HEIGHT + @offsets[layer] * (HEIGHT + YGAP)
      return x, y
    end
  end

  class Input < CanvasGroup
    include Draw

    def initialize(root, iv, i, offsets)
      @i, @offsets = i, offsets
      @value = "%.3f" % iv
      x, y = position
      super(root, :x => x, :y => y)
      draw_text
    end 

    private

    def position
      x = LAYERS[:input_layer] - XGAP - @value.size * 6
      y = (@i + 1) * YGAP + @i * HEIGHT + @offsets[:input_layer] * (HEIGHT + YGAP)
      return x, y
    end

    def draw_text
      font_size = 14
      Gnome::CanvasText.new(
        self, :x => WIDTH / 2, :y => HEIGHT / 2 - 2,
        :fill_color => "black",
        :text => @value,
        :'size-points' => font_size
      )
    end
  end

  class Output < CanvasGroup
    include Draw

    def initialize(root, ov, i, offsets)
      @i, @offsets = i, offsets
      @value = "%.3f" % ov
      x, y = position
      super(root, :x => x, :y => y)
      draw_text
    end 

    private

    def position
      x = LAYERS[:output_layer] + XGAP + 30
      y = (@i + 1) * YGAP + @i * HEIGHT + @offsets[:output_layer] * (HEIGHT + YGAP)
      return x, y
    end

    def draw_text
      font_size = 14
      Gnome::CanvasText.new(
        self, :x => WIDTH / 2, :y => HEIGHT / 2 - 2,
        :fill_color => "black",
        :text => @value,
        :'size-points' => font_size
      )
    end
  end

  class Node < CanvasGroup
    include Draw

    def initialize(root, nh, layer, i, offsets)
      @nh, @layer, @i, @offsets = nh, layer, i, offsets
      x, y = position
      super(root, :x => x, :y => y)
      draw_node
    end 

    private

    def draw_node 
      Gnome::CanvasEllipse.new(
        self, :x1 => 1, :y1 => 2,
        :x2 => WIDTH - 2, :y2 => HEIGHT - 3,
        :outline_color => "black",
        :fill_color => "grey",
        :width_units => 1.0
      )
      name = @i.to_s 
      font_size = 14
      Gnome::CanvasText.new(
        self, :x => WIDTH / 2, :y => HEIGHT / 2 - 2,
        :fill_color => "black",
        :text => name,
        :'size-points' => font_size
      )
    end
  end

  class Edges < CanvasGroup
    include Draw

    def initialize(root, nh, layer, i, offsets)
      @nh, @layer, @i, @offsets = nh, layer, i, offsets
      super(root, :x => 0, :y => 0)
      draw_edges
    end

    private

    def middle_position(layer, i)
      x, y = position(layer, i)
      x += WIDTH / 2
      y += HEIGHT / 2
      return x, y
    end

    def color(weight)
      if weight < 0
        "red"
      else
        "green"
      end 
    end

    def width(layer, i)
      o = @nh[layer][i][:output].abs
      if o >= 1
        5.0
      else
        5.0 * o
      end
    end

    def draw_edges
      case @layer 
      when :input_layer
         (0...@nh[:input_size]).each do |i|
          x1, y1 = middle_position(@layer, i)
          Gnome::CanvasLine.new(
            self, :points => [ [x1, y1], [x1 - XGAP, y1] ],
            :fill_color => 'black',
            :width_units => 1.0
          )
          end
      when :hidden_layer
        @nh[@layer].each_with_index do |neuron, i|
          x1, y1 = middle_position(@layer, i)
          neuron[:weights].each_with_index do |w, j|
            x2, y2 =  middle_position(:input_layer, j)
            Gnome::CanvasLine.new(
              self, :points => [ [x1, y1], [x2, y2] ],
              :fill_color => color(w),
              :width_units => 1.0
            )
          end
        end
      when :output_layer
        @nh[@layer].each_with_index do |neuron, i|
          x1, y1 = middle_position(@layer, i)
          neuron[:weights].each_with_index do |w, j|
            x2, y2 =  middle_position(:hidden_layer, j)
            Gnome::CanvasLine.new(
              self, :points => [ [x1, y1], [x2, y2] ],
              :fill_color => color(w),
              :width_units => 1.0
            )
          end
          Gnome::CanvasLine.new(
            self, :points => [ [x1, y1], [x1 + XGAP, y1] ],
            :fill_color => 'black',
            :width_units => 1.0
          )
        end
      end
    end
  end


  class NetworkDrawer
    include Draw

    def initialize(root, network)
      @root, @network = root, network
      @width, @height = 800, 600
    end

    attr_reader :width, :height

    def draw(input, output)
      nh = @network.to_h
      layers = [ :input_layer, :hidden_layer, :output_layer ]
      sizes = [ :input_size, :hidden_size, :output_size ].map { |x| nh[x] }
      max = sizes.max
      offsets = {}
      layers.zip(sizes) do |layer, size| 
         offsets[layer] = (max - size) / 2.0
      end
      layers.zip(sizes) do |layer, size| 
        size.times do |i|
          Edges.new(@root, nh, layer, i, offsets)
        end
      end
      max_position = -1
      layers.zip(sizes) do |layer, size| 
        size.times do |i|
          node = Node.new(@root, nh, layer, i, offsets)
          max_position = [ max_position, node.position[1] ].max
        end
      end
      @height = max_position + YGAP * 2
      input.each_with_index do |iv, i|
        Input.new(@root, iv, i, offsets)
      end
      output.each_with_index do |ov, i|
        Output.new(@root, ov, i, offsets)
      end
      self
    end
  end

  #
  # Main Window
  #

  class MainWindow < Window
    def initialize(max_height, network)
      super()
      @max_height = max_height
      @network = network

      # Actions
      signal_connect(:destroy) { quit }

      # Main Window
      set_border_width(0)
      @base_box = VBox.new(false, 0)
      add @base_box

      draw_network
      realize
      window.set_background(Gdk::Color.new(0, 0, 0))
    end

    def draw_network( input = [ 0.0 ] * @network.input_size,
                      output = [ 0.0 ] * @network.output_size)
      canvas = Gnome::Canvas.new(true)
      canvas.freeze_notify

      root = Gnome::CanvasGroup.new(canvas.root, :x => 1, :y => 1)
      nd = NetworkDrawer.new(root, @network)
      nd.draw(input, output)
      canvas.set_scroll_region(0, 0, nd.width, nd.height)

      default_size = [
        nd.width,
        nd.height > @max_height ? @max_height : nd.height
      ]
      set_default_size(*default_size)

      background = Gnome::CanvasRect.new(
        canvas.root, :x1 => 0, :y1 => 0,
        :x2 => nd.width, :y2 => nd.height,
        :fill_color => "white",
        :outline_color => "gray",
        :width_pixels => 4.0
      )
      background.lower_to_bottom
      canvas.thaw_notify

      if @scrolled_window
        @base_box.remove(@scrolled_window) 
        @scrolled_window.destroy
      end
      @scrolled_window = ScrolledWindow.new
      @scrolled_window.add(canvas)
      @scrolled_window.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)

      @base_box.pack_end(@scrolled_window, true, true, 0)
      @scrolled_window.show_all
    end

    def quit
      Gtk.main_quit
    end
  end

  module Observable
    def add_listener(&listener)
      (@__observable__listeners ||= []) << listener
    end

    def notify(m, *a, &b)
      return unless @__observable__listeners
      @__observable__listeners.each do |listener|
        listener.call(self, m, *a, &b)
      end
    end
  end

  class ObservableNetwork
    include Observable

    def initialize(neuron)
      @neuron = neuron
    end

    def method_missing(m, *a, &b)
      r = nil
      case m
      when :learn, :decide
        r = @neuron.__send__(m, *a, &b)
        notify m, r, a
      else
        r = @neuron.__send__(m, *a, &b)
      end
      r
    end
  end

  class NeuroGUI
    def initialize(max_height, network)
      @network = network
      @observed_network = ObservableNetwork.new(network)
      Gtk.init
      @main_window = MainWindow.new(max_height, @observed_network)
      @main_window.show_all
    end

    attr_reader :observed_network

    def start
      @observed_network.add_listener do |s, m, r, a|
        case m
        when :decide
          @main_window.draw_network(a[0], r)
        when :learn
          d = @network.decide a[0]
          @main_window.draw_network(a[0], d)
        end
      end
      Thread.new { Gtk.main }
    end
  end
end

if $0 == __FILE__
  include Neuro::Display

  class Parity
    MAX_BITS = 2

    def initialize(network)
      @network = network
      @network.debug = STDERR
      @network.debug_step = 1000
      @eta = 0.2
      @max_error = 1.0E-5
    end

    def pre_train
      vectors = all_vectors
      max_count = vectors.size * 10
      count = max_count
      until count < max_count
        count = 0
        vectors.sort_by { rand }.each do |sample|
          desired = [ parity(sample) == 1 ? 0.95 : 0.05 ]
          count += @network.learn(sample, desired, @max_error, @eta)
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

    def run
      loop do
        puts "#{@network.input_size} bits?"
        input = STDIN.gets.chomp
        /^[01]{#{@network.input_size}}$/.match(input) or next
        input = input.split(//).map { |x| x.to_i }
        parity, = @network.decide(input)
        rounded = parity.round
        puts "#{parity} -> #{rounded} - Learn, invert or skip? (l/i/s)"
        what_now = STDIN.gets.chomp
        case what_now
        when 'l'
          @network.learn(input, [ rounded == 0 ? 0.05 : 0.95 ], @max_error, @eta)
        when 'i'
          @network.learn(input, [ rounded == 0 ? 0.95 : 0.05 ], @max_error, @eta)
        end
      end
    end
  end
  network = Neuro::Network.new(Parity::MAX_BITS, Parity::MAX_BITS * 2, 1)
  ngui = NeuroGUI.new(768, network)
  par = Parity.new(ngui.observed_network)
  par.pre_train
  ngui.start
  par.run
end
