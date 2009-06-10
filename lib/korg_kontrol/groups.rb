# Control Modules

module KorgKontrol
  
  include MidiLex::Messages
  
  class GroupManager
    attr_accessor :kontrol, :groups, :current, :midi_out
    
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

    def initialize(options = {})
      # Setup controls
      @controls = {}
      [*options[:controls]].each { |c| add_control c } if options[:controls]
      
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
    attr_accessor :group, :action, :current_values
    
    def initialize(indexes, options = {})
      @action = options.delete(:action)
      @midi_out = options.delete(:midi_out)  
      
      # Set default values. Expand default to multiple selectors if key is an enumerable.
      @current_values = (options.delete(:defaults) || {}).inject({}) do |hash, default| 
        if default[0].respond_to?(:each)
          default[0].each{ |v| hash[v] = default[1] }
        else
          hash[default[0]] = default[1]
        end
        hash
      end
      
      @options = options
    end
    
    def kontrol
      @group.kontrol
    end
    
    def manager
      @group.manager
    end
    
    ### Returns an enumerable containing which selectors this control responds to
    def selectors
      raise "GroupControl#selectors must be implemented by subclasses!"
    end
    
    def activate
      selectors.each { |i| manager.current[key][i] = self }
      display
    end
    
    def display
      selectors.each { |i| display_item i }
    end
    
    ### Attempts to capture and process incoming hardware messages.
    ### If the event is applicable to this control, process it, execute our action (if defined), and display the relevant item.
    ### If not applicable, do not capture it (so it is passed to subsequent controls in Group#capture_event)
    def capture_event(event)
      if selectors.include?(event.selector)
        process_event event
        process_result execute_action(action_parameters(event)) if @action
        display_item event.selector
        true
      end
    end
    
    def action_parameters(event)
      [event, @current_values[event.selector]]
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
      when Core::MidiMessage
        (@options[:midi_out] || manager.midi_out) << result
      end
    end
  end
  
  module LEDControl    
    def display_item(selector)
      kontrol.led selector, @current_values[selector] ? :on : :off, @current_values[selector]
    end
    
    def process_event(event)
      if event.state
        kontrol.led event.selector, :oneshot, @current_values[event.selector]
      end
    end
  end
  
  class SwitchControl < GroupControl
    include LEDControl
    attr_accessor :switches
    
    def initialize(switches, options = {})
      super
      @switches = switches.respond_to?(:to_a) ? switches.to_a : [*switches]
    end
    
    def selectors
      @switches
    end
    
    def key
      SwitchEvent
    end
  end
  
  class SwitchGroupSelect < SwitchControl
    attr_accessor :groups
        
    def initialize(default, groups = {})
      @groups = groups
      @switches = groups.keys
      @current = default
      super @switches, :defaults => { default => :on }
    end
    
    def activate
      super
      activate_group @current
    end
    
    def activate_group(selector)
      @current_values[selector] = true
      kontrol.led selector, :on
      @groups[selector].activate
    end
    
    def process_event(event)
      if event.state        
        if @current
          @last = @current
          @current_values[@last] = false
          kontrol.led @last, :off
        end
        
        @current = event.selector
        activate_group @current
      end
    end
  end
  
  ### Base class for indexable controls, including pads, encoders, and sliders
  ### A single index or any enumberable can be supplied. For example, to encompass all sliders
  ### with one control, you could use a range (1..16); you could also use an array to target
  ### specific indexes (e.g., [1, 5, 9, 13] for all pads in the leftmost column)
  class IndexedControl < GroupControl
    attr_accessor :indexes
    
    def initialize(indexes, options = {})
      super
      @indexes = indexes.respond_to?(:to_a) ? indexes.to_a : [*indexes]
    end
    
    def selectors
      @indexes
    end
  end
  
  class PadControl < IndexedControl
    include LEDControl
    
    def key
      PadEvent
    end
  end
  
  class PadControlSelect < PadControl    
    def process_event(event)
      if event.state
        if @current_values[event.index]
          @last = @current
          @current = event.index
          display_item @last if @last
        end
      end
    end
    
    def display_item(index)
      kontrol.led index, @current_values[index] ? (@current == index ? :blink : :on) : :off, @current_values[index]
    end
  end
  
  class PadControlToggle < PadControl
    def process_event(event)
      if event.state
        @current_values[event.index] = !@current_values[event.index]
      end
    end
    
    def display_item(index)
      kontrol.led index, @current_values[index] ? :on : :off, @options[:color]
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
        kontrol.lcd index, @current_values[index], @options[:color] || :green
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
  
  ### Included automatically by EncoderControl & SliderControl if values are an array.
  ### Transforms the actual numeric value of the control into a position in the array.
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
  
  ### Included automatically by EncoderControl if values are an array. Assists IndexedEnumerableControl module.
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
  
  ### Included automatically by SliderControl if values are an array. Assists IndexedEnumerableControl module.
  module SliderEnumerable
    def process_event(event)
      process_values event.index, (event.value / 128 * @values.size).floor
    end
  end
end