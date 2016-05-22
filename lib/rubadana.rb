require "rubadana/version"

module Rubadana
  class Registry
    def initialize
      @dimensions   = Hash.new
      @accumulators = Hash.new
    end

    def register_dimension    d ; @dimensions[d.name.to_sym]   = d                             ; end
    def register_accumulator  a ; @accumulators[a.name.to_sym] = a                             ; end
    def dimensions              ; @dimensions.values                                           ; end
    def accumulators            ; @accumulators.values                                         ; end
    def not_nil attr, hsh, name ; hsh[name.to_sym] || raise("unknown #{attr} #{name.inspect}") ; end
    def dimension          name ; not_nil "dimension"  , @dimensions  , name                   ; end
    def accumulator        name ; not_nil "accumulator", @accumulators, name                   ; end

    def build dnames, anames
      dd = dnames.compact.map { |n| dimension   n }
      aa = anames.compact.map { |n| accumulator n }
      Program.new(dd + aa)
    end
  end

  class DataSet < Aduki::Initializable
    attr_accessor :analyser, :group_value, :data
    def value_label ; analyser.value_label_for group_value ; end
  end

  class Accumulator
    def name              ; raise "implement this and return a unique name for this accumulator"        ; end
    def accumulate things ; raise "implement this and return a value extracted from #things"            ; end
    def run things, after ; [DataSet.new(analyser: self, data: accumulate(things))] + after.run(things) ; end
  end


  class Summation < Accumulator
    def value_for   thing ; raise "implement this and return a value extracted from #thing"       ; end
    def accumulate things ; things.map { |thing| value_for(thing) }.reduce :+                     ; end
  end

  class Counter < Accumulator
    def name              ; "count"           ; end
    def accumulate things ; things.uniq.count ; end
  end

  class Average < Summation
    def accumulate things ; super / (1.0 * things.count) ; end
  end

  class Dimension
    def name                  ; raise "implement this and return a unique name for this dimension"    ; end
    def group_value_for thing ; raise "implement this and return a value extracted from #thing"       ; end
    def value_label_for value ; raise "implement this to return a display value for #{value.inspect}" ; end

    def run objects, after
      objects.group_by { |obj| group_value_for obj }.map { |value, list|
        DataSet.new analyser: self, group_value: value, data: after.run(list)
      }
    end
  end

  class Program
    attr_accessor :dimension, :after

    def initialize dimensions
      if dimensions
        self.dimension = dimensions.first
        self.after = Program.new dimensions[1..-1]
      end
    end

    def run objects
      dimension ? dimension.run(objects, after) : []
    end
  end
end
