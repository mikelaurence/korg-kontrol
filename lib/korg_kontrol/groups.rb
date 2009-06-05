# Control Modules

module KorgKontrol
  
  class GroupManager
    attr_accessor :kontrol, :groups, :current
    
    def initialize(options = {})
      @midi_out = options[:midi_out]
      @groups = []
      @selectors = []
      
      # Setup hash for active controls
      @current = [PadEvent, SwitchEvent, EncoderEvent, SliderEvent, WheelEvent, PedalEvent, JoystickEvent, KontrolEvent, NativeModeEvent, LCDControl].inject({}) do |hash, event|
        hash[event] = {}; hash
      end
    end
    
    def add_group(group)
      #raise "Already managing a group with the selector '#{group.selector}'" if @groups.find{ |g| g.selector == group.selector }
      group.kontrol = @kontrol
      group.manager = self
      @groups << group
      group
    end
    
    def capture_event(event)
      #if event.is_a?(ButtonEvent) and selected_group = @groups.find { |g| g.selector == event.selector }
      #  if event.state
      #    self.current = selected_group if selected_group != @current
      #  elsif @current.hold and @last 
      #    self.current = @last
      #  end
      #  return true
      #end
      if ctrl = @current[event.class][event.selector]
        ctrl.capture_event event
      end
    end
    
    def lcd_revert(index, time)
      if lcd = current[LCDControl][index]
        lcd.revert_in index, time
      end
    end
    
  end
  
  class Group
    attr_accessor :kontrol, :manager, :selector, :controls, :hold

    def initialize(selector, options = {})
      @selector = selector
      
      # Setup controls
      @controls = {}
      options[:controls].each { |c| add_control c } if options[:controls]
      
      # Setup options
      @hold = options[:hold]
    end
    
    def current?
      @manager.current = self
    end
    
    def add_control(control)
      control.group = self
      @controls[control.key] ||= []
      @controls[control.key] << control
    end
    
    def activate
      #@kontrol.led @selector, :on, :red
      
      # Activate group's controls
      @controls.each_value do |ctrls|
        ctrls.each { |c| c.activate }
      end
    end
        
    def capture_event(event)
      @controls[event.class].find{ |c| c.capture_event(event) } if @controls[event.class]
    end
    
  end
  
  class GroupControl
    attr_accessor :group, :action
    
    def initialize(indexes, options = {})
      @options = options
      @midi_out = options[:midi_out]
    end
    
    def kontrol
      @group.kontrol
    end
    
    def manager
      @group.manager
    end
    
    def execute_action(params)
      if @action.is_a?(Proc)
        @action.call *params
      else
        @action
      end
    end

    def process_result(result)
      case result
      when Enumerable
        result.each { |e| process_result e }
      when MidiMix::MidiMessage
        @options[:midi_out] || manager.midi_out << result
      end
    end
  end
  
  ### Base class for indexable controls, including pads, encoders, and sliders
  ### A single index or any enumberable can be supplied. For example, to encompass all sliders
  ### with one control, you could use a range (1..16); you could also use an array to target
  ### specific indexes (e.g., [1, 5, 9, 13] for all pads in the leftmost column)
  class IndexedControl < GroupControl
    attr_accessor :indexes, :current_values
    
    def initialize(indexes, options = {})
      super
      @indexes = indexes.respond_to?(:to_a) ? indexes.to_a : [*indexes]
      
      # Set default values. Expand default to multiple indexes if key is an enumerable.
      @current_values = (options.delete(:defaults) || {}).inject({}) do |hash, default| 
        if default[0].respond_to?(:each)
          default[0].each{ |v| hash[v] = default[1] }
        else
          hash[default[0]] = default[1]
        end
        hash
      end
    end
    
    def capture_event(event)
      if @indexes.include?(event.index)
        process_event event
        process_result execute_action(action_parameters(event)) if @action
        display_item event.index
        true
      end
    end
    
    def display
      @indexes.each { |i| display_item i }
    end
    
    def activate
      @indexes.each { |i| manager.current[key][i] = self }
      display
    end
    
  end
  
  class PadControl < IndexedControl
    def display_item(index)
      kontrol.led index, :oneshot
    end
    
    def key
      PadEvent
    end
  end
  
  class PadControlToggle < PadControl
    def process_event(event)
      if event.state
        @current_values[event.index] = !@current_values[event.index]
        true
      end
    end
    
    def display_item(index)
      kontrol.led index, @current_values[index] ? :on : :off, @options[:color]
    end
    
    def action_parameters(event)
      [event.index, @current_values[event.index]]
    end
  end
  
  
  # LCDs & indexed labeled controls
  
  class LCDControl < IndexedControl
    attr_accessor :label
    
    def initialize(indexes, options = {})
      super
      @label_revert_times = {}
      @label_revert_threads = {}
    end
    
    def display_item(index)
      kontrol.lcd index, @current_values[index], @options[:color]
    end
    
    def revert_in(index, time)
      @label_revert_times[index] = Time.now + time
      @label_revert_threads[index] = Thread.new do
        while Time.now < @label_revert_times[index]
          sleep 0.1
        end
        display_item index
        @label_revert_threads[index] = nil
        self.terminate
      end unless @label_revert_threads[index]
    end
    
    def key
      LCDControl
    end
  end
  
  class IndexedLabeledControl < IndexedControl
    attr_accessor :values
    
    def initialize(indexes, options = {})
      super
      
      @values = options[:values] || (0..127)
      raise "[IndexedLabeledControl] Values must be a range or an array" unless @values.is_a?(Range) or @values.is_a?(Array)
      if @values.is_a?(Array)
        extend IndexedEnumerableControl
        extend key == EncoderEvent ? EncoderEnumerable : SliderEnumerable
      end

      init_defaults
    end

    def init_defaults
      @indexes.each { |i| @current_values[i] = @options[:default] || 0 }
    end
    
    def display_item(index)
      if @options[:display] != false
        kontrol.lcd index, @current_values[index], @options[:color]
        manager.lcd_revert index, @options[:lcd_revert_time] || 1 unless @options[:revert_lcd] = false
      end
    end
  end

  class EncoderControl < IndexedLabeledControl    
    def process_event(event)
      idx = @current_values[event.index] + event.direction * (@options[:speed] || 1)
      @current_values[event.index] = idx unless idx < @values.min or idx > @values.max
    end
    
    def key
      EncoderEvent
    end
  end
  
  class SliderControl < IndexedLabeledControl
    def process_event(event)
      @current_values[event.index] = @values.min + (event.value / 127.0 * (@values.max - @values.min))
      @current_values[event.index] = @current_values[event.index].to_i if @options[:format] == :integer
    end
    
    def key
      SliderEvent
    end
  end
  
  module IndexedEnumerableControl
    def init_defaults
      @current_value_indexes = {}
      @indexes.each do |i|
        i = @current_value_indexes[i] = @values.index(@options[:default]) || 0
        @current_values[i] = @values[i]
      end      
    end
    
    def process_values(control_index, value_index)
      @current_value_indexes[control_index] = value_index
      @current_values[control_index] = @values[value_index]
    end
  end
  
  module EncoderEnumerable
    def process_event(event)
      idx = @current_value_indexes[event.index] + event.direction;
      if (idx >= @values.size)
        idx = @options[:cycle] ? 0 : @values.size - 1
      elsif (idx < 0)
        idx = @options[:cycle] ? @values.size - 1 : 0
      end
      
      process_values event.index, idx
    end
  end
  
  module SliderEnumerable
    def process_event(event)
      process_values event.index, (event.value / 128 * @values.size).floor
    end
  end
end