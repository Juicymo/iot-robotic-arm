require 'mqtt'
require_relative 'lib'
require_relative 'rucicka'
require 'io/console'
require 'dotenv/load'

module Rucicka
  class Client
    include Lib

    MAX_HEIGHT = 25
    MIN_HEIGHT = 0.5
    MAX_DISTANCE = 33
    MIN_DISTANCE = 5
    GRIPPER_GRAB = 76

    def initialize(step = nil)
      @step = step
      @client = MQTT::Client.connect(MQTT_IP)
      @client.subscribe(MQTT_TOPIC_OUT)
      define_presents
      @park_position = {
          rotation: 75,
          height: 3,
          distance: 3,
          gripper: 30,
          wrist_rotate: 86,
          wrist: 80
      }
      park
    end

    def forward(step = nil)
      step = set_step step
      @position[:distance] += step
      move
    end

    def left(step = nil)
      step = set_step step
      @position[:rotation]  += step * 2
      move
    end

    def right(step = nil)
      step = set_step step
      @position[:rotation] -= step * 2
      move
    end

    def back(step = nil)
      step = set_step step
      @position[:distance] -= step
      move
    end

    def up(step = nil)
      step = set_step step
      @position[:height] += step
      move
    end

    def down(step = nil)
      step = set_step step
      @position[:height] -= step
      move
    end

    def wrist_left(step = nil)
      step = set_step step
      @position[:wrist_rotate] -= step * 10
      move
    end

    def wrist_right(step = nil)
      step = set_step step
      @position[:wrist_rotate] += step * 10
      move
    end

    def wrist_up(step = nil)
      step = set_step step
      @position[:wrist] -= step * 10
      move
    end

    def wrist_down(step = nil)
      step = set_step step
      @position[:wrist] += step * 10
      move
    end

    def manual
      trap('INT') { throw :ctrl_c }

      catch :ctrl_c do
        begin
          loop do
            stop = map_key_to_move
            throw :ctrl_c if stop == :stop
          end
        rescue StandardError => e
          puts "Error: #{e}"
        end
      end

      trap('INT', 'DEFAULT')
    end

    def set_moves
      if block_given?
        @dont_move = true
        yield
        @dont_move = false
        move
      end
    end

    def park
      park = @park_position.dup
      unless @position.nil?
        park[:gripper] = @position[:gripper]
      end
      coords = position_to_coords park
      send(coords)
      @position = park
      p coords_format(@coords)
    end

    def gripper_on
      @position[:gripper] = GRIPPER_GRAB
      move
    end

    def gripper_off
      @position[:gripper] = MIN_GRIPPER
      move
    end

    def gripper_close
      step = set_step step
      @position[:gripper] += step
      move
    end

    def gripper_open(step = nil)
      step = set_step step
      @position[:gripper] -= step
      move
    end

    private

    def max
      @position[:distance] = MAX_DISTANCE
      @position[:height] = MAX_HEIGHT
      move
    end

    def min
      @position[:distance] = MIN_DISTANCE
      @position[:height] = MIN_HEIGHT
      move
    end

    def max_min
      @position[:distance] = MAX_DISTANCE
      @position[:height] = MIN_HEIGHT
      move
    end

    def min_max
      @position[:distance] = MIN_DISTANCE
      @position[:height] = MAX_HEIGHT
      move
    end

    def move
      return if @position.nil?
      return if @dont_move
      @position = constrain_position(@position)
      coords = position_to_coords @position
      if coords.nil?
        p 'Unreacheable position!'
        puts "position: #{format_position @position}"
      else
        send(coords)
      end
    end

    def set_step(step)
      step ||= @step
      step ||= 1
      step
    end

    def constrain_position(position)
      constrained = {}
      constrained[:rotation] = bound(position[:rotation], MIN_BASE, MAX_BASE)
      constrained[:height] = bound(position[:height], MIN_HEIGHT, MAX_HEIGHT)
      constrained[:distance] = bound(position[:distance], MIN_DISTANCE, MAX_DISTANCE)
      constrained[:gripper] = bound(position[:gripper], MIN_GRIPPER, MAX_GRIPPER)
      constrained[:wrist_rotate] = bound(position[:wrist_rotate], MIN_WRIST_ROTATE, MAX_WRIST_ROTATE)
      constrained[:wrist] = bound(position[:wrist], MIN_WRIST, MAX_WRIST)

      constrained
    end

    def send(coords)
      coords = mqtt_format(coords)
      @client.publish(MQTT_TOPIC_IN, coords)
      _, message = @client.get
      @coords = mqtt_parse(message)
    end

    def position_to_coords(position)
      puts format_position position
      super(position[:rotation], position[:height], position[:distance], position[:gripper], position[:wrist_rotate], position[:wrist])
    end

    def format_position(position)
      "\n rotation: #{position[:rotation]}\n height: #{position[:height]}\n distance: #{position[:distance]} \n gripper: #{position[:gripper]} \n wrist_rotate: #{position[:wrist_rotate]} \n wrist: #{position[:wrist]}"
    end

    # Reads keypresses from the user including 2 and 3 escape character sequences.
    def read_char
      STDIN.echo = false
      STDIN.raw!

      input = STDIN.getc.chr
      if input == "\e" then
        input << STDIN.read_nonblock(3) rescue nil
        input << STDIN.read_nonblock(2) rescue nil
      end
    ensure
      STDIN.echo = true
      STDIN.cooked!

      return input
    end

    # oringal case statement from:
    # http://www.alecjacobson.com/weblog/?p=75
    def map_key_to_move
      c = read_char
      step = @step
      step ||= 1
      case c
      when " "
        puts "SPACE"
        park
      when "\t"
        puts "TAB"
        :stop
      when "\r"
        puts "RETURN"
        :stop
      when "\n"
        puts "LINE FEED"
        :stop
      when "\e"
        puts "ESCAPE"
        :stop
      when "\e[A", "w"
        up step
      when "\e[B", "s"
        down step
      when "\e[C", "d"
        right step
      when "\e[D", "a"
        left step
      when "+", "r"
        forward step
      when "-", "f"
        back step
      when "q"
        gripper_on
      when "e"
        gripper_off
      when 'j'
        wrist_left
      when 'l'
        wrist_right
      when 'i'
        wrist_up
      when 'k'
        wrist_down
      when "\177"
        puts "BACKSPACE"
        :stop
      when "\004"
        puts "DELETE"
        :stop
      when "\e[3~"
        puts "ALTERNATE DELETE"
        :stop
      when "\u0003"
        puts "CONTROL-C"
        :stop
      when /^.$/
        puts "SINGLE CHAR HIT: #{c.inspect}"
        :stop
      else
        puts "SOMETHING ELSE: #{c.inspect}"
        :stop
      end
    end
  end
end
