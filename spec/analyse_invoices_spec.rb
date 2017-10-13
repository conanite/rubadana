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
    register.mappers.register  InvoiceYear.new
    register.mappers.register  InvoiceMonth.new
    register.mappers.register  InvoiceType.new
    register.mappers.register  InvoiceScale.new
    register.mappers.register  InvoiceAmount.new
    register.mappers.register  Rubadana::Self.new
    register.reducers.register Rubadana::Sum.new
    register.reducers.register Rubadana::Average.new
    register.reducers.register Rubadana::Count.new
  }

  def mkfactory params ; Rubadana::Factory.new params ; end

  it "groups items by month and counts them" do
    f    = mkfactory group: %i{ monthly }, map: %i{ self }, reduce: %i{ count }
    grid = f.grid register, invoices
    expected_keys = [:__total__,
                     date("2020-02-01"),
                     date("2021-04-01"),
                     date("2020-05-01"),
                     date("2021-12-01"),
                     date("2022-06-01"),
                     date("2022-12-01"),
                     date("2020-11-01")
                    ]
    expect(grid.key_values).to eq [Set.new(expected_keys)]
    expect(grid.keys 0).to eq((expected_keys - [:__total__]).sort)
    expect(grid.data[[   :__total__     ]].reduced).to eq [16]
    expect(grid.data[[date("2020-02-01")]].reduced).to eq [3]
    expect(grid.data[[date("2020-05-01")]].reduced).to eq [3]
    expect(grid.data[[date("2020-11-01")]].reduced).to eq [2]
    expect(grid.data[[date("2021-04-01")]].reduced).to eq [3]
    expect(grid.data[[date("2021-12-01")]].reduced).to eq [1]
    expect(grid.data[[date("2022-06-01")]].reduced).to eq [3]
    expect(grid.data[[date("2022-12-01")]].reduced).to eq [1]
  end

  it "groups items by year and sums them" do
    f    = mkfactory group: %i{ yearly }, map: %i{ invoice_amount }, reduce: %i{ sum }
    grid = f.grid register, invoices
    expected_keys = [:__total__, 2020, 2021, 2022]
    expect(grid.key_values).to eq [Set.new(expected_keys)]
    expect(grid.data[[ :__total__ ]].reduced).to eq [ 430365 ]
    expect(grid.data[[ 2020       ]].reduced).to eq [ 175166 ]
    expect(grid.data[[ 2021       ]].reduced).to eq [   4369 ]
    expect(grid.data[[ 2022       ]].reduced).to eq [ 250830 ]
  end

  it "groups items by year and counts them" do
    f    = mkfactory group: %i{ yearly }, map: %i{ self }, reduce: %i{ count }
    grid = f.grid register, invoices
    expected_keys = [:__total__, 2020, 2021, 2022]
    expect(grid.key_values).to eq [Set.new(expected_keys)]
    expect(grid.data[[:__total__]].reduced).to eq [16]
    expect(grid.data[[2020]].reduced).to eq [8]
    expect(grid.data[[2021]].reduced).to eq [4]
    expect(grid.data[[2022]].reduced).to eq [4]
  end

  it "groups items by year and averages them" do
    f    = mkfactory group: %i{ yearly }, map: %i{ invoice_amount }, reduce: %i{ average }
    grid = f.grid register, invoices
    expected_keys = [:__total__, 2020, 2021, 2022]
    expect(grid.key_values).to eq [Set.new(expected_keys)]
    expect(grid.data[[:__total__ ]].reduced).to eq [ 26897.8125 ]
    expect(grid.data[[2020       ]].reduced).to eq [ 21895.75   ]
    expect(grid.data[[2021       ]].reduced).to eq [  1092.25   ]
    expect(grid.data[[2022       ]].reduced).to eq [ 62707.5    ]
  end

  it "groups items by year and gives the count, sum, and average" do
    factory = mkfactory group: %i{ yearly }, map: %i{ invoice_amount invoice_amount invoice_amount }, reduce: %i{ count sum average }
    grid    = factory.grid register, invoices
    expected_keys_yearly = [:__total__, 2020, 2021, 2022]
    expect(grid.key_values).to eq [Set.new(expected_keys_yearly)]
    expect(grid.data[[:__total__]].reduced).to eq [ 16, 430365, 26897.8125 ]
    expect(grid.data[[2020      ]].reduced).to eq [  8, 175166, 21895.75   ]
    expect(grid.data[[2021      ]].reduced).to eq [  4,   4369,  1092.25   ]
    expect(grid.data[[2022      ]].reduced).to eq [  4, 250830, 62707.5    ]
  end

  it "groups items by year and by type and counts them" do
    factory = mkfactory group: %i{ yearly type }, map: %i{ self }, reduce: %i{ count }
    grid    = factory.grid register, invoices
    expected_keys_yearly = [:__total__, 2020, 2021, 2022]
    expected_keys_type   = [:__total__, "SalesInvoice", "PurchaseInvoice", "SalesCreditNote", "Quote", "Order", "PurchaseCreditNote"]
    expect(grid.key_values).to eq [Set.new(expected_keys_yearly), Set.new(expected_keys_type)]
    expect(grid.data[[2020, "PurchaseCreditNote"       ]].reduced).to eq [2]
    expect(grid.data[[2020, "Quote"                    ]].reduced).to eq [1]
    expect(grid.data[[2020, "SalesCreditNote"          ]].reduced).to eq [1]
    expect(grid.data[[2020, "SalesInvoice"             ]].reduced).to eq [4]
    expect(grid.data[[2020, :__total__                 ]].reduced).to eq [8]
    expect(grid.data[[2021, "Order"                    ]].reduced).to eq [1]
    expect(grid.data[[2021, "PurchaseInvoice"          ]].reduced).to eq [1]
    expect(grid.data[[2021, "SalesCreditNote"          ]].reduced).to eq [1]
    expect(grid.data[[2021, "SalesInvoice"             ]].reduced).to eq [1]
    expect(grid.data[[2021, :__total__                 ]].reduced).to eq [4]
    expect(grid.data[[2022, "PurchaseInvoice"          ]].reduced).to eq [2]
    expect(grid.data[[2022, "SalesInvoice"             ]].reduced).to eq [2]
    expect(grid.data[[2022, :__total__                 ]].reduced).to eq [4]
    expect(grid.data[[:__total__, "Order"              ]].reduced).to eq [1]
    expect(grid.data[[:__total__, "PurchaseCreditNote" ]].reduced).to eq [2]
    expect(grid.data[[:__total__, "PurchaseInvoice"    ]].reduced).to eq [3]
    expect(grid.data[[:__total__, "Quote"              ]].reduced).to eq [1]
    expect(grid.data[[:__total__, "SalesCreditNote"    ]].reduced).to eq [2]
    expect(grid.data[[:__total__, "SalesInvoice"       ]].reduced).to eq [7]
    expect(grid.data[[:__total__, :__total__           ]].reduced).to eq [16]
  end

  it "groups items by scale and by type and sums them" do
    factory = mkfactory group: %i{ scale type }, map: %i{ invoice_amount }, reduce: %i{ sum }
    grid    = factory.grid register, invoices
    expected_keys_scale = [:__total__, 1, 2, 3, 4, 5]
    expected_keys_type   = [:__total__, "SalesInvoice", "PurchaseInvoice", "SalesCreditNote", "Quote", "Order", "PurchaseCreditNote"]
    expect(grid.key_values).to eq [Set.new(expected_keys_scale), Set.new(expected_keys_type)]
    expect(grid.data[[:__total__, :__total__           ]].reduced).to eq [430365]
    expect(grid.data[[:__total__, "SalesInvoice"       ]].reduced).to eq [196383]
    expect(grid.data[[:__total__, "PurchaseInvoice"    ]].reduced).to eq [81800]
    expect(grid.data[[:__total__, "SalesCreditNote"    ]].reduced).to eq [26100]
    expect(grid.data[[:__total__, "Quote"              ]].reduced).to eq [43000]
    expect(grid.data[[:__total__, "Order"              ]].reduced).to eq [59]
    expect(grid.data[[:__total__, "PurchaseCreditNote" ]].reduced).to eq [83023]
    expect(grid.data[[1, :__total__                    ]].reduced).to eq [135]
    expect(grid.data[[3, :__total__                    ]].reduced).to eq [12000]
    expect(grid.data[[4, :__total__                    ]].reduced).to eq [247000]
    expect(grid.data[[2, :__total__                    ]].reduced).to eq [1230]
    expect(grid.data[[5, :__total__                    ]].reduced).to eq [170000]
    expect(grid.data[[1, "SalesInvoice"                ]].reduced).to eq [53]
    expect(grid.data[[3, "PurchaseInvoice"             ]].reduced).to eq [2800]
    expect(grid.data[[4, "SalesCreditNote"             ]].reduced).to eq [23000]
    expect(grid.data[[3, "SalesCreditNote"             ]].reduced).to eq [3100]
    expect(grid.data[[4, "Quote"                       ]].reduced).to eq [43000]
    expect(grid.data[[1, "Order"                       ]].reduced).to eq [59]
    expect(grid.data[[3, "SalesInvoice"                ]].reduced).to eq [6100]
    expect(grid.data[[4, "PurchaseInvoice"             ]].reduced).to eq [79000]
    expect(grid.data[[4, "PurchaseCreditNote"          ]].reduced).to eq [83000]
    expect(grid.data[[2, "SalesInvoice"                ]].reduced).to eq [1230]
    expect(grid.data[[4, "SalesInvoice"                ]].reduced).to eq [19000]
    expect(grid.data[[1, "PurchaseCreditNote"          ]].reduced).to eq [23]
    expect(grid.data[[5, "SalesInvoice"                ]].reduced).to eq [170000]
  end

  it "groups items by year and by type and by scale returns count, sum and average them" do
    f    = mkfactory group: %i{ yearly type scale }, map: %i{ invoice_amount invoice_amount invoice_amount }, reduce: %i{ count sum average }
    grid = f.grid register, invoices

    yearly_keys = [:__total__, 2020, 2021, 2022]
    type_keys   = [:__total__, "SalesInvoice", "PurchaseInvoice", "SalesCreditNote", "Quote", "Order", "PurchaseCreditNote"]
    scale_keys  = [:__total__, 1, 2, 3, 4, 5]

    expect(grid.key_values).to eq [Set.new(yearly_keys), Set.new(type_keys), Set.new(scale_keys)]
    expect(grid.data[[:__total__ , :__total__           , :__total__ ] ].reduced).to eq [16 , 430365 , 26897.8125         ]
    expect(grid.data[[:__total__ , :__total__           , 1          ] ].reduced).to eq [3  , 135    , 45.0               ]
    expect(grid.data[[:__total__ , :__total__           , 3          ] ].reduced).to eq [4  , 12000  , 3000.0             ]
    expect(grid.data[[:__total__ , :__total__           , 4          ] ].reduced).to eq [5  , 247000 , 49400.0            ]
    expect(grid.data[[:__total__ , :__total__           , 2          ] ].reduced).to eq [3  , 1230   , 410.0              ]
    expect(grid.data[[:__total__ , :__total__           , 5          ] ].reduced).to eq [1  , 170000 , 170000.0           ]
    expect(grid.data[[:__total__ , "SalesInvoice"       , :__total__ ] ].reduced).to eq [7  , 196383 , 28054.714285714286 ]
    expect(grid.data[[:__total__ , "PurchaseInvoice"    , :__total__ ] ].reduced).to eq [3  , 81800  , 81800.0 / 3.0      ]
    expect(grid.data[[:__total__ , "SalesCreditNote"    , :__total__ ] ].reduced).to eq [2  , 26100  , 13050.0            ]
    expect(grid.data[[:__total__ , "Quote"              , :__total__ ] ].reduced).to eq [1  , 43000  , 43000.0            ]
    expect(grid.data[[:__total__ , "Order"              , :__total__ ] ].reduced).to eq [1  , 59     , 59.0               ]
    expect(grid.data[[:__total__ , "PurchaseCreditNote" , :__total__ ] ].reduced).to eq [2  , 83023  , 41511.5            ]
    expect(grid.data[[:__total__ , "SalesInvoice"       , 1          ] ].reduced).to eq [1  , 53     , 53.0               ]
    expect(grid.data[[:__total__ , "PurchaseInvoice"    , 3          ] ].reduced).to eq [2  , 2800   , 1400.0             ]
    expect(grid.data[[:__total__ , "SalesCreditNote"    , 4          ] ].reduced).to eq [1  , 23000  , 23000.0            ]
    expect(grid.data[[:__total__ , "SalesCreditNote"    , 3          ] ].reduced).to eq [1  , 3100   , 3100.0             ]
    expect(grid.data[[:__total__ , "Quote"              , 4          ] ].reduced).to eq [1  , 43000  , 43000.0            ]
    expect(grid.data[[:__total__ , "Order"              , 1          ] ].reduced).to eq [1  , 59     , 59.0               ]
    expect(grid.data[[:__total__ , "SalesInvoice"       , 3          ] ].reduced).to eq [1  , 6100   , 6100.0             ]
    expect(grid.data[[:__total__ , "PurchaseInvoice"    , 4          ] ].reduced).to eq [1  , 79000  , 79000.0            ]
    expect(grid.data[[:__total__ , "PurchaseCreditNote" , 4          ] ].reduced).to eq [1  , 83000  , 83000.0            ]
    expect(grid.data[[:__total__ , "SalesInvoice"       , 2          ] ].reduced).to eq [3  , 1230   , 410.0              ]
    expect(grid.data[[:__total__ , "SalesInvoice"       , 4          ] ].reduced).to eq [1  , 19000  , 19000.0            ]
    expect(grid.data[[:__total__ , "PurchaseCreditNote" , 1          ] ].reduced).to eq [1  , 23     , 23.0               ]
    expect(grid.data[[:__total__ , "SalesInvoice"       , 5          ] ].reduced).to eq [1  , 170000 , 170000.0           ]
    expect(grid.data[[2020       , :__total__           , :__total__ ] ].reduced).to eq [8  , 175166 , 21895.75           ]
    expect(grid.data[[2021       , :__total__           , :__total__ ] ].reduced).to eq [4  , 4369   , 1092.25            ]
    expect(grid.data[[2022       , :__total__           , :__total__ ] ].reduced).to eq [4  , 250830 , 62707.5            ]
    expect(grid.data[[2020       , :__total__           , 1          ] ].reduced).to eq [2  , 76     , 38.0               ]
    expect(grid.data[[2021       , :__total__           , 3          ] ].reduced).to eq [2  , 4200   , 2100.0             ]
    expect(grid.data[[2020       , :__total__           , 4          ] ].reduced).to eq [4  , 168000 , 42000.0            ]
    expect(grid.data[[2021       , :__total__           , 1          ] ].reduced).to eq [1  , 59     , 59.0               ]
    expect(grid.data[[2020       , :__total__           , 3          ] ].reduced).to eq [1  , 6100   , 6100.0             ]
    expect(grid.data[[2022       , :__total__           , 4          ] ].reduced).to eq [1  , 79000  , 79000.0            ]
    expect(grid.data[[2020       , :__total__           , 2          ] ].reduced).to eq [1  , 990    , 990.0              ]
    expect(grid.data[[2022       , :__total__           , 2          ] ].reduced).to eq [1  , 130    , 130.0              ]
    expect(grid.data[[2022       , :__total__           , 3          ] ].reduced).to eq [1  , 1700   , 1700.0             ]
    expect(grid.data[[2021       , :__total__           , 2          ] ].reduced).to eq [1  , 110    , 110.0              ]
    expect(grid.data[[2022       , :__total__           , 5          ] ].reduced).to eq [1  , 170000 , 170000.0           ]
    expect(grid.data[[2020       , "SalesInvoice"       , :__total__ ] ].reduced).to eq [4  , 26143  , 6535.75            ]
    expect(grid.data[[2021       , "PurchaseInvoice"    , :__total__ ] ].reduced).to eq [1  , 1100   , 1100.0             ]
    expect(grid.data[[2020       , "SalesCreditNote"    , :__total__ ] ].reduced).to eq [1  , 23000  , 23000.0            ]
    expect(grid.data[[2021       , "SalesCreditNote"    , :__total__ ] ].reduced).to eq [1  , 3100   , 3100.0             ]
    expect(grid.data[[2020       , "Quote"              , :__total__ ] ].reduced).to eq [1  , 43000  , 43000.0            ]
    expect(grid.data[[2021       , "Order"              , :__total__ ] ].reduced).to eq [1  , 59     , 59.0               ]
    expect(grid.data[[2022       , "PurchaseInvoice"    , :__total__ ] ].reduced).to eq [2  , 80700  , 40350.0            ]
    expect(grid.data[[2020       , "PurchaseCreditNote" , :__total__ ] ].reduced).to eq [2  , 83023  , 41511.5            ]
    expect(grid.data[[2022       , "SalesInvoice"       , :__total__ ] ].reduced).to eq [2  , 170130 , 85065.0            ]
    expect(grid.data[[2021       , "SalesInvoice"       , :__total__ ] ].reduced).to eq [1  , 110    , 110.0              ]
    expect(grid.data[[2020       , "SalesInvoice"       , 1          ] ].reduced).to eq [1  , 53     , 53.0               ]
    expect(grid.data[[2021       , "PurchaseInvoice"    , 3          ] ].reduced).to eq [1  , 1100   , 1100.0             ]
    expect(grid.data[[2020       , "SalesCreditNote"    , 4          ] ].reduced).to eq [1  , 23000  , 23000.0            ]
    expect(grid.data[[2021       , "SalesCreditNote"    , 3          ] ].reduced).to eq [1  , 3100   , 3100.0             ]
    expect(grid.data[[2020       , "Quote"              , 4          ] ].reduced).to eq [1  , 43000  , 43000.0            ]
    expect(grid.data[[2021       , "Order"              , 1          ] ].reduced).to eq [1  , 59     , 59.0               ]
    expect(grid.data[[2020       , "SalesInvoice"       , 3          ] ].reduced).to eq [1  , 6100   , 6100.0             ]
    expect(grid.data[[2022       , "PurchaseInvoice"    , 4          ] ].reduced).to eq [1  , 79000  , 79000.0            ]
    expect(grid.data[[2020       , "PurchaseCreditNote" , 4          ] ].reduced).to eq [1  , 83000  , 83000.0            ]
    expect(grid.data[[2020       , "SalesInvoice"       , 2          ] ].reduced).to eq [1  , 990    , 990.0              ]
    expect(grid.data[[2022       , "SalesInvoice"       , 2          ] ].reduced).to eq [1  , 130    , 130.0              ]
    expect(grid.data[[2022       , "PurchaseInvoice"    , 3          ] ].reduced).to eq [1  , 1700   , 1700.0             ]
    expect(grid.data[[2020       , "SalesInvoice"       , 4          ] ].reduced).to eq [1  , 19000  , 19000.0            ]
    expect(grid.data[[2020       , "PurchaseCreditNote" , 1          ] ].reduced).to eq [1  , 23     , 23.0               ]
    expect(grid.data[[2021       , "SalesInvoice"       , 2          ] ].reduced).to eq [1  , 110    , 110.0              ]
    expect(grid.data[[2022       , "SalesInvoice"       , 5          ] ].reduced).to eq [1  , 170000 , 170000.0           ]
  end
end
