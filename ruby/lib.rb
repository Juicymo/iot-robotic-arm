module Rucicka
  module Lib
    def position_to_coords(rotation, height, distance)
      p "#{rotation},#{height},#{distance}"

      x = Math.sqrt((distance**2) + (height**2))

      if x >= (M + N)
        # puts 'rucicka> Desired position is unreachable!'
        return
      end

      s = 0.5 * (M + N + x)
      small_shoulder = compute_angle(s, M, x).degrees
      big_shoulder = Math.asin(height / x.to_f).degrees
      elbow = compute_angle(s, M, N).degrees
      gamma = compute_angle(s, x, N).degrees
      # theta = Math.asin(distance / x.to_f).degrees
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

      input = "#{elbow},#{shoulder},#{wrist},#{rotation},40,86"

      coords_parse(input)
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

    def compute_angle(s, k, l)
      Math.asin(Math.sqrt(((s - k) * (s - l)) / (k * l))) * 2
    end
  end
end