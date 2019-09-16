require 'rubyserial'
require 'mqtt'
require_relative 'rucicka'
require_relative 'lib'

module Rucicka
  class Server
    include Lib

    def initialize
      print 'rucicka> Connecting...'
      @serial = if OS.mac?
                  Serial.new '/dev/tty.usbserial-A49B20I', 9600
                else

                  Serial.new '/dev/ttyUSB0', 9600
                end

      puts 'OK'

      print 'rucicka> Initializing...'
      @random = Random.new
      define_presents

      @coords = {
        elbow: 50,
        shoulder: 140,
        wrist: 90,
        base: 70,
        gripper: 40,
        wrist_rotate: 86
      }

      sleep 1

      @serial.write("Hello\n")

      sleep 1

      puts 'OK'

      response = receive
      puts "serial> <-  #{response}"

      response = receive
      puts "serial> <-  #{response}"

      puts 'rucicka> Moving to `park` position'
      apply_preset(:park)
    end

    def run
      puts 'rucicka> I am ready!'

      loop do
        puts
        puts 'rucicka> Type command (or `help`):'
        s = gets.strip

        if s == 'exit'
          break
        elsif s == 'help'
          puts "rucicka> I understand the following:\nexit, help, ninety, default, high, low, demo, mqtt, park"
        elsif s == 'ninety'
          reach_preset(:ninety)
        elsif s == 'default'
          reach_preset(:default)
        elsif s == 'low'
          reach_preset(:low)
        elsif s == 'high'
          reach_preset(:high)
        elsif s == 'min'
          reach_preset(:min)
        elsif s == 'max'
          reach_preset(:max)
        elsif s == 'park'
          reach_preset(:park)
        elsif s == 'demo'
          do_standing
        elsif s == 'mqtt'
          do_mqtt
        elsif s == 'pos'
          do_pos
        elsif s == 'manual'
          do_manual
        else
          reach(@coords)
        end
      end

      puts 'rucicka> Parking...'

      reach_preset(:park)
      reach_preset(:park)
      sleep(0.1)

      puts 'rucicka> Exiting'
    end

    private

    def do_standing
      trap('INT') { throw :ctrl_c }

      catch :ctrl_c do
        begin
          loop do
            high_coords = get_random_coords
            low_coords = get_random_coords

            reach(high_coords)
            reach(high_coords)
            sleep(WAIT_INTERVAL)
            reach_preset(:default)
            reach_preset(:default)
            sleep(WAIT_INTERVAL)
            reach(low_coords)
            reach(low_coords)
            sleep(WAIT_INTERVAL)
          end
        rescue StandardError => e
          puts "Error: #{e}"
        end
      end

      trap('INT', 'DEFAULT')
    end

    def do_mqtt
      trap('INT') { throw :ctrl_c }

      catch :ctrl_c do
        begin
          print 'rucicka> Connecting to MQTT...'
          MQTT::Client.connect(MQTT_IP) do |client|
            puts 'OK'
            # From client to warehouse:
            #   rucicka/move (send six comma separated int values as payload)
            # From warehouse to client:
            #   rucicka/status (will send six comma separated int values as payload)
            client.get(MQTT_TOPIC_IN) do |topic, message|
              puts "mqtt> <- #{topic}: #{message}"
              coords = mqtt_parse(message)
              # payload = mqtt_format(coords)
              # client.publish(MQTT_TOPIC_OUT, payload, false)
              # puts "mqtt> -> #{MQTT_TOPIC_OUT}: #{payload}"
              # reach(constrain(coords))
              reach(constrain(coords))
              payload = mqtt_format(@coords)
              client.publish(MQTT_TOPIC_OUT, payload, false)
              puts "mqtt> -> #{MQTT_TOPIC_OUT}: #{payload}"
              sleep(WAIT_INTERVAL)
            end
          end
        rescue StandardError => e
          puts "Error: #{e}"
        end
      end

      trap('INT', 'DEFAULT')
    end

    def do_pos
      trap('INT') { throw :ctrl_c }

      catch :ctrl_c do
        begin
          loop do
            puts 'rucicka> Enter desired position in format "ROT,HEIGHT,DIST,GRIP,W_ROT":'
            position = gets.strip.split(',')
            rot = position[0].to_i
            height = position[1].to_i
            dist = position[2].to_i
            grip = position[3].to_i
            wrist = position[4].to_i

            coords = position_to_coords(rot, height, dist, grip, wrist)
            if coords.nil?
              puts 'rucicka> Desired position is unreachable!'
              next
            end
            p coords_format(coords)
            reach(coords)
          end
        rescue StandardError => e
          puts "Error: #{e}"
        end
      end

      trap('INT', 'DEFAULT')
    end

    def do_manual
      trap('INT') { throw :ctrl_c }

      catch :ctrl_c do
        begin
          loop do
            puts 'rucicka> Enter desired servo rotation manually in format "ELBOW,SHOULDER,WRIST,BASE,GRIPPER,WRIST_ROTATE" in int in degrees (parking position is "19,170,80,70,40,86", default is "50,139,91,70,40,86"):'
            coords = coords_parse(gets.strip)
            p coords_format(coords)
            reach(coords)
          end
        rescue StandardError => e
          puts "Error: #{e}"
        end
      end

      trap('INT', 'DEFAULT')
    end

    def new_reach(new_coords)
      move(constrain(new_coords))
      @coords = new_coords
    end

    def reach(new_coords)
      return new_reach(new_coords)

      deltas = {}
      directions = {}

      new_coords.each do |key, value|
        deltas[key] = (@coords[key] - value).abs
        directions[key] = (@coords[key] - value) > 0 ? :up : :down
      end

      steps = deltas.values.max

      puts "rucicka> Performing #{steps} steps:"

      steps.times do |i|
        puts "rucicka> Performing step #{i}/#{steps}"

        # deltas.each do |key, _value|
        #   if (deltas[key] != 0) && (i % (steps / deltas[key]) == 0)
        #     if directions[key] == :down
        #       @coords[key] += 1
        #     else # directions[key] == :down
        #       @coords[key] -= 1
        #     end
        #   end
        # end

        deltas.each do |key, _value|
          if deltas[key] != 0
            if directions[key] == :down
              @coords[key] += 1
            else # directions[key] == :down
              @coords[key] -= 1
            end
            deltas[key] -= 1
          end
        end

        move(constrain(@coords))
      end

      puts 'rucicka> Done'
    end

    def get_random_coords
      {
        elbow: @random.rand(40...60),
        shoulder: @random.rand(110...130),
        wrist: @random.rand(30...120),
        base: @random.rand(50...90),
        gripper: @random.rand(30...90),
        wrist_rotate: @random.rand(0...86)
      }
    end

    def reach_preset(key)
      reach(@presets[key])
    end

    def apply_preset(key)
      preset = @presets[key]

      preset.each do |key, value|
        @coords[key] = value
      end

      move(constrain(@coords))
    end

    def move(coords)
      data = "<#{coords[:elbow]},#{coords[:shoulder]},#{coords[:wrist]},#{coords[:base]},#{coords[:gripper]},#{coords[:wrist_rotate]}>\n"
      print "serial> -> #{data}"
      @serial.write(data)
      sleep STEP_INTERVAL
    end

    def receive
      @serial.read(32)
    end
  end
end

r = Rucicka::Server.new
r.run
