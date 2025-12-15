module EconVariables

    BASE_FOLDER = dirname(@__DIR__)

    using Dates
    using Parameters        # unpack
    using EconStats         # statistics

    # Load dependencies
    include(joinpath(BASE_FOLDER, "src", "dep", "types.jl"))
        export EconVariable, EconScalar
        export MonetaryVariable, MonetaryScalar
        export DataSource
        export DataFrequency, frequency, Annual, Quarterly, Monthly
        export DataSubject, subject, Household, Individual, Quantile
        export Currency, currency
        export NominalEUR, NominalUSD
        export RealEUR, RealUSD
        export get_dates
        export monetary_variable!
        # export TenureStatus, Owner, Renter, NoTenure
    include(joinpath(BASE_FOLDER, "src", "dep", "inflation.jl"))
        export CPI, GoodType, AnyGood, ConsumptionGood, Housing
        export to_real, to_nominal, rebase
        export to_real!, to_nominal!, rebase!

end
