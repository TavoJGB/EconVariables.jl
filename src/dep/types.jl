#==========================================================================
    AUXILIARY TYPES
==========================================================================#

# Data frequency
abstract type DataFrequency end
struct Annual <: DataFrequency end
struct Quarterly <: DataFrequency end
struct Monthly <: DataFrequency end
struct MultiYearly{N} <: DataFrequency end
struct NAFrequency <: DataFrequency end         # not a frequency

# Subject of analysis
abstract type DataSubject end
struct Household <: DataSubject end
struct Individual <: DataSubject end
struct Quantile <: DataSubject end

# Source of the data
abstract type DataSource end

# Good type (for sector-specific inflation adjustments)
abstract type GoodType end
abstract type SomeGood <: GoodType end
struct AnyGood <: GoodType end
struct ConsumptionGood <: SomeGood end
struct Housing <: SomeGood end



#==========================================================================
    CURRENCIES
==========================================================================#

# Currency type (for tracking nominal vs real values)
abstract type Currency end
abstract type NominalCurrency <: Currency end
abstract type RealCurrency{D} <: Currency end   # D = base date for real values
struct NominalEUR <: NominalCurrency end
struct RealEUR{D} <: RealCurrency{D} end        # D = base date for real values
struct NominalUSD <: NominalCurrency end
struct RealUSD{D} <: RealCurrency{D} end        # D = base date for real values
struct NACurrency <: Currency end        # not a currency

# Currency mapping helpers
# - Nominal to real
real_currency(::NominalEUR, d) = RealEUR{d}()
real_currency(::NominalUSD, d) = RealUSD{d}()
# - Real to nominal
nominal_currency(::RealEUR{D}) where {D} = NominalEUR()
nominal_currency(::RealUSD{D}) where {D} = NominalUSD()
# - Real to real
real_currency(::RealEUR{D1}, d2::Union{Int,Date}) where {D1} = RealEUR{d2}()
real_currency(::RealUSD{D1}, d2::Union{Int,Date}) where {D1} = RealUSD{d2}()
# - Get base date
base_date(::RealCurrency{D}) where {D} = D

# Fallbacks (extend later if more currencies are added)
function real_currency(::NominalCurrency, d)
    throw(ArgumentError("No real-currency mapping defined for this NominalCurrency"))
end
function nominal_currency(::RealCurrency)
    throw(ArgumentError("No nominal-currency mapping defined for this RealCurrency"))
end

# Helper function to display currency type
currency_string(::NominalCurrency) = "Nominal currency"
currency_string(::NominalEUR) = "Nominal EUR"
currency_string(::NominalUSD) = "Nominal USD"
currency_string(::RealCurrency{Y}) where Y = "Real currency {$Y}"
currency_string(::RealEUR{D}) where D = "Real EUR (base=$D)"
currency_string(::RealUSD{D}) where D = "Real USD (base=$D)"



#==========================================================================
    ECONSCALAR
    Scalar economic values (means, variances, etc.)
==========================================================================#

abstract type AbstractEconScalar{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} end

struct EconScalar{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconScalar{T, Tf, Ts}
    value::T
    # Constructor
    EconScalar(value::T, freq::F, DataSubject::S) where {T<:Real, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(value)
end

# Accessor functions for EconScalar
frequency(s::AbstractEconScalar{T, Tf, Ts}) where {T, Tf<:DataFrequency, Ts} = Tf()
subject(s::AbstractEconScalar{T, Tf, Ts}) where {T, Tf, Ts<:DataSubject} = Ts()

# Compatibility check
function assert_compatible(s::AbstractEconScalar, t::AbstractEconScalar)::Nothing
    for (Ts, Tt) in zip(characteristics(s), characteristics(t))
        @assert Ts == Tt "Scalars are not comparable ($Ts vs $Tt)"
    end
    return nothing
end

# Base functions for EconScalar
characteristics(s::AbstractEconScalar) = (frequency(s), subject(s))
Base.show(io::IO, s::AbstractEconScalar) = show(io, s.value)
Base.:(==)(s::AbstractEconScalar, t::AbstractEconScalar) = (s.value == t.value) && (typeof(s) == typeof(t))
Base.:(==)(s::AbstractEconScalar, x::Number) = (s.value == x)
Base.:(==)(x::Number, s::AbstractEconScalar) = (s.value == x)
Base.isequal(s::AbstractEconScalar, t::AbstractEconScalar) = isequal(s.value, t.value) && (typeof(s) == typeof(t))
Base.isequal(s::AbstractEconScalar, x::Number) = isequal(s.value, x)
Base.isequal(x::Number, s::AbstractEconScalar) = isequal(s.value, x)
function Base.isless(s::AbstractEconScalar, t::AbstractEconScalar)
    assert_compatible(s, t)
    return (s.value < t.value)
end
Base.isless(s::Real, t::AbstractEconScalar) = (s < t.value)
Base.isless(s::AbstractEconScalar, t::Real) = (s.value < t)
Base.real(s::AbstractEconScalar) = s.value
Base.abs(s::AbstractEconScalar) = abs(s.value)

# Arithmetic operations for EconScalar
function Base.:+(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value + t.value, characteristics(s)...)
end
Base.:+(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value + x, characteristics(s)...)
Base.:+(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x + s.value, characteristics(s)...)

function Base.:-(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value - t.value, characteristics(s)...)
end
Base.:-(s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(-s.value, characteristics(s)...)
Base.:-(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value - x, characteristics(s)...)
Base.:-(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x - s.value, characteristics(s)...)
function Base.:*(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value * t.value, characteristics(s)...)
end
Base.:*(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value * x, characteristics(s)...)
Base.:*(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x * s.value, characteristics(s)...)

function Base.:/(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value / t.value, characteristics(s)...)
end
Base.:/(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value / x, characteristics(s)...)
Base.:/(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x / s.value, characteristics(s)...)

function Base.:^(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value ^ t.value, characteristics(s)...)
end
Base.:^(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value ^ x, characteristics(s)...)
Base.:^(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x ^ s.value, characteristics(s)...)



#==========================================================================
    MONETARYSCALAR
==========================================================================#

struct MonetaryScalar{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconScalar{T, Tf, Ts}
    value::T
    currency::Currency
    good::GoodType
    # Constructors
    MonetaryScalar(value::T, ::F, ::S, currency::Currency, good::GoodType=AnyGood()) where {T<:Real, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(value, currency, good)
    EconScalar(value::T, freq::F, DataSubject::S, currency::Currency, good::GoodType=AnyGood()) where {T<:Real, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(value, currency, good)
end

# Methods
currency(s::MonetaryScalar) = s.currency
get_good_type(s::MonetaryScalar) = typeof(s.good)
characteristics(s::MonetaryScalar) = (frequency(s), subject(s), currency(s))



#==========================================================================
    ECONVARIABLE
    Vector wrapper with economic metadata
==========================================================================#

abstract type AbstractEconVariable{T<:Union{Missing,Real}, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractVector{T} end

struct EconVariable{T<:Union{Missing,Real}, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconVariable{T, Tf, Ts}
    data::Vector{T}
    # Constructors
    function EconVariable(data::Vector{T}, freq::F, subject::S) where {T<:Union{Missing,Real}, F<:DataFrequency, S<:DataSubject}
        return new{T, F, S}(data)
    end
end

# Accessor functions
frequency(v::AbstractEconVariable{T, Tf, Ts}) where {T, Tf<:DataFrequency, Ts} = Tf()
subject(v::AbstractEconVariable{T, Tf, Ts}) where {T, Tf, Ts<:DataSubject} = Ts()
characteristics(v::AbstractEconVariable) = (frequency(v), subject(v))

# Show methods for EconVariable
list_characteristics(v::AbstractEconVariable) = list_characteristics(characteristics(v)...)
list_characteristics(::Tf, ::Ts) where {Tf<:DataFrequency, Ts<:DataSubject} = string(Tf.name.name), string(Ts.name.name)
function Base.show(io::IO, v::EconVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str = list_characteristics(v)
    println(io, "EconVariable{$T, $freq_str, $subj_str}($(length(v)) elements)")
    Base.print_array(io, v.data)
end
function Base.show(io::IO, ::MIME"text/plain", v::EconVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str = list_characteristics(v)
    println(io, "$(length(v))-element EconVariable{$T, $freq_str, $subj_str}:")
    Base.print_array(io, v.data)
end

# AbstractArray interface implementation
Base.size(v::AbstractEconVariable) = size(v.data)
Base.getindex(v::AbstractEconVariable, i::Int) = getindex(v.data, i)
Base.getindex(v::AbstractEconVariable, I...) = getindex(v.data, I...)
Base.setindex!(v::AbstractEconVariable, val, i::Int) = setindex!(v.data, val, i)
Base.setindex!(v::AbstractEconVariable, val, I...) = setindex!(v.data, val, I...)
Base.IndexStyle(::Type{<:AbstractEconVariable}) = IndexLinear()
Base.length(v::AbstractEconVariable) = length(v.data)

# Iteration
Base.iterate(v::AbstractEconVariable) = iterate(v.data)
Base.iterate(v::AbstractEconVariable, state) = iterate(v.data, state)
# Equality
Base.:(==)(v::AbstractEconVariable, w::AbstractEconVariable) = (v.data == w.data) && (typeof(v) == typeof(w))
Base.isequal(v::AbstractEconVariable, w::AbstractEconVariable) = isequal(v.data, w.data) && (typeof(v) == typeof(w))

# Helper functions to check compatibility
function assert_compatible(v::AbstractEconVariable, w::AbstractEconVariable)::Nothing
    for (Tv, Tw) in zip(characteristics(v), characteristics(w))
        @assert Tv == Tw "Variables are not comparable ($Tv vs $Tw)"
    end
    @assert length(v) == length(w) "Variables have different lengths"
    return nothing
end
function assert_compatible(v::AbstractEconVariable, w::AbstractEconScalar)::Nothing
    for (Tv, Tw) in zip(characteristics(v), characteristics(w))
        @assert Tv == Tw "Variables are not comparable ($Tv vs $Tw)"
    end
    @assert length(v) == length(w) "Variables have different lengths"
    return nothing
end
assert_compatible(w::AbstractEconScalar, v::AbstractEconVariable) = assert_compatible(v, w)

# Arithmetic operations
# - Addition
function Base.:+(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    T = typeof(v).name.wrapper
    return T(v.data .+ w.data, characteristics(v)...)
end
Base.:+(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .+ x, characteristics(v)...)
Base.:+(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .+ v.data, characteristics(v)...)
Base.:+(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .+ x, characteristics(v)...)
Base.:+(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .+ v.data, characteristics(v)...)
# - Addition of EconScalar to EconVariable
function Base.:+(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(v.data .+ s.value, characteristics(v)...)
end
Base.:+(s::AbstractEconScalar, v::AbstractEconVariable) = v + s
# - Subtraction
function Base.:-(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    return Tev.name.wrapper(v.data .- w.data, characteristics(v)...)
end
Base.:-(v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(-v.data, characteristics(v)...)
Base.:-(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .- x, characteristics(v)...)
Base.:-(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .- v.data, characteristics(v)...)
Base.:-(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .- x, characteristics(v)...)
Base.:-(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .- v.data, characteristics(v)...)
function Base.:-(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(v.data .- s.value, characteristics(v)...)
end
function Base.:-(s::Tes, v::Tev) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(s.value .- v.data, characteristics(v)...)
end
# - Multiplication
function Base.:*(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    T = typeof(v).name.wrapper
    return T(v.data .* w.data, characteristics(v)...)
end
Base.:*(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .* x, characteristics(v)...)
Base.:*(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .* v.data, characteristics(v)...)
Base.:*(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .* x, characteristics(v)...)
Base.:*(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .* v.data, characteristics(v)...)
function Base.:*(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(v.data .* s.value, characteristics(v)...)
end
Base.:*(s::AbstractEconScalar, v::AbstractEconVariable) = v * s
# - Division
function Base.:/(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    return Tev.name.wrapper(v.data ./ w.data, characteristics(v)...)
end
Base.:/(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data ./ x, characteristics(v)...)
Base.:/(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x ./ v.data, characteristics(v)...)
Base.:/(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data ./ x, characteristics(v)...)
Base.:/(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x ./ v.data, characteristics(v)...)
function Base.:/(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    return Tev.name.wrapper(v.data ./ s.value, characteristics(v)...)
end
function Base.:/(s::Tes, v::Tev) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    return Tev.name.wrapper(s.value ./ v.data, characteristics(v)...)
end
# - Power
function Base.:^(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    return Tev.name.wrapper(v.data .^ w.data, characteristics(v)...)
end
Base.:^(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .^ x, characteristics(v)...)
Base.:^(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .^ v.data, characteristics(v)...)
Base.:^(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .^ x, characteristics(v)...)
Base.:^(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .^ v.data, characteristics(v)...)

# Broadcasting support
Base.BroadcastStyle(::Type{Tev}) where {Tev<:AbstractEconVariable} = Broadcast.ArrayStyle{Tev}()

# similar
function Base.similar(bc::Broadcast.Broadcasted{<:Broadcast.ArrayStyle{<:Tev}}, ::Type{ElType}, axes) where {ElType, Tev<:AbstractEconVariable}
    v = find_econvar(bc)
    return Tev.name.wrapper(similar(Array{ElType}, axes), characteristics(v)...)
end
Base.similar(bc::Broadcast.Broadcasted{<:Broadcast.ArrayStyle{<:AbstractEconVariable}}, ::Type{ElType}) where {ElType} = similar(bc, ElType, axes(bc))

# Helper function to find an EconVariable in Broadcasted args
function find_econvar(bc::Base.Broadcast.Broadcasted)
    for arg in bc.args
        if arg isa AbstractEconVariable
            return arg
        elseif arg isa Base.Broadcast.Broadcasted
            v = find_econvar(arg)
            if !isnothing(v)
                return v
            end
        end
    end
    return nothing
end

# Statistical functions that preserve metadata and return EconScalar
Base.sum(v::AbstractEconVariable) = EconScalar(sum(v.data), characteristics(v)...)
Base.minimum(v::AbstractEconVariable) = EconScalar(minimum(v.data), characteristics(v)...)
Base.maximum(v::AbstractEconVariable) = EconScalar(maximum(v.data), characteristics(v)...)
EconStats.mean(v::AbstractEconVariable) = EconScalar(mean(v.data), characteristics(v)...)
EconStats.var(v::AbstractEconVariable) = EconScalar(var(v.data), characteristics(v)...)
EconStats.std(v::AbstractEconVariable) =  EconScalar(std(v.data), characteristics(v)...)
EconStats.median(v::AbstractEconVariable) = EconScalar(median(v.data), characteristics(v)...)
EconStats.quantile(v::AbstractEconVariable, p) = EconScalar(quantile(v.data, p), characteristics(v)...)

# Other
Base.skipmissing(v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(collect(skipmissing(v.data)), characteristics(v)...)

# Allow conversion to regular Vector
Base.Vector(v::AbstractEconVariable) = v.data
Base.convert(::Type{Vector{T}}, v::AbstractEconVariable) where T = convert(Vector{T}, v.data)



#==========================================================================
    MONETARYVARIABLE
    Vector wrapper with monetary metadata
==========================================================================#

struct MonetaryVariable{T<:Union{Missing,Real}, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconVariable{T, Tf, Ts}
    data::Vector{T}
    currency::Currency
    good::GoodType
    # Constructors
    MonetaryVariable(data::Vector{T}, ::F, ::S, curr::Currency, good::GoodType=AnyGood()) where {T<:Union{Missing,Real}, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(data, curr, good)
end

currency(v::MonetaryVariable) = v.currency
get_good_type(v::MonetaryVariable) = typeof(v.good)
characteristics(v::MonetaryVariable) = (frequency(v), subject(v), currency(v))
list_characteristics(::Tf, ::Ts, ::Tc) where {Tf<:DataFrequency, Ts<:DataSubject, Tc<:Currency} = string(Tf.name.name), string(Ts.name.name), currency_string(Tc())

# Show methods for MonetaryVariable (with currency)
function Base.show(io::IO, v::MonetaryVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str, curr_str = list_characteristics(v)
    println(io, "MonetaryVariable{$T, $freq_str, $subj_str, $curr_str}($(length(v)) elements)")
    Base.print_array(io, v.data)
end
function Base.show(io::IO, ::MIME"text/plain", v::MonetaryVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str, curr_str = list_characteristics(v)
    println(io, "$(length(v))-element MonetaryVariable{$T, $freq_str, $subj_str, $curr_str}:")
    Base.print_array(io, v.data)
end

# Statistical functions for MonetaryVariable return MonetaryScalar
Base.sum(v::MonetaryVariable) = MonetaryScalar(sum(v.data), characteristics(v)...)
Base.minimum(v::MonetaryVariable) = MonetaryScalar(minimum(v.data), characteristics(v)...)
Base.maximum(v::MonetaryVariable) = MonetaryScalar(maximum(v.data), characteristics(v)...)
EconStats.mean(v::MonetaryVariable) = MonetaryScalar(mean(v.data), characteristics(v)...)
EconStats.var(v::MonetaryVariable) = MonetaryScalar(var(v.data), characteristics(v)...)
EconStats.std(v::MonetaryVariable) = MonetaryScalar(std(v.data), characteristics(v)...)
EconStats.median(v::MonetaryVariable) = MonetaryScalar(median(v.data), characteristics(v)...)
EconStats.quantile(v::MonetaryVariable, p) = MonetaryScalar(quantile(v.data, p), characteristics(v)...)