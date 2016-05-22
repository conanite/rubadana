# Rubadana

Rubadana is an elementary ruby data-analysis package. It works with plain old ruby objects, not sql or databases or anything fancy like that.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rubadana'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rubadana

## Usage

See spec for some examples. The basic idea:

1. Create a Registry for your `Dimension` and `Accumulator` instances

my_registry = Rubadana::Registry.new

2. Create and register some `Dimension` instances:

```ruby
  class SaleYear < Rubadana::Dimension
    def name                  ; "yearly"                                        ; end
    def group_value_for thing ; thing.date.year                                 ; end
    def value_label_for value ; value                                           ; end
  end

  my_registry.register_dimension SaleYear.new
```

3. Create and register some `Accumulator` instances:

```ruby
  class SumSaleAmount < Rubadana::Summation
    def name            ; "sum-sale-amount"         ; end
    def value_for thing ; thing.sale_amount         ; end
  end

  my_registry.register_accumulator SumSaleAmount.new
```

4. Build an analysis program and run it:

```ruby
  # this is a program to analyse invoices by year and product, giving the
  # number of sales, the sum of sales and the average sale in each case
  my_program = register.build ["yearly", "invoice-product"], ["count", "sum-sale-amount", "avg-sale-amount"]

  data = my_program.run(invoices)
```

`#run` returns an array of `DataSet` each with the following attributes:

* `analyser`    - a `Dimension` instance
* `group_value` - the common value of this dimension for all objects in this data-set
* `data`        - either an accumulated value given by an accumulator, or a nested array of `DataSet` instances


## Contributing

1. Fork it ( https://github.com/[my-github-username]/rubadana/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
