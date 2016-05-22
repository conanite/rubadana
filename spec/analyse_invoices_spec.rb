require "spec_helper"

describe "analyse invoices" do
  def date str ; Date.parse str ; end

  class Invoice < Aduki::Initializable
    attr_accessor :type, :date, :amount
  end

  class InvoiceMonth < Rubadana::Dimension
    def name                  ; "monthly"                                       ; end
    def group_value_for thing ; Date.new(thing.date.year, thing.date.month, 1)  ; end # rails just use #beginning_of_month
    def value_label_for value ; value.strftime "%B %Y"                          ; end # better with I18n
  end

  class InvoiceYear < Rubadana::Dimension
    def name                  ; "yearly"                                        ; end
    def group_value_for thing ; thing.date.year                                 ; end
    def value_label_for value ; value                                           ; end
  end

  class InvoiceType < Rubadana::Dimension
    def name                  ; "type"                                          ; end
    def group_value_for thing ; thing.type                                      ; end
    def value_label_for value ; value.to_s                                      ; end
  end

  class InvoiceScale < Rubadana::Dimension
    def name                  ; "scale"                                         ; end
    def group_value_for thing ; Math.log(thing.amount, 10).to_i                 ; end
    def value_label_for value ; value                                           ; end
  end

  class InvoiceSum < Rubadana::Summation
    def name            ; "sum-amount" ; end
    def value_for thing ; thing.amount ; end
  end

  class InvoiceAvg < Rubadana::Average
    def name            ; "avg-amount" ; end
    def value_for thing ; thing.amount ; end
  end

  let(:i00) { Invoice.new type: "SalesInvoice"      , date: date("2020-02-01"), amount:     53 }
  let(:i01) { Invoice.new type: "PurchaseInvoice"   , date: date("2021-04-02"), amount:   1100 }
  let(:i02) { Invoice.new type: "SalesCreditNote"   , date: date("2020-02-03"), amount:  23000 }
  let(:i03) { Invoice.new type: "SalesCreditNote"   , date: date("2021-04-04"), amount:   3100 }
  let(:i04) { Invoice.new type: "Quote"             , date: date("2020-05-05"), amount:  43000 }
  let(:i05) { Invoice.new type: "Order"             , date: date("2021-12-06"), amount:     59 }
  let(:i06) { Invoice.new type: "SalesInvoice"      , date: date("2020-02-07"), amount:   6100 }
  let(:i07) { Invoice.new type: "PurchaseInvoice"   , date: date("2022-06-08"), amount:  79000 }
  let(:i08) { Invoice.new type: "PurchaseCreditNote", date: date("2020-05-09"), amount:  83000 }
  let(:i09) { Invoice.new type: "SalesInvoice"      , date: date("2020-05-10"), amount:    990 }
  let(:i10) { Invoice.new type: "SalesInvoice"      , date: date("2022-06-11"), amount:    130 }
  let(:i11) { Invoice.new type: "PurchaseInvoice"   , date: date("2022-12-12"), amount:   1700 }
  let(:i12) { Invoice.new type: "SalesInvoice"      , date: date("2020-11-13"), amount:  19000 }
  let(:i13) { Invoice.new type: "PurchaseCreditNote", date: date("2020-11-14"), amount:     23 }
  let(:i14) { Invoice.new type: "SalesInvoice"      , date: date("2021-04-15"), amount:    110 }
  let(:i15) { Invoice.new type: "SalesInvoice"      , date: date("2022-06-16"), amount: 170000 }

  let(:invoices) { [ i00,i01,i02,i03,i04,i05,i06,i07,i08,i09,i10,i11,i12,i13,i14,i15 ]}
  let(:register) { Rubadana::Registry.new }

  before {
    register.register_dimension   InvoiceYear.new
    register.register_dimension   InvoiceMonth.new
    register.register_dimension   InvoiceType.new
    register.register_dimension   InvoiceScale.new
    register.register_accumulator InvoiceSum.new
    register.register_accumulator InvoiceAvg.new
    register.register_accumulator Rubadana::Counter.new
  }

  it "groups items by month and counts them" do
    program  = register.build ["monthly"], ["count"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).map { |d| [d.value_label] +  d.data.map(&:data) }
    expected = [
                ["February 2020", 3],
                ["May 2020"     , 3],
                ["November 2020", 2],
                ["April 2021"   , 3],
                ["December 2021", 1],
                ["June 2022"    , 3],
                ["December 2022", 1],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and sums them" do
    program  = register.build ["yearly"], ["sum-amount"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).map { |d| [d.value_label] +  d.data.map(&:data) }
    expected = [
                [2020, 175166],
                [2021,   4369],
                [2022, 250830],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and counts them" do
    program  = register.build ["yearly"], ["count"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).map { |d| [d.value_label] +  d.data.map(&:data) }
    expected = [
                [2020, 8],
                [2021, 4],
                [2022, 4],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and averages them" do
    program  = register.build ["yearly"], ["avg-amount"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).map { |d| [d.value_label] +  d.data.map(&:data) }
    expected = [
                [2020, 21895.75],
                [2021,  1092.25],
                [2022, 62707.5 ],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and gives the count, sum, and average" do
    program  = register.build ["yearly"], ["count", "sum-amount", "avg-amount"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).map { |d| [d.value_label] + d.data.map(&:data) }
    expected = [
                [2020, 8, 175166, 21895.75],
                [2021, 4,   4369,  1092.25],
                [2022, 4, 250830, 62707.5 ],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and by type and by scale and counts them" do
    program  = register.build ["yearly", "type"], ["count"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).inject([]) { |arr, d|
      d.data.sort_by(&:group_value).each { |s|
        arr << [d.value_label, s.value_label] + s.data.map(&:data) }
      arr
    }

    expected = [
                [2020 , "PurchaseCreditNote" , 2 ],
                [2020 , "Quote"              , 1 ],
                [2020 , "SalesCreditNote"    , 1 ],
                [2020 , "SalesInvoice"       , 4 ],
                [2021 , "Order"              , 1 ],
                [2021 , "PurchaseInvoice"    , 1 ],
                [2021 , "SalesCreditNote"    , 1 ],
                [2021 , "SalesInvoice"       , 1 ],
                [2022 , "PurchaseInvoice"    , 2 ],
                [2022 , "SalesInvoice"       , 2 ],
               ]
    expect(actual).to eq expected
  end

  it "groups items by scale and by type and sums them" do
    program  = register.build ["scale", "type"], ["sum-amount"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).inject([]) { |arr, d|
      d.data.sort_by(&:group_value).each { |s|
        arr << [d.value_label, s.value_label] +  s.data.map(&:data) }
      arr
    }

    expected = [
                [1 , "Order"              , 59     ] ,
                [1 , "PurchaseCreditNote" , 23     ] ,
                [1 , "SalesInvoice"       , 53     ] ,
                [2 , "SalesInvoice"       , 1230   ] ,
                [3 , "PurchaseInvoice"    , 2800   ] ,
                [3 , "SalesCreditNote"    , 3100   ] ,
                [3 , "SalesInvoice"       , 6100   ] ,
                [4 , "PurchaseCreditNote" , 83000  ] ,
                [4 , "PurchaseInvoice"    , 79000  ] ,
                [4 , "Quote"              , 43000  ] ,
                [4 , "SalesCreditNote"    , 23000  ] ,
                [4 , "SalesInvoice"       , 19000  ] ,
                [5 , "SalesInvoice"       , 170000 ] ]

    expect(actual).to eq expected
  end

  it "groups items by year and by type and by scale and counts them" do
    program  = register.build ["yearly", "type", "scale"], ["sum-amount"]
    data     = program.run(invoices)
    actual   = data.sort_by(&:group_value).inject([]) { |arr, d|
      d.data.sort_by(&:group_value).each { |s|
        s.data.sort_by(&:group_value).each { |z|
          arr << [d.value_label, s.value_label, z.value_label] + z.data.map(&:data) }
      }
      arr
    }

    expected = [
                [2020 , "PurchaseCreditNote" , 1 , 23.0     ],
                [2020 , "PurchaseCreditNote" , 4 , 83000.0  ],
                [2020 , "Quote"              , 4 , 43000.0  ],
                [2020 , "SalesCreditNote"    , 4 , 23000.0  ],
                [2020 , "SalesInvoice"       , 1 , 53.0     ],
                [2020 , "SalesInvoice"       , 2 , 990.0    ],
                [2020 , "SalesInvoice"       , 3 , 6100.0   ],
                [2020 , "SalesInvoice"       , 4 , 19000.0  ],
                [2021 , "Order"              , 1 , 59.0     ],
                [2021 , "PurchaseInvoice"    , 3 , 1100.0   ],
                [2021 , "SalesCreditNote"    , 3 , 3100.0   ],
                [2021 , "SalesInvoice"       , 2 , 110.0    ],
                [2022 , "PurchaseInvoice"    , 3 , 1700.0   ],
                [2022 , "PurchaseInvoice"    , 4 , 79000.0  ],
                [2022 , "SalesInvoice"       , 2 , 130.0    ],
                [2022 , "SalesInvoice"       , 5 , 170000.0 ]
               ]
    expect(actual).to eq expected
  end
end
