require 'mqtt'
require_relative 'lib'
require_relative 'rucicka'
require 'io/console'
require 'dotenv/load'

module Rucicka
  class Client
    include Lib

    def initialize
      @client = MQTT::Client.connect(MQTT_IP)
      @client.subscribe(MQTT_TOPIC_OUT)
      define_presents
      @park_position = {
          rotation: 75,
          height: 3,
          distance: 5,
          gripper: 40,
          wrist_rotate: 86
      }
      park
    end

    def forward(step = 1)
      @position[:distance] += step
      move
    end

    def left(step = 1)
      @position[:rotation] += step
      move
    end

    def right(step = 1)
      @position[:rotation] -= step
      move
    end

    def back(step = 1)
      @position[:distance] -= step
      move
    end

    def up(step = 1)
      @position[:height] += step
      move
    end

    def down(step = 1)
      @position[:height] -= step
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

    def park
      coords = position_to_coords @park_position
      send(coords)
      @position = @park_position.dup
      p coords_format(@coords)
    end

    private

    def move
      return if @position.nil?
      coords = position_to_coords @position
      send(coords)
    end

    def send(coords)
      coords = mqtt_format(coords)
      @client.publish(MQTT_TOPIC_IN, coords)
      _, message = @client.get
      @coords = mqtt_parse(message)
    end

    def position_to_coords(position)
      super(position[:rotation], position[:height], position[:distance], position[:gripper], position[:wrist_rotate])
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
      when "\e[A"
        up 3
      when "\e[B"
        down 3
      when "\e[C"
        right 3
      when "\e[D"
        left 3
      when "+"
        forward 3
      when "-"
        back 3
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
