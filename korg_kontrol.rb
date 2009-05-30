# KorgKontrol - Ruby-based native mode Control for Korg's Kontrol49 and MicroKontrol (and PadKontrol, eventually!)
# Copyright (c) 2009 Mike Laurence
# Released under the MIT License
#
# Requires very little in terms of MIDI interface so far:
# midi_out must have a #sysex method which accepts an array of bytes
# midi_in must return new midi data via #new_data? method, returning objects with a #data accessor to their byte arrays (based on rbcoremidi)
# (I will be adding LiveMIDI and rbcoremidi to the repo eventually so you can get it up and running quickly, though only on Mac OS for now)
#
# Documentation and examples also forthcoming.
#
# Let me know if you stumble across this and you're desperate for it to work immediately! In that case, I'll put a little extra effort in :-)

module KorgKontrol
  
  HEADER = [0xf0, 0x42, 0x40, 0x6e]
  KONTROL_49_HEADER = [0x02]
  MICRO_KONTROL_HEADER = [0]
  
  NATIVE_MODE_ON = [0, 0, 0x01]
	NATIVE_MODE_OFF = [0, 0, 0]
	
	STATE_OFF = 0
	STATE_ON = 32
	STATE_ONESHOT = 64
	STATE_BLINK = 96
	
	LED_STATES = { :off => 0, :on => 32, :oneshot => 64, :blink => 96 }
	LED_COLORS = { :red => [true, false], :green => [false, true], :orange => [true, true] }
	LCD_COLORS = { :off => 0, :red => 1 << 4, :green => 2 << 4, :orange => 3 << 4}

  SWITCH_INPUT_VALUES = [:previous, :next, :enter, :hex_lock, :exit, :scene, :message, :setting, :sw1, :sw2]
  
  class Kontroller
    
    attr_reader :managers
    
    def initialize(midi_out, midi_in, sysex_header)
      @midi_out = midi_out
      @midi_in = midi_in
      @sysex_header = sysex_header
      @managers = []
      
      @pad_ids = {
        :setting => 0x10,
        :message => 0x11,
      	:scene => 0x12,
      	:exit => 0x13,
      	:hex_lock => 0x15,
      	:enter => 0x14,
      	:tempo => 0x16,
      	:next => 0x18,
      	:previous => 0x19
      }.merge((1..16).inject({}){ |h, p| h["pad_#{p}".to_sym] = h[p] = p - 1; h })
      
    end
    
    def method_missing(method, *args)
      #constant = Object.module_eval(method.to_s.upcase)
      #send_sysex constant
      puts "Methmiss: #{method.class} #{args.inspect}"
    end
    
    def native_mode_on
      send_sysex NATIVE_MODE_ON
      clear_all
    end
    
    def native_mode_off
      send_sysex NATIVE_MODE_OFF
    end
    
    def clear_all
      [
        [0x3F, 0x27, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0x3F, 0x12, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 32, 32, 32, 32, 32, 32, 32],
        [ 0x3F, 0x21, 2, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32],
        [0x3F, 0x21, 3, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32]
      ].each { |data| send_sysex data }
    end
    
    def led(pad, state, color = :red)
      p = @pad_ids[pad]
      multicolor = p < 16 or p == :previous or p == :next
      c = LED_COLORS[color] || LED_COLORS[:red]
      send_sysex [1, @pad_ids[pad], (!multicolor or c[0]) ? LED_STATES[state] : 0]
      send_sysex [1, @pad_ids[pad] + 32, c[1] ? LED_STATES[state] : 0] if multicolor
    end
    
    def lcd(index, text, color = :red)
      send_sysex [0x22, 0x09] + [((LCD_COLORS[color] || 0) | index)] + (0..7).collect{ |c| text[c] || 32 }
    end
        
    def send_sysex(data)
      #puts "Kontrol out: #{data.join(' ')}"
      @midi_out.sysex @sysex_header + data + [0xf7]
    end
    
    def capture_midi
      return nil unless events = @midi_in.new_data?
      events = events.collect do |event|
        data = event.data[6..-2]
        case event.data[5]
        when 0x40
          NativeModeEvent.new data
        when 0x43
          EncoderEvent.new data
        when 0x44
          SliderEvent.new data
        when 0x45
          PadEvent.new data
        when 0x46
          WheelEvent.new data
        when 0x47
          PedalEvent.new data
        when 0x48
          SwitchEvent.new data
        when 0x4b
          JoystickEvent.new data
        else
          KontrolEvent.new data
        end
      end
      
      events.reject do |e|
        @managers.find { |m| m.capture_event(e) }
      end
      
    end
    
    def set_state(states)
      states.each_pair do |key, value|
        # If a pad, send an LED message
        if pad_id = @pad_ids[key]
          led key, value == :off ? :off : :on, value
        end
      end
    end
    
    def add_manager(manager)
      manager.kontrol = self
      @managers << manager
      manager
    end
    
    def self.flatten(selectors)
      selectors = [*selectors]
      selectors += (1..16).to_a if selectors.delete(:pads)   # Add all pads if the symbol :pads is present
    end
  end
  
  
  # Main controller subclasses
  
  class Kontrol49 < Kontroller
    def initialize(midi_out, midi_in)
      super midi_out, midi_in, HEADER + KONTROL_49_HEADER
    end
  end
  
  class MicroKontrol < Kontroller
    def initialize(midi_out, midi_in)
      super midi_out, midi_in, HEADER + MICRO_KONTROL_HEADER
    end
  end
  
  
  # Control Modules
  
  class GroupManager
    attr_accessor :kontrol, :groups
    attr_reader :current
    
    def initialize
      @groups = []
      @selectors = []
    end
    
    def add_group(group)
      group.kontrol = @kontrol
      group.manager = self
      @groups << group
      group
    end
    
    def activate
      @groups.each do |g|
        g.activate
      end
    end
    
    def capture_event(event)
      if event.is_a?(ButtonEvent)
        if selected_group = @groups.find { |g| g.selector == event.selector }
          self.current = selected_group if event.state and selected_group != @current
          true
        else
          @current.capture_event(event)
        end
      end
    end
    
    def current=(group)
      @kontrol.led @current.selector, :off if @current
      group.activate
      @current = group
    end
    
  end
  
  class Group
    attr_accessor :kontrol, :manager, :selector, :members
    def initialize(selector, members, options = {})
      @selector = selector
      
      @members = Kontroller.flatten(members)
      @clears = @members.inject({}) { |memo, member| memo[member] = :off; memo }
      
      @values = @clears.merge(options.delete(:initial_values) || {})
    end
    
    def activate
      @kontrol.set_state @values
      @kontrol.led @selector, :on, :green
    end
    
    def capture_event(event)
      if @members.include?(event.selector)
        true
      end
    end
  end
  
  
  # MIDI input events
  
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