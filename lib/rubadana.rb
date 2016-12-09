require "rubadana/version"

module Rubadana
  TOTAL = :__total__

  class Named < Aduki::Initializable
    attr_accessor :type
    aduki_initialize :hsh, Hash
    def lookup       k ; hsh[k] || raise("unknown #{type} : #{k.inspect}") ; end
    def []           k ; k && lookup(k.to_sym)                             ; end
    def []=       k, v ; hsh[k.to_sym] = v                                 ; end
    def find     names ; names.map { |n| self[n] }                         ; end
    def register thing ; self[thing.name] = thing                          ; end
  end

  class Registry
    attr_accessor :mappers, :reducers, :factories

    def initialize
      @mappers    = Named.new(type: :mapper)
      @reducers   = Named.new(type: :reducer)
      @factories  = Named.new(type: :factory)
    end

    def build        params ; Factory.new(params).build(self)                   ; end
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
    def merge other
      kv = key_values.zip(other.key_values).map { |kv0, kv1| kv0 + kv1 }
      d  = data.merge(other.data)
      self.class.new key_values: kv, data: d, program: program
    end
  end

  class Analysis < Aduki::Initializable
    attr_accessor :program, :key, :list, :mapped, :reduced
    def key_labels     ; program.group.zip(key).map { |g,k| g ? g.label(k) : TOTAL }   ; end
    def reduced_labels ; program.map.zip(reduced).map { |m,r| m.label r }              ; end
    def to_s           ; "#{key_labels.join ", "} : #{reduced.join ", "}"              ; end
  end

  class Factory < Aduki::Initializable
    attr_accessor :name, :group, :map, :reduce
    def combinations
      (0...(2**group.size)).map { |i|
        i = i.to_s(2).rjust(group.size, "0").split(//).map(&:to_i)
        (0...group.size).map { |g| i[g] == 1 ? group[g] : nil }
      }
    end

    def build reg
      combinations.inject({}) { |h, g|
        h[g] = Programmer.new(factory: self, group: g, map: map, reduce: reduce).build reg
        h
      }
    end

    def grid registry, things
      build(registry).values.map { |prog| prog.run things }.reduce :merge
    end
  end

  class Programmer < Aduki::Initializable
    attr_accessor :factory, :group, :map, :reduce
    def build reg
      Program.new programmer: self, group: reg.mappers.find(group), map: reg.mappers.find(map), reduce: reg.reducers.find(reduce)
    end
  end

  class Program < Aduki::Initializable
    attr_accessor :programmer, :group, :map, :reduce, :groups

    def group_key mapper, thing
      mapper ? mapper.map(thing) : TOTAL
    end

    def run things
      self.groups = Hash.new { |h, k| h[k] = [] }
      things.each { |thing|
        groups[group.map { |g| group_key(g, thing) }] << thing
      }

      h = groups.keys.inject({ }) { |hsh, key|
        mapped  = map.map  { |m| groups[key].map { |thing| m.map thing } }
        reduced = reduce.zip(mapped).map { |r, m| r.reduce m }
        hsh[key] = Analysis.new(program: self, key: key, list: things, mapped: mapped, reduced: reduced )
        hsh
      }

      distinct_key_values = (0...group.size).map { |i|
        Set.new(h.values.map { |v| v.key[i] })
      }

      Overview.new key_values: distinct_key_values, data: h, program: self
    end
  end
end
