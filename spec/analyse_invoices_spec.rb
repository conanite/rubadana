require "spec_helper"

describe "analyse invoices" do
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
    register.register_mapper  InvoiceYear.new
    register.register_mapper  InvoiceMonth.new
    register.register_mapper  InvoiceType.new
    register.register_mapper  InvoiceScale.new
    register.register_mapper  InvoiceAmount.new
    register.register_mapper  Rubadana::Self.new
    register.register_reducer Rubadana::Sum.new
    register.register_reducer Rubadana::Average.new
    register.register_reducer Rubadana::Count.new
  }

  it "groups items by month and counts them" do
    programs = register.build group: %i{ monthly }, map: %i{ self }, reduce: %i{ count }
    global_prog = programs[[]]
    detail_prog = programs[%i{ monthly }]

    global    = global_prog.run invoices
    detail    = detail_prog.run invoices

    actual   = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [ [ 16 ] ]
    expect(actual).to eq expected

    actual   = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
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
    programs  = register.build group: %i{ yearly }, map: %i{ invoice_amount }, reduce: %i{ sum }

    global_prog = programs[[]]
    detail_prog = programs[%i{ yearly }]

    global    = global_prog.run invoices
    detail    = detail_prog.run invoices

    actual    = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected  = [ [430365] ]
    expect(actual).to eq expected

    actual    = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected  = [
                 [2020, 175166],
                 [2021,   4369],
                 [2022, 250830],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and counts them" do
    programs  = register.build group: %i{ yearly }, map: %i{ self }, reduce: %i{ count }

    global_prog = programs[[]]
    detail_prog = programs[%i{ yearly }]

    global    = global_prog.run invoices
    detail    = detail_prog.run invoices

    actual    = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [ [ 16 ] ]
    expect(actual).to eq expected

    actual    = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [2020, 8],
                [2021, 4],
                [2022, 4],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and averages them" do
    programs  = register.build group: %i{ yearly }, map: %i{ invoice_amount }, reduce: %i{ average }
    global_prog = programs[[]]
    detail_prog = programs[%i{ yearly }]

    global    = global_prog.run invoices
    detail    = detail_prog.run invoices

    actual   = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [ [ 26897.8125 ] ]
    expect(actual).to eq expected

    actual   = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [2020, 21895.75],
                [2021,  1092.25],
                [2022, 62707.5 ],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and gives the count, sum, and average" do
    programs     = register.build group: %i{ yearly }, map: %i{ invoice_amount invoice_amount invoice_amount }, reduce: %i{ count sum average }
    global_prog  = programs[[]]
    detail_prog  = programs[%i{ yearly }]
    global       = global_prog.run invoices
    detail       = detail_prog.run invoices

    actual   = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [ [ 16, 430365, 26897.8125 ] ]
    expect(actual).to eq expected

    actual   = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [2020, 8, 175166, 21895.75],
                [2021, 4,   4369,  1092.25],
                [2022, 4, 250830, 62707.5 ],
               ]
    expect(actual).to eq expected
  end

  it "groups items by year and by type and counts them" do
    programs  = register.build group: %i{ yearly type }, map: %i{ self }, reduce: %i{ count }
    global_prog  = programs[[]]
    yearly_prog  = programs[%i{ yearly }]
    type_prog    = programs[%i{ type }]
    detail_prog  = programs[%i{ yearly type }]

    global       = global_prog.run invoices
    yearly       = yearly_prog.run invoices
    type         = type_prog  .run invoices
    detail       = detail_prog.run invoices

    actual   = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [ [ 16 ] ]
    expect(actual).to eq expected

    actual   = yearly.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [2020 , 8 ],
                [2021 , 4 ],
                [2022 , 4 ],
               ]
    expect(actual).to eq expected

    actual   = type.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                ["Order"              , 1 ],
                ["PurchaseCreditNote" , 2 ],
                ["PurchaseInvoice"    , 3 ],
                ["Quote"              , 1 ],
                ["SalesCreditNote"    , 2 ],
                ["SalesInvoice"       , 7 ],
               ]
    expect(actual).to eq expected

    actual   = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
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
    programs     = register.build group: %i{ scale type }, map: %i{ invoice_amount }, reduce: %i{ sum }
    global_prog  = programs[[]]
    scale_prog   = programs[%i{ scale }]
    type_prog    = programs[%i{ type }]
    detail_prog  = programs[%i{ scale type }]

    global       = global_prog.run invoices
    scale        = scale_prog.run invoices
    type         = type_prog  .run invoices
    detail       = detail_prog.run invoices

    actual       = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected     = [ [430365] ]
    expect(actual).to eq expected

    actual       = scale.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [ 1 , 135 ],
                [ 2 , 1230 ],
                [ 3 , 12000 ],
                [ 4 , 247000 ],
                [ 5 , 170000 ],
               ]
    expect(actual).to eq expected

    actual   = type.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [ "Order"              , 59     ] ,
                [ "PurchaseCreditNote" , 83023  ] ,
                [ "PurchaseInvoice"    , 81800  ] ,
                [ "Quote"              , 43000  ] ,
                [ "SalesCreditNote"    , 26100  ] ,
                [ "SalesInvoice"       , 196383 ] ]
    expect(actual).to eq expected

    actual   = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
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

  it "groups items by year and by type and by scale returns count, sum and average them" do
    programs     = register.build group: %i{ yearly type scale }, map: %i{ invoice_amount invoice_amount invoice_amount }, reduce: %i{ count sum average }
    global_prog  = programs[[]]
    yearly_prog  = programs[%i{ yearly }]
    type_prog    = programs[%i{   type }]
    scale_prog   = programs[%i{  scale }]
    yearly_type_prog   = programs[%i{ yearly  type }]
    yearly_scale_prog  = programs[%i{ yearly scale }]
    type_scale_prog    = programs[%i{   type scale }]
    detail_prog        = programs[%i{ yearly  type scale }]

    global       = global_prog.run invoices
    yearly       = yearly_prog.run invoices
    scale        = scale_prog.run invoices
    type         = type_prog  .run invoices
    yearly_type  = yearly_type_prog.run invoices
    yearly_scale = yearly_scale_prog.run invoices
    type_scale   = type_scale_prog  .run invoices
    detail       = detail_prog.run invoices

    actual       = global.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected     = [ [ 16, 430365, 26897.8125 ] ]
    expect(actual).to eq expected

    actual       = yearly.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [2020, 8, 175166, 21895.75],
                [2021, 4,   4369,  1092.25],
                [2022, 4, 250830, 62707.5 ],
               ]
    expect(actual).to eq expected

    actual       = scale.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [ 1 , 3,    135,     45 ],
                [ 2 , 3,   1230,    410 ],
                [ 3 , 4,  12000,   3000 ],
                [ 4 , 5, 247000,  49400 ],
                [ 5 , 1, 170000, 170000 ],
               ]
    expect(actual).to eq expected

    actual   = type.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                ["Order"              , 1,     59,    59.0 ],
                ["PurchaseCreditNote" , 2,  83023, 41511.5 ],
                ["PurchaseInvoice"    , 3,  81800, 81800.0 / 3.0 ],
                ["Quote"              , 1,  43000, 43000.0 ],
                ["SalesCreditNote"    , 2,  26100, 13050.0 ],
                ["SalesInvoice"       , 7, 196383, 196383.0 / 7.0 ],
               ]
    expect(actual).to eq expected

    actual   = yearly_type.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [2020 , "PurchaseCreditNote" , 2,  83023, 41511.5  ],
                [2020 , "Quote"              , 1,  43000, 43000.0  ],
                [2020 , "SalesCreditNote"    , 1,  23000, 23000.0  ],
                [2020 , "SalesInvoice"       , 4,  26143,  6535.75 ],
                [2021 , "Order"              , 1,     59,    59.0  ],
                [2021 , "PurchaseInvoice"    , 1,   1100,  1100.0  ],
                [2021 , "SalesCreditNote"    , 1,   3100,  3100.0  ],
                [2021 , "SalesInvoice"       , 1,    110,   110.0  ],
                [2022 , "PurchaseInvoice"    , 2,  80700,  40350.0 ],
                [2022 , "SalesInvoice"       , 2, 170130,  85065.0 ],
               ]
    expect(actual).to eq expected

    actual       = yearly_scale.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [ 2020, 1, 2,     76,     38.0 ],
                [ 2020, 2, 1,    990,    990.0 ],
                [ 2020, 3, 1,   6100,   6100.0 ],
                [ 2020, 4, 4, 168000,  42000.0 ],
                [ 2021, 1, 1,     59,     59.0 ],
                [ 2021, 2, 1,    110,    110.0 ],
                [ 2021, 3, 2,   4200,   2100.0 ],
                [ 2022, 2, 1,    130,    130.0 ],
                [ 2022, 3, 1,   1700,   1700.0 ],
                [ 2022, 4, 1,  79000,  79000.0 ],
                [ 2022, 5, 1, 170000, 170000.0 ],
               ]
    expect(actual).to eq expected

    actual   = type_scale.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                ["Order"              , 1 , 1,     59,     59.0 ],
                ["PurchaseCreditNote" , 1 , 1,     23,     23.0 ],
                ["PurchaseCreditNote" , 4 , 1,  83000,  83000.0 ],
                ["PurchaseInvoice"    , 3 , 2,   2800,   1400.0 ],
                ["PurchaseInvoice"    , 4 , 1,  79000,  79000.0 ],
                ["Quote"              , 4 , 1,  43000,  43000.0 ],
                ["SalesCreditNote"    , 3 , 1,   3100,   3100.0 ],
                ["SalesCreditNote"    , 4 , 1,  23000,  23000.0 ],
                ["SalesInvoice"       , 1 , 1,     53,     53.0 ],
                ["SalesInvoice"       , 2 , 3,   1230,    410.0 ],
                ["SalesInvoice"       , 3 , 1,   6100,   6100.0 ],
                ["SalesInvoice"       , 4 , 1,  19000,  19000.0 ],
                ["SalesInvoice"       , 5 , 1, 170000, 170000.0 ]
               ]
    expect(actual).to eq expected

    actual       = detail.data.values.sort_by(&:key).map { |d| d.key_labels + d.reduced }
    expected = [
                [2020 , "PurchaseCreditNote" , 1 , 1,    23,    23.0 ],
                [2020 , "PurchaseCreditNote" , 4 , 1, 83000, 83000.0 ],
                [2020 , "Quote"              , 4 , 1, 43000, 43000.0 ],
                [2020 , "SalesCreditNote"    , 4 , 1, 23000, 23000.0 ],
                [2020 , "SalesInvoice"       , 1 , 1,    53,    53.0 ],
                [2020 , "SalesInvoice"       , 2 , 1,   990,   990.0 ],
                [2020 , "SalesInvoice"       , 3 , 1,  6100,  6100.0 ],
                [2020 , "SalesInvoice"       , 4 , 1, 19000, 19000.0 ],

                [2021 , "Order"              , 1 , 1,   59,   59.0 ],
                [2021 , "PurchaseInvoice"    , 3 , 1, 1100, 1100.0 ],
                [2021 , "SalesCreditNote"    , 3 , 1, 3100, 3100.0 ],
                [2021 , "SalesInvoice"       , 2 , 1,  110,  110.0 ],

                [2022 , "PurchaseInvoice"    , 3 , 1,   1700,   1700.0 ],
                [2022 , "PurchaseInvoice"    , 4 , 1,  79000,  79000.0 ],
                [2022 , "SalesInvoice"       , 2 , 1,    130,    130.0 ],
                [2022 , "SalesInvoice"       , 5 , 1, 170000, 170000.0 ]
               ]
    expect(actual).to eq expected
  end
end
