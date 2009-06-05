# Control Modules

module KorgKontrol
  
  class GroupManager
    attr_accessor :kontrol, :groups, :current
    
    def initialize
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
    attr_accessor :group
    
    def kontrol
      @group.kontrol
    end
    
    def manager
      @group.manager
    end
  end
  
  ### Base class for indexable controls, including pads, encoders, and sliders
  ### A single index or any enumberable can be supplied. For example, to encompass all sliders
  ### with one control, you could use a range (1..16); you could also use an array to target
  ### specific indexes (e.g., [1, 5, 9, 13] for all pads in the leftmost column)
  class IndexedControl < GroupControl
    attr_accessor :indexes, :values
    
    def initialize(indexes, options = {})
      @indexes = indexes.respond_to?(:to_a) ? indexes.to_a : [*indexes]
      @options = options
      
      # Set default values. Expand default to multiple indexes if key is an enumerable.
      @values = (options.delete(:defaults) || {}).inject({}) do |hash, default| 
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
        if process_event(event)
          display_item event.index
        end
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
        @values[event.index] = !@values[event.index]
        true
      end
    end
    
    def display_item(index)
      kontrol.led index, @values[index] ? :on : :off, @options[:color]
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
      kontrol.lcd index, @values[index], @options[:color]
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
    def initialize(indexes, options = {})
      super
      
      @min = options[:min] || 0
      @max = options[:max] || 127
      @indexes.each { |i| @values[i] ||= (options[:default] || 0) }
    end
    
    def display_item(index)
      kontrol.lcd index, @label, @options[:color]
    end
    
    def display_item_value(index)
      kontrol.lcd index, @values[index], @options[:color]
      manager.lcd_revert index, @options[:lcd_revert_time] || 1
    end
  end

  class EncoderControl < IndexedLabeledControl    
    def process_event(event)
      val = @values[event.index] + event.direction
      @values[event.index] = val unless val < @min or val > @max
      display_item_value event.index
      false
    end
    
    def key
      EncoderEvent
    end
  end
  
  class SliderControl < IndexedLabeledControl
    def process_event(event)
      @values[event.index] = @min + (event.value / 127.0 * (@max - @min))
      @values[event.index] = @values[event.index].to_i if @options[:format] == :integer
      display_item_value event.index
      false
    end
    
    def key
      SliderEvent
    end
  end
end