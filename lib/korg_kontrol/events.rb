# Korg Kontrol events (MIDI input)
module KorgKontrol

  class KontrolEvent
    attr_reader :data
    def initialize(data)
      @data = data
    end
  end

  class NativeModeEvent < KontrolEvent
  end

  class ButtonEvent < KontrolEvent
    attr_reader :state
  end

  class PadEvent < ButtonEvent
    attr_reader :index, :velocity
    def initialize(data)
      @index = (data[0] & 15) + 1
      @state = data[0] > 15
      @velocity = data[1]
    end
  
    def selector
      @index
    end
  end

  class SwitchEvent < ButtonEvent
    attr_reader :type
    def initialize(data)
      @type = SWITCH_INPUT_VALUES[data[0]]
      @state = data[1] == 127
    end
  
    def selector
      @type
    end
  end

  class EncoderEvent < KontrolEvent
    attr_reader :index, :direction
    def initialize(data)
      puts data.inspect
      @index = data[0] + 1
      @direction = data[1] == 1 ? 1 : -1
    end
  end

  class SliderEvent < KontrolEvent
    attr_reader :index, :value
    def initialize(data)
      @index = data[0] + 1
      @value = data[1]
    end
  end

  class WheelEvent < KontrolEvent
    attr_reader :type, :value
    def initialize(data)
      @type = data[0] == 0 ? :pitch_bend : :mod_wheel
      @value = data[1]
    end
  end

  class PedalEvent < KontrolEvent
    attr_reader :type, :value
    def initialize(data)
      @type = data[0] == 0 ? :assignable_sw : :assignable_pedal
      @value = data[1]
    end
  end

  class JoystickEvent < KontrolEvent
    attr_reader :x, :y
    def initialize(data)
      @x = data[0]
      @y = data[1]
    end
  end
end