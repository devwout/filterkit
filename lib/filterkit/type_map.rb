module Filterkit
  class TypeMap
    def initialize
      @map = {}
      @raw_map = {}
    end
    
    def [](type)
      instantiate_types
      @map[Types.lookup(type)]
    end
    
    def []=(type, args)
      @raw_map[type] = args
    end
    
    private
    
    def instantiate_types
      return if @raw_map.empty?
      @raw_map.each do |type, args|
        @map[Types.lookup(type)] = args.map {|arg| Types.lookup(arg)}.freeze
      end
      unless defined?(::Rails) and not ::Rails.configuration.cache_classes
        @raw_map.clear
      end
    end
  end
end