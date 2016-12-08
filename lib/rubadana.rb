require "rubadana/version"

module Rubadana
  class Registry
    def initialize
      @mappers    = Hash.new
      @reducers   = Hash.new
      @programs   = Hash.new
    end

    def register_mapper       m ; @mappers[m.name.to_sym]  = m                                       ; end
    def register_reducer      r ; @reducers[r.name.to_sym] = r                                       ; end
    def register_program      p ; @programs[p.name.to_sym] = p                                       ; end
    def mapper             name ; @mappers[name.to_sym]  || raise("unknown mapper #{name.inspect}")  ; end
    def reducer            name ; @reducers[name.to_sym] || raise("unknown reducer #{name.inspect}") ; end
    def mappers           names ; names.map { |n| mapper n }                                         ; end
    def reducers          names ; names.map { |n| reducer n }                                        ; end
    def build            params ; Factory.new(params).build(self)                                    ; end
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

  class Overview < Aduki::Initializable
    attr_accessor :key_values, :data, :program
  end

  class Analysis < Aduki::Initializable
    attr_accessor :program, :key, :list, :mapped, :reduced
    def key_labels     ; program.group.zip(key).map { |g,k| g.label k }   ; end
    def reduced_labels ; program.map.zip(reduced).map { |m,r| m.label r } ; end
    def to_s           ; "#{key_labels.join ", "} : #{reduced.join ", "}" ; end
  end

  class Factory < Aduki::Initializable
    attr_accessor :name, :group, :map, :reduce
    def build reg
      (0..group.size).map { |c| group.combination(c).to_a }.reduce(:+).inject({}) { |h, g|
        h[g] = Programmer.new(factory: self, group: g, map: map, reduce: reduce).build reg
        h
      }
    end
  end

  class Programmer < Aduki::Initializable
    attr_accessor :factory, :group, :map, :reduce
    def build reg
      Program.new programmer: self, group: reg.mappers(group), map: reg.mappers(map), reduce: reg.reducers(reduce)
    end
  end

  class Program < Aduki::Initializable
    attr_accessor :programmer, :group, :map, :reduce, :groups

    def run things
      self.groups = Hash.new { |h, k| h[k] = [] }
      things.each { |thing|
        groups[group.map { |g| g.map thing }] << thing
      }

      h = groups.keys.inject({ }) { |hsh, key|
        mapped  = map.map  { |m|
          groups[key].map  { |thing|
            m.map thing
          }
        }
        reduced = reduce.zip(mapped).map { |r, m| r.reduce m           }
        hsh[key] = Analysis.new(program: self, key: key, list: things, mapped: mapped, reduced: reduced )
        hsh
      }

      distinct_key_values = (0...group.size).map { |i|
        h.values.map { |v|
          v.key[i]
        }
      }

      Overview.new key_values: distinct_key_values, data: h, program: self
    end
  end
end
