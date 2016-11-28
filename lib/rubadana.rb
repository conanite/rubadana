require "rubadana/version"

module Rubadana
  class Registry
    def initialize
      @mappers    = Hash.new
      @reducers   = Hash.new
    end

    def register_mapper       m ; @mappers[m.name.to_sym]  = m                                       ; end
    def register_reducer      r ; @reducers[r.name.to_sym] = r                                       ; end
    def mapper             name ; @mappers[name.to_sym]  || raise("unknown mapper #{name.inspect}")  ; end
    def reducer            name ; @reducers[name.to_sym] || raise("unknown reducer #{name.inspect}") ; end
    def mappers           names ; names.map { |n| mapper n }                                         ; end
    def reducers          names ; names.map { |n| reducer n }                                        ; end
    def build params            ; Programmer.new(params).build(self)                                 ; end
  end

  class Self
    def name           ; :self  ; end
    def map      thing ; thing  ; end
  end

  class Sum
    def name               ; :sum              ; end
    def reduce      things ; things.reduce(:+) ; end
  end

  class Count
    def name          ; :count       ; end
    def reduce things ; things.count ; end
  end

  class CountUnique
    def name          ; :count_unique     ; end
    def reduce things ; things.uniq.count ; end
  end

  class Average
    def name          ; :average                                 ; end
    def reduce things ; things.reduce(:+) / (1.0 * things.count) ; end
  end

  class Analysis < Aduki::Initializable
    attr_accessor :program, :key, :list, :mapped, :reduced
    def key_labels ; key_str = program.group.zip(key).map { |g,k| g.label k } ; end
    def to_s       ; "#{key_labels.join ", "} : #{reduced.join ", "}"            ; end
  end

  class Programmer < Aduki::Initializable
    attr_accessor :group, :map, :reduce
    def build reg
      Program.new group: reg.mappers(group), map: reg.mappers(map), reduce: reg.reducers(reduce)
    end
  end

  class Program < Aduki::Initializable
    attr_accessor :group, :map, :reduce, :groups

    def run things
      self.groups = Hash.new { |h, k| h[k] = [] }
      things.each { |thing|
        groups[group.map { |g| g.map thing }] << thing
      }

      groups.map { |key, things|
        mapped  = map.map  { |m| things.map  { |thing| m.map thing } }
        reduced = reduce.zip(mapped).map { |r, m| r.reduce m           }
        Analysis.new(program: self, key: key, list: things, mapped: mapped, reduced: reduced )
      }
    end
  end
end
