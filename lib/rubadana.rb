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
    def each    &block ; hsh.each &block                                   ; end
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

  class Latest < Aduki::Initializable
    attr_accessor :attribute
    def name          ; :newest                           ; end
    def reduce things ; things.sort_by(&attribute).last   ; end
  end

  class Grid < Aduki::Initializable
    attr_accessor :key_values, :data, :factory, :registry
    def merge more_key_values, more_data
      self.key_values = key_values.zip(more_key_values).map { |kv0, kv1| kv0 + kv1 }
      self.data       = data.merge(more_data)
      self
    end
    def normal_sort        a, b ; a.nil? ? -1 : (b.nil? ? 1 : a <=> b)                   ; end
    def total_sort         a, b ; a == TOTAL ? 1 : (b == TOTAL ? -1 : normal_sort(a, b)) ; end
    def keys                  i ; key_values[i].to_a.sort { |a, b| total_sort a, b }     ; end
    def group_label    i, value ; registry.mappers[factory.group[i]].label value         ; end
    def reduced_label  i, value ; registry.mappers[factory.map[i]]  .label value         ; end
    def reducer_count           ; factory.reduce.size                                    ; end
    def values_at          keys ; data[keys]                                             ; end
  end

  class Analysis < Aduki::Initializable
    attr_accessor :program, :key, :list, :mapped, :reduced
    def key_labels     ; program.group.zip(key).map { |g,k| g ? g.label(k) : TOTAL }   ; end
    def reduced_labels ; program.map.zip(reduced).map { |m,r| m.label r }              ; end
    def to_s           ; "#{key_labels.join ", "} : #{reduced.join ", "}"              ; end
  end

  class Factory < Aduki::Initializable
    attr_accessor :group, :map, :reduce, :present

    def name ; group.join('_') ; end

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
      grid = Grid.new factory: self, key_values: [Set.new] * group.size, data: { }, registry: registry
      build(registry).values.map { |prog| prog.run things, grid }
      grid
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

    def run things, grid
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

      grid.merge distinct_key_values, h
    end
  end
end
