require 'rubyserial'

class Array
  def chr
    self.map { |e| e.chr }
  end
end

class Rucicka
  MIN_ELBOW = 19
  MIN_SHOULDER = 110
  MIN_WRIST = 80
  MIN_BASE = 70
  MIN_GRIPPER = 40
  MIN_WRIST_ROTATE = 86

  MAX_ELBOW = 90
  MAX_SHOULDER = 170
  MAX_WRIST = 100
  MAX_BASE = 70
  MAX_GRIPPER = 40
  MAX_WRIST_ROTATE = 86
  
  STEP_INTERVAL = 0.05
  #STEP_INTERVAL = 1.1

  def initialize
    print 'Connecting...'
    @serial = Serial.new '/dev/tty.usbserial-A49B20I', 9600
    puts 'OK'

    print 'Initializing...'
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
    puts "<-  #{response}"
    
    response = receive
    puts "<-  #{response}"
    
    puts 'Moving to `park` position'
    apply_preset(:park)
  end

  def run
    puts 'I am ready!'
    
    while true
      puts
      puts 'Type command (or `help`):'
      s = gets.strip

      if s == 'exit'
        break
      elsif s == 'help'
        puts "I understand the following:\nexit, help, ninety, default, min, max, park"
      elsif s == 'ninety'
        reach_preset(:ninety)
      elsif s == 'default'
        reach_preset(:default)
      elsif s == 'min'
        reach_preset(:min)
      elsif s == 'max'
        reach_preset(:max)
      elsif s == 'park'
        reach_preset(:park)
      else
        send(constrain(@coords))
      end
    end
    
    puts 'Parking...'
    
    reach_preset(:park)

    puts 'Exiting'
  end

private
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

  def reach(new_coords)
    deltas = {}
    directions = {}

    new_coords.each do |key, value|
      deltas[key] = (@coords[key] - value).abs
      directions[key] = ((@coords[key] - value) > 0) ? :up : :down
    end

    steps = deltas.values.max

    puts "Performing #{steps} steps:"

    steps.times do |i|
      puts "Performing step #{i}/#{steps}"

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

    puts "Done"
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

  def send(coords)
    data = "<#{coords[:elbow]},#{coords[:shoulder]},#{coords[:wrist]},#{coords[:base]},#{coords[:gripper]},#{coords[:wrist_rotate]}>\n"
    print "-> #{data}"
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
    
    response = receive
    puts "<-  #{response}"
  end
  
  def receive
    @serial.read(32)
  end
end

r = Rucicka.new
r.run
