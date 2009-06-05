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
  
  HEADER = [0x42, 0x40, 0x6e]
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
    
    LCD_SIZE = 8  # TODO: Is this different for MicroKontrol or PadKontrol?
    
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
      	:previous => 0x19,
      	:sw1 => 0x20,
      	:sw2 => 0x21
      }.merge((1..16).inject({}){ |h, p| h["pad_#{p}".to_sym] = h[p] = p - 1; h })
      
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
    
    def lcd(index, text, color = :red, justification = :centered)
      text_s = text.to_s
      if justification == :centered
        pad = (LCD_SIZE - text_s.size) / 2.0
        text_s = "#{' ' * pad.floor}#{text_s}#{' ' * pad.ceil}"
      end
      byte_method = text_s.respond_to?(:getbyte) ? :getbyte : :[] # Necessary because MacRuby string#[] doesn't return the byte code
      send_sysex [0x22, 0x09] + [((LCD_COLORS[color] || 0) | index - 1)] + (0..7).collect{ |n| text_s.send(byte_method, n) || 32 }
    end
        
    def send_sysex(data)
      @midi_out.sysex @sysex_header + data
    end
    
    def capture(message)
      data = message.data[5..-1]
      event = case message.data[4]
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
    
      @managers.find { |m| m.capture_event(event) } ? nil : event
    end
    
    def set_state(states)
      states.each_pair do |key, value|
        # If a pad, send an LED message
        if pad_id = @pad_ids[key]
          led key, value == :off ? :off : :on, value
        end
      end if states
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
  
end