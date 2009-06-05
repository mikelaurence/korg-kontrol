# Control Modules

module KorgKontrol
  
  class GroupManager
    attr_accessor :kontrol, :groups
    attr_reader :current, :last
    
    def initialize
      @groups = []
      @selectors = []
    end
    
    def add_group(group)
      raise "Already managing a group with the selector '#{group.selector}'" if @groups.find{ |g| g.selector == group.selector }
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
      if event.is_a?(ButtonEvent) and selected_group = @groups.find { |g| g.selector == event.selector }
        if event.state
          self.current = selected_group if selected_group != @current
        elsif @current.hold and @last 
          self.current = @last
        end
        return true
      end
      @current.capture_event(event)
    end
    
    def current=(group)
      if @current
        @last = @current
        @kontrol.led @current.selector, :off
      end
      group.activate
      @current = group
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
    
    def add_control(control)
      control.group = self
      @controls[control.class::EVENT_TYPE] ||= []
      @controls[control.class::EVENT_TYPE] << control
    end
    
    def activate
      @kontrol.led @selector, :on, :red
      
      # Reset display for this group's controls
      @controls.each_value do |ctrls|
        ctrls.each { |c| c.display }
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
  end
  
  # Base class for indexable controls, including pads, encoders, and sliders
  # A single index or any enumberable can be supplied. For example, to encompass all sliders
  # with one control, you could use a range (1..16); you could also use an array to target
  # specific indexes (e.g., [1, 5, 9, 13] for all pads in the leftmost column)
  class IndexedControl < GroupControl
    attr_accessor :indexes, :values
    
    def initialize(indexes, options = {})
      @indexes = indexes.respond_to?(:to_a) ? indexes.to_a : [*indexes]
      @options = options
      @values = options.delete(:defaults) || {}
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
    
  end
  
  class IndexedLCDControl < IndexedControl
    attr_accessor :label
    
    def initialize(indexes, options = {})
      super
      @label = options[:label]
      @label_revert_times = {}
      @label_revert_threads = {}
    end
    
    def display_item(index)
      kontrol.lcd index, @label, @options[:color]
    end
    
    def display_item_value(index)
      kontrol.lcd index, @values[index], @options[:color]
      @label_revert_times[index] = Time.now + (@options[:lcd_revert_time] || 1)
      @label_revert_threads[index] = Thread.new do
        while Time.now < @label_revert_times[index]
          sleep 0.1
        end
        display_item index
        @label_revert_threads[index] = nil
        self.terminate
      end unless @label_revert_threads[index]
    end
  end
  
  class PadControl < IndexedControl
    EVENT_TYPE = PadEvent

    def display_item(index)
      kontrol.led index, :oneshot
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
  
  class EncoderControl < IndexedLCDControl
    EVENT_TYPE = EncoderEvent
    
    def initialize(indexes, options = {})
      super
      @min = options[:min] || 0
      @max = options[:max] || 127
      @indexes.each { |i| @values[i] ||= (options[:default] || 0) }
    end
    
    def process_event(event)
      val = @values[event.index] + event.direction
      @values[event.index] = val unless val < @min or val > @max
      display_item_value event.index
      false
    end
  end
end