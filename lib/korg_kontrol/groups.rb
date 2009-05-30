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
      if event.is_a?(ButtonEvent)
        if selected_group = @groups.find { |g| g.selector == event.selector }
          if event.state
            self.current = selected_group if selected_group != @current
          elsif @current.hold and @last 
            self.current = @last
          end
          true
        else
          @current.capture_event(event)
        end
      end
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
      #@clears = @members.inject({}) { |memo, member| memo[member] = :off; memo }
      
      # Setup options
      @hold = options[:hold]
      #@values = @clears.merge(options[:initial_values] || {})
    end
    
    def add_control(control)
      control.group = self
      @controls[control.class::EVENT_TYPE] ||= []
      @controls[control.class::EVENT_TYPE] << control
    end
    
    def activate
      @kontrol.set_state @values
      @kontrol.led @selector, :on, :red
    end
    
    def capture_event(event)
      @controls[event.class].find{ |c| c.capture_event(event) }
    end
  end
  
  class GroupControl
    attr_accessor :group
    
    def kontrol
      @group.kontrol
    end
  end
  
  class PadControl < GroupControl
    EVENT_TYPE = PadEvent
    attr_accessor :indexes
    
    def initialize(indexes, options = {})
      @indexes = indexes
      @options = options
      @values = {}
    end
    
    def capture_event(event)
      if @indexes == event.index or (@indexes.respond_to?(:include?) and @indexes.include?(event.index))
        p = process_event(event)
        display event.index
        p
      end
    end
    
    def process_event(event)
      true
    end
    
    def display(index)
      kontrol.led index, :oneshot
    end
  end
  
  class PadControlToggle < PadControl
    def process_event(event)
      if event.state
        @values[event.index] = !@values[event.index]
      end
    end
    
    def display(index)
      kontrol.led index, @values[index] ? :on : :off, @options[:color]
    end
  end
end