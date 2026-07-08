# Tests for MonetaryVariable type

function test_monetaryvariable_construction()
    @testset "MonetaryVariable Construction" begin
        # Nominal USD
        data = [45000.0, 48000.0, 50000.0, 52000.0, 55000.0]
        v1 = MonetaryVariable(data, Annual(), Household(), NominalUSD())
        
        @test length(v1) == 5
        @test v1[1] == 45000.0
        @test frequency(v1) == Annual()
        @test subject(v1) == Household()
        @test currency(v1) isa NominalUSD
        
        # Real EUR
        v2 = MonetaryVariable([40000.0, 42000.0], Annual(), Individual(), RealEUR{2000}())
        @test length(v2) == 2
        @test currency(v2) isa RealEUR{2000}
        @test base_date(currency(v2)) == 2000
    end
end

function test_monetaryvariable_arithmetic()
    @testset "MonetaryVariable Arithmetic" begin
        v1 = MonetaryVariable([100.0, 200.0, 300.0], Annual(), Household(), NominalUSD())
        v2 = MonetaryVariable([50.0, 100.0, 150.0], Annual(), Household(), NominalUSD())
        
        # Addition
        v3 = v1 + v2
        @test v3.data == [150.0, 300.0, 450.0]
        @test currency(v3) isa NominalUSD
        
        # Subtraction
        v4 = v1 - v2
        @test v4.data == [50.0, 100.0, 150.0]
        
        # Multiplication
        v5 = v1 * 2
        @test v5.data == [200.0, 400.0, 600.0]
        
        # Division
        v6 = v1 / 2
        @test v6.data == [50.0, 100.0, 150.0]
    end
end

function test_monetaryvariable_deleteat!()
    @testset "MonetaryVariable deleteat!" begin
        v = MonetaryVariable([10.0, 20.0, 30.0, 40.0], Annual(), Household(), NominalUSD())
        deleteat!(v, BitVector([false, true, false, true]))
        @test v.data == [10.0, 30.0]
        @test v isa MonetaryVariable
        @test currency(v) isa NominalUSD
    end
end

function test_monetaryvariable_broadcasting()
    @testset "MonetaryVariable Broadcasting" begin
        v = MonetaryVariable([100.0, 200.0, 300.0], Annual(), Household(), NominalUSD())
        v_real = MonetaryVariable(Real[100, 200, 300], Annual(), Household(), NominalUSD())
        v_mixed = MonetaryVariable([100.0, 200.0, 300.0], Annual(), Household(), NominalUSD())
        h_val = MonetaryVariable(Real[20, 30, 40], Annual(), Household(), NominalUSD())
        mortgage = MonetaryVariable(Real[5, 10, 15], Annual(), Household(), NominalUSD())
        
        # Broadcasting with scalars
        v2 = v .* 1.5
        @test v2.data == [150.0, 300.0, 450.0]
        @test v2 isa MonetaryVariable
        @test currency(v2) isa NominalUSD
        
        v3 = v .+ 50
        @test v3.data == [150.0, 250.0, 350.0]
        
        # Broadcasting with vectors
        v4 = v .* [1, 2, 3]
        @test v4.data == [100.0, 400.0, 900.0]

        # Nested broadcast with AbstractArray-typed monetary data
        v5 = @. v_real - (v_real - 10)
        @test v5 isa MonetaryVariable
        @test v5.data == [10, 10, 10]

        # Mixed concrete eltypes should still preserve MonetaryVariable
        v6 = @. v_mixed - (h_val - mortgage)
        @test v6 isa MonetaryVariable
        @test v6.data == [85.0, 180.0, 275.0]

        # Predicate-style broadcasts should not preserve monetary metadata
        b1 = isfinite.(v_mixed)
        @test b1 isa AbstractVector{Bool}
        @test !(b1 isa MonetaryVariable)
        @test b1 == [true, true, true]

        b2 = @. (20 <= v_mixed) & (v_mixed < 250)
        @test b2 isa AbstractVector{Bool}
        @test !(b2 isa MonetaryVariable)
        @test b2 == [true, true, false]
    end
end

function test_monetaryvariable_statistics()
    @testset "MonetaryVariable Statistics" begin
        v = MonetaryVariable([10.0, 20.0, 30.0, 40.0, 50.0], Annual(), Household(), NominalUSD())
        
        # Mean
        m = mean(v)
        @test m isa MonetaryScalar
        @test m.value == 30.0
        @test frequency(m) == Annual()
        @test subject(m) == Household()
        @test currency(m) isa NominalUSD
        
        # Median
        med = median(v)
        @test med isa MonetaryScalar
        @test med.value == 30.0
        @test currency(med) isa NominalUSD
        
        # Standard deviation
        s = std(v)
        @test s isa MonetaryScalar
        @test s.value ≈ 15.811388300841896
        @test currency(s) isa NominalUSD
        
        # Sum
        sum_v = sum(v)
        @test sum_v isa MonetaryScalar
        @test sum_v.value == 150.0
        @test currency(sum_v) isa NominalUSD
    end
end

function test_monetaryvariable_currency()
    @testset "MonetaryVariable Currency" begin
        # Nominal currencies
        v_nom = MonetaryVariable([1000.0, 2000.0], Annual(), Household(), NominalUSD())
        @test currency(v_nom) isa NominalCurrency
        @test currency(v_nom) isa NominalUSD
        
        # Real currencies
        v_real = MonetaryVariable([1000.0, 2000.0], Annual(), Household(), RealUSD{1990}())
        @test currency(v_real) isa RealCurrency
        @test currency(v_real) isa RealUSD{1990}
        @test base_date(currency(v_real)) == 1990
        
        # Currency is preserved in arithmetic
        v2 = v_nom .* 2
        @test currency(v2) isa NominalUSD
        
        v3 = v_real .+ 500
        @test currency(v3) isa RealUSD{1990}
    end
end
