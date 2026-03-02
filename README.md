# EconVariables.jl

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Vectors and scalars with economic metadata for Julia.**

EconVariables.jl provides wrapper types around numeric vectors and scalars, allowing to combine them with economic metadata —such as data frequency, subject of analysis or currency— so that incompatible data cannot be silently combined.

## Features

- **Econ types** — `EconVariable` / `EconScalar` carry frequency (e.g. `Annual`, `Quarterly`, `Monthly`) and subject (e.g. `Household`, `Individual`, `Quantile`) information.
- **Monetary types** — `MonetaryVariable` / `MonetaryScalar` additionally track currency (nominal or real) and, potentially, good type.
- **Type-safe arithmetic** — operations between incompatible variables (e.g., different frequencies) raise an error at runtime.
- **Full `AbstractVector` interface** — `EconVariable` and `MonetaryVariable` implement indexing, iteration, broadcasting, and standard statistical functions (`mean`, `var`, `std`, `median`, `quantile`, `sum`, `minimum`, `maximum`).
- **Inflation adjustment** — convert between nominal and real values, or rebase real values, using a `CPI` object.

## Installation

The package is not registered. Install it directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/TavoJGB/EconVariables.jl")
```

### Dependencies

| Package | Purpose |
|---------|---------|
| `Dates` | Date handling for CPI and real-currency base dates |
| `Parameters` | Struct unpacking utilities |
| `EconStats` | Statistical functions (`mean`, `var`, `std`, …) |
| `StatsBase` | Additional statistics support |

## Quick start

```julia
using EconVariables
```

### EconVariable & EconScalar

```julia
# Create an annual household-level variable
v = EconVariable([1.0, 2.0, 3.0, 4.0, 5.0], Annual(), Household())

# Arithmetic preserves metadata
w = v + 10.0        # EconVariable with same frequency/subject
s = mean(v)         # EconScalar with same metadata

# Incompatible operations are caught
q = EconVariable([1.0, 2.0, 3.0, 4.0, 5.0], Quarterly(), Household())
# v + q  # ERROR: "Variables are not comparable"
```

### MonetaryVariable & MonetaryScalar

```julia
# Nominal income in USD
income = MonetaryVariable(
    [30_000.0, 31_000.0, 32_500.0],
    Annual(), Household(), NominalUSD()
)

# Currency is part of the type metadata
currency(income)  # NominalUSD()
```

### Inflation adjustment with CPI

```julia
using Dates

# Define a CPI series (dates + index values)
cpi = CPI(
    [Date(2020), Date(2021), Date(2022)],
    [100.0, 103.0, 107.0]
)

# Convert nominal values to real (base year 2020)
income_real = to_real(income, cpi, [Date(2020), Date(2021), Date(2022)], Date(2020))
currency(income_real)  # RealUSD{Date("2020-01-01")}()

# Rebase to a different year
income_rebased = rebase(income_real, cpi, Date(2022))

# Convert back to nominal
income_nominal = to_nominal(income_real, cpi, [Date(2020), Date(2021), Date(2022)])
```

## Type hierarchy

```
AbstractEconScalar{T, Tf, Ts}
├── EconScalar          # plain numeric scalar with freq/subject
└── MonetaryScalar      # adds currency + good type

AbstractEconVariable{T, Tf, Ts} <: AbstractVector{T}
├── EconVariable        # plain numeric vector with freq/subject
└── MonetaryVariable    # adds currency + good type
```

### Metadata types

| Category | Types |
|----------|-------|
| **Frequency** (`DataFrequency`) | `Annual`, `Quarterly`, `Monthly` |
| **Subject** (`DataSubject`) | `Household`, `Individual`, `Quantile` |
| **Currency** (`Currency`) | `NominalEUR`, `NominalUSD`, `RealEUR{D}`, `RealUSD{D}` |
| **Good type** (`GoodType`) | `AnyGood`, `ConsumptionGood`, `Housing` |

## API reference

### Constructors

| Constructor | Description |
|-------------|-------------|
| `EconScalar(value, freq, subject)` | Scalar with frequency and subject |
| `MonetaryScalar(value, freq, subject, currency[, good])` | Scalar with currency metadata |
| `EconVariable(data, freq, subject)` | Vector with frequency and subject |
| `MonetaryVariable(data, freq, subject, currency[, good])` | Vector with currency metadata |
| `CPI(dates, values[, good])` | Consumer Price Index series |

### Accessor functions

| Function | Description |
|----------|-------------|
| `frequency(x)` | Get the `DataFrequency` of a variable or scalar |
| `subject(x)` | Get the `DataSubject` of a variable or scalar |
| `currency(x)` | Get the `Currency` of a monetary type |

### Currency helpers

| Function | Description |
|----------|-------------|
| `real_currency(nominal, base_date)` | Map a nominal currency to its real counterpart |
| `nominal_currency(real)` | Map a real currency back to nominal |

### Inflation functions

| Function | Description |
|----------|-------------|
| `to_real(v, cpi, data_dates, base_date)` | Deflate nominal values to real |
| `to_nominal(v, cpi, data_dates)` | Inflate real values back to nominal |
| `rebase(v, cpi, new_base_date)` | Change the base date of real values |

All three have in-place variants (`to_real!`, `to_nominal!`, `rebase!`).

### Statistics (return `EconScalar` / `MonetaryScalar`)

`sum`, `minimum`, `maximum`, `mean`, `var`, `std`, `median`, `quantile`

## Running the tests

```julia
using Pkg
Pkg.test("EconVariables")
```

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Author

[Gustavo García Bernal](https://garciabernal.github.io/index.html)
