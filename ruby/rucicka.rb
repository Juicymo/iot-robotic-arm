require 'rubyserial'

class Rucicka
  MIN_ELBOW = 30
  MIN_SHOULDER = 110
  MIN_WRIST = 90
  MIN_BASE = 70
  MIN_GRIPPER = 40
  MIN_WRIST_ROTATE = 86

  MAX_ELBOW = 90
  MAX_SHOULDER = 150
  MAX_WRIST = 90
  MAX_BASE = 70
  MAX_GRIPPER = 40
  MAX_WRIST_ROTATE = 86

  def initialize
    @serial = Serial.new '/dev/tty.usbserial-A49B20I'

    @coords = {
      elbow: 50,
      shoulder: 140,
      wrist: 90,
      base: 70,
      gripper: 40,
      wrist_rotate: 86
    }

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
      elbow: 50,
      shoulder: 140,
      wrist: 90,
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
  end

  def run
    while true
      s = gets.strip

      if s == 'exit'
        break
      elsif s == 'ninety'
        reach_preset(:ninety)
      elsif s == 'default'
        reach_preset(:default)
      else
        send(constrain(@coords))
      end
    end

    puts 'Exiting'
  end

private
  def reach(new_coords)
    deltas = {}
    directions = {}

    new_coords.each do |key, value|
      deltas[key] = (@coords[key] - value).abs
      directions[key] = ((@coords[key] - value) > 0) ? :up : :down
    end

    steps = deltas.values.max

    puts "Performing #{steps} steps..."

    steps.times do |i|
      puts "Performing #{i} step..."

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

      #gets
      sleep 1.1
    end

    puts "Done"
  end

  def reach_preset(key)
    reach(@presets[key])
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
    data = "#{coords[:elbow]} #{coords[:shoulder]} #{coords[:wrist]} #{coords[:base]} #{coords[:gripper]} #{coords[:wrist_rotate]}"
    puts "Sending: #{data}"

    @serial.write(data)
  end
end

r = Rucicka.new
r.run
