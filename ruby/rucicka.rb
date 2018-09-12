require 'rubyserial'
require 'mqtt'

MQTT_IP = '127.0.0.1'
MQTT_TOPIC_IN = 'rucicka/move'
MQTT_TOPIC_OUT = 'rucicka/status'

M = 14.60500 # shoulder to elbow, 5,75" = 14.60500 cm = 0,14605 m
N = 18.7325 # elbow to wrist, 7,375" = 18.7325 cm = 0,187325 m

class Array
  def chr
    self.map { |e| e.chr }
  end
end

class Numeric
  def radians
    (self * Math::PI) / 180
  end

  def degrees
    (self * 180) / Math::PI
  end
end

module OS
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
   (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end

class Rucicka
  MIN_ELBOW = 19
  MIN_SHOULDER = 50
  MIN_WRIST = 30
  MIN_BASE = 40
  MIN_GRIPPER = 30
  MIN_WRIST_ROTATE = 0

  MAX_ELBOW = 90
  MAX_SHOULDER = 170
  MAX_WRIST = 120
  MAX_BASE = 100
  MAX_GRIPPER = 110
  MAX_WRIST_ROTATE = 86

  WAIT_INTERVAL = 1.0
  STEP_INTERVAL = 0.05

  def initialize
    print 'rucicka> Connecting...'
    if OS.mac?
      @serial = Serial.new '/dev/tty.usbserial-A49B20I', 9600
    else

      @serial = Serial.new '/dev/ttyUSB0', 9600
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
    
    while true
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
         while true
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
            payload = mqtt_format(coords)
            client.publish(MQTT_TOPIC_OUT, payload, false)
            puts "mqtt> -> #{MQTT_TOPIC_OUT}: #{payload}"
            reach(coords)
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
        while true do
          puts 'rucicka> Enter desired position in format "ROT,HEIGHT,DIST":'
          position = gets.strip.split(',')
          rot = position[0].to_i
          height = position[1].to_i
          dist = position[2].to_i
          p "#{rot},#{height},#{dist}"
          
          x = Math.sqrt((dist**2) + (height**2))
          
          if x >= (M + N)
            puts 'rucicka> Desired position is unreachable!'
            next
          end
          
          s = 0.5 * (M + N + x)
          small_shoulder = compute_angle(s, M, x).degrees
          big_shoulder = Math.asin(height / x.to_f).degrees
          elbow = compute_angle(s, M, N).degrees
          gamma = compute_angle(s, x, N).degrees
          #theta = Math.asin(dist / x.to_f).degrees
          wrist = (90 - gamma)

          shoulder = small_shoulder + big_shoulder

          p "X = #{x} cm"
          p "S = #{s} cm2"
          p "small_shoulder = #{small_shoulder} deg"
          p "big_shoulder = #{big_shoulder} deg"
          p "shoulder = #{shoulder} deg"
          p "elbow = #{elbow} deg"
          p "wrist = #{wrist} deg"

          # calibration correction
          shoulder += 20
          elbow -= 5

          input = "#{elbow},#{shoulder},#{wrist},#{rot},#{40},#{86}"

          coords = coords_parse(input)
          p coords_format(coords)
          reach(coords)
        end
      rescue StandardError => e
         puts "Error: #{e}"
      end
    end
    
    trap('INT', 'DEFAULT')
  end
  
  def compute_angle(s, k, l)
    Math.asin(Math.sqrt(((s - k) * (s - l)) / (k * l))) * 2
  end
  
  def do_manual
    trap('INT') { throw :ctrl_c }
    
    catch :ctrl_c do
      begin
        while true do
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

  def define_presents
    @presets = {}
    @presets[:default] = {
      elbow: 50,
      shoulder: 140,
      wrist: 90,
      base: 70,
      gripper: 40,
      wrist_rotate: 86
    }
    @presets[:low] = {
      elbow: 60,
      shoulder: 110,
      wrist: 120,
      base: 50,
      gripper: 30,
      wrist_rotate: 86
    }
    @presets[:high] = {
      elbow: 40,
      shoulder: 130,
      wrist: 30,
      base: 90,
      gripper: 90,
      wrist_rotate: 0
    }
    @presets[:park] = {
      elbow: 19,
      shoulder: 170,
      wrist: 80,
      base: 70,
      gripper: 40,
      wrist_rotate: 86
    }
    @presets[:ninety] = {
      elbow: 85,
      shoulder: 110,
      wrist: 90,
      base: 70,
      gripper: 40,
      wrist_rotate: 86
    }
    @presets[:max] = {
      elbow:        MAX_ELBOW,
      shoulder:     MAX_SHOULDER,
      wrist:        MAX_WRIST,
      base:         MAX_BASE,
      gripper:      MAX_GRIPPER,
      wrist_rotate: MAX_WRIST_ROTATE
    }
    @presets[:min] = {
      elbow:        MIN_ELBOW,
      shoulder:     MIN_SHOULDER,
      wrist:        MIN_WRIST,
      base:         MIN_BASE,
      gripper:      MIN_GRIPPER,
      wrist_rotate: MIN_WRIST_ROTATE
    }
  end
  
  def reach_position(rotation, height, distance)
    
  end

  def reach(new_coords)
    deltas = {}
    directions = {}

    new_coords.each do |key, value|
      deltas[key] = (@coords[key] - value).abs
      directions[key] = ((@coords[key] - value) > 0) ? :up : :down
    end

    steps = deltas.values.max

    puts "rucicka> Performing #{steps} steps:"

    steps.times do |i|
      puts "rucicka> Performing step #{i}/#{steps}"

      deltas.each do |key, value|
        if (deltas[key] != 0) && (i % (steps/deltas[key]) == 0)
          if directions[key] == :down
            @coords[key] += 1
          else # directions[key] == :down
            @coords[key] -= 1
          end
        end
      end

      send(constrain(@coords))
    end

    puts "rucicka> Done"
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
    
    send(constrain(@coords))
  end

  def bound(value, min, max)
    [[min, value].max, max].min
  end

  def constrain(coords)
    constrained = {}

    constrained[:elbow] = bound(coords[:elbow], MIN_ELBOW, MAX_ELBOW)
    constrained[:shoulder] = bound(coords[:shoulder], MIN_SHOULDER, MAX_SHOULDER)
    constrained[:wrist] = bound(coords[:wrist], MIN_WRIST, MAX_WRIST)
    constrained[:base] = bound(coords[:base], MIN_BASE, MAX_BASE)
    constrained[:gripper] = bound(coords[:gripper], MIN_GRIPPER, MAX_GRIPPER)
    constrained[:wrist_rotate] = bound(coords[:wrist_rotate], MIN_WRIST_ROTATE, MAX_WRIST_ROTATE)

    constrained
  end
  
  def mqtt_format(coords)
    "#{coords[:elbow]},#{coords[:shoulder]},#{coords[:wrist]},#{coords[:base]},#{coords[:gripper]},#{coords[:wrist_rotate]}"
  end
  
  def mqtt_parse(payload)
    values = payload.split(',')
    coords = {}
    
    coords[:elbow]        = values[0].to_i
    coords[:shoulder]     = values[1].to_i
    coords[:wrist]        = values[2].to_i
    coords[:base]         = values[3].to_i
    coords[:gripper]      = values[4].to_i
    coords[:wrist_rotate] = values[5].to_i
    
    coords
  end
  
  def coords_parse(payload)
    values = payload.split(',')
    coords = {}
    
    coords[:elbow]        = values[0].to_i
    coords[:shoulder]     = values[1].to_i
    coords[:wrist]        = values[2].to_i
    coords[:base]         = values[3].to_i
    coords[:gripper]      = values[4].to_i
    coords[:wrist_rotate] = values[5].to_i
    
    coords
  end
  
  def coords_format(coords)
    "#{coords[:elbow]},#{coords[:shoulder]},#{coords[:wrist]},#{coords[:base]},#{coords[:gripper]},#{coords[:wrist_rotate]}"
  end

  def send(coords)
    data = "<#{coords[:elbow]},#{coords[:shoulder]},#{coords[:wrist]},#{coords[:base]},#{coords[:gripper]},#{coords[:wrist_rotate]}>\n"
    print "serial> -> #{data}"
    @serial.write(data)
    # @serial.write([
    #   coords[:elbow],
    #   coords[:shoulder],
    #   coords[:wrist],
    #   coords[:base],
    #   coords[:gripper],
    #   coords[:wrist_rotate]
    # ].chr.to_s)
    
    sleep STEP_INTERVAL
    
    # response = receive
    # puts "<-  #{response}"
  end
  
  def receive
    @serial.read(32)
  end
end

r = Rucicka.new
r.run
