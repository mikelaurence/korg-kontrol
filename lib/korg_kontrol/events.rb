# Korg Kontrol events (MIDI input)
module KorgKontrol

  class KontrolEvent
    attr_reader :data
    def initialize(data)
      @data = data
    end
    
    def initialize_from_hash(data)
      data.each_pair do |key, value|
        instance_variable_set "@#{key}", value
      end
    end
    
    def selector
      :default
    end
  end

  class NativeModeEvent < KontrolEvent
  end
  
  class IndexedEvent < KontrolEvent
    attr_reader :index
    alias selector index
    def selector
      @index
    end
  end
  
  class TypedEvent < KontrolEvent
    attr_reader :type
    alias selector type
    def selector
      @type
    end
  end

  class PadEvent < IndexedEvent
    attr_accessor :state, :velocity
    def initialize(data)
      if data.is_a?(Hash)
        initialize_from_hash(data)
      else
        @index = (data[0] & 15) + 1
        @state = data[0] > 15
        @velocity = data[1]
      end
    end
    
    def to_s
      "[PadEvent index: #{@index}, state: #{@state}, velocity: #{@velocity}]"
    end
  end

  class SwitchEvent < TypedEvent
    attr_reader :state, :type
    def initialize(data)
      if data.is_a?(Hash)
        initialize_from_hash(data)
      else
        @type = SWITCH_INPUT_VALUES[data[0]]
        @state = data[1] == 127
      end
    end

    def to_s
      "[SwitchEvent type: #{@type}, state: #{@state}]"
    end
  end

  class EncoderEvent < IndexedEvent
    attr_reader :direction
    def initialize(data)
      @index = data[0] + 1
      @direction = data[1] < 64 ? 1 : -1
    end
  end

  class SliderEvent < IndexedEvent
    attr_reader :value
    def initialize(data)
      @index = data[0] + 1
      @value = data[1]
    end
  end

  class WheelEvent < TypedEvent
    attr_reader :value
    def initialize(data)
      @type = data[0] == 0 ? :pitch_bend : :mod_wheel
      @value = data[1]
    end
  end

  class PedalEvent < TypedEvent
    attr_reader :value
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