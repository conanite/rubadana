# Rubadana

Rubadana is an elementary ruby data-analysis package. It works with plain old ruby objects, not sql or databases or anything fancy like that.

The aim is to create a summary overview from a list of objects by basically running a group-by/map/reduce operation on your list. The input, grouping,
mapping, reducing, and display of the result are all independently variable.

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

Here's a trivial example, returning the number of requests per user:

```ruby
  program  = Rubadana::Registry.build groupings: [:user], mappers: [:self], reducers: [:count]
  analysis = program.run Request.all
```

In this example, `:user`, `:self`, and `:count` are plugins you will have provided to rubadana for extracting and manipulating your data.

`analyser.run` returns a list of `Rubadana::Analysis` instances, with, for this example, the following attributes:

|`key`    | a `Hash` instance with keys `:user`                                                         |
|`list`   | the subset of `Request.all` with the corresponding value for `:user`                        |
|`mapped` | in this case, the same as `list` (assuming the `:identity` mapper returns the thing itself) |
|`reduced`| a list of one integers, equal to the size of the list                                       |


In ordinary ruby, you would write `Request.all.group_by(:user).map {|user, requests| [user, requests.count] }` to get the same information.

Here's a richer example which returns the sum of debits, credits, and account balances from a set of accounting transactions:

```ruby
  program = Rubadana::Analyser.new group: [:month, :account_number], map: [:debits, :credits, :balance], reduce: [:sum, :sum, :sum]
  analysis = program.run AccountingTransaction.all
```

In this example, `:month`, `:account_number`, `:debits` and so on, are plugins you will have provided to rubadana for extracting and manipulating your data.

`analyser.run` returns a list of `Rubadana::Analysis` instances, with the following attributes:

|`key`    | a `Hash` instance with keys `:month` and `:account_number`                                                                                       |
|`list`   | the subset of `AccountingTransaction.all` having the corresponding values for `:month` and `:account_number`                                     |
|`mapped` | the output of the `map` operations on `list`. This is a list of n-tuples, where `n` is the number of operations specified by the `map` parameter |
|`reduced`| the output of the `reduce` operations on `mapped`. This is a list of n values, one for each operation specified by the `reduce` parameter.       |

In this example, `reduced` gives us the sum of all debits, the sum of all credits, and the sum of all balances, per account-number

See spec for some examples.

## Steps

1. Create a Registry for your mappers and your reducers

my_registry = Rubadana::Registry.new

2. Create and register some mappers

```ruby
  class SaleYear
    def name        ; :yearly         ; end
    def run  thing  ; thing.date.year ; end
    def label value ; value           ; end
  end

  my_registry.register_mapper SaleYear.new
```

3. Create and register some reducers:

```ruby
  class Sum
    def name          ; :sum             ; end
    def reduce things ; things.reduce :+ ; end
  end

  my_registry.register_reducer Sum.new
```

4. Build an analysis program and run it:

```ruby
  # this is a program to analyse invoices by year and product, giving the
  # number of sales, the sum of sales and the average sale in each case
  my_program = register.build group: %i{ yearly }, map: %i{ self sale_amount sale_amount }, reduce: %i{ count sum average }

  data = my_program.run(invoices)
```

`#run` returns an array of `Rubadana::Analysis` as described above.

## Contributing

1. Fork it ( https://github.com/conanite/rubadana/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
