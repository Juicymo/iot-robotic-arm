require_relative 'client'

@arm = Rucicka::Client.new

def grab_mark
  move_to_dip
  @arm.gripper_on
  @arm.up(3)
  @arm.park
end

def drop_mark
  move_to_dip
  @arm.gripper_off
  @arm.up(5)
  @arm.park
end

def move_to_dip
  @arm.set_moves do
    @arm.up(10)
    @arm.right(18.5)
    @arm.forward(10)
    @arm.wrist_down(6.7)
  end
  @arm.down(9)
end

def dip
  move_to_dip
  @arm.down(6.8)
  @arm.up(5)
  @arm.park
end

trap('INT') { throw :ctrl_c }

catch :ctrl_c do
  grab_mark
  start = 10
  5.times do |i|
    dip
    @arm.set_moves do
      @arm.left(start - (i * 3))
      @arm.up(5)
      @arm.forward(15)
      @arm.wrist_down(6.5)
    end
    @arm.down(7.6)
    @arm.wrist_up(0.1)
    @arm.right(0.2)

    @arm.up(4)
    @arm.park
  end

  drop_mark
end

trap('INT', 'DEFAULT')
@arm.park
