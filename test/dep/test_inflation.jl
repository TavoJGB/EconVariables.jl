# Tests for Inflation/CPI functionality

function test_cpi_construction()
    @testset "CPI Construction" begin
        # Construction with years (Int)
        years = [1990, 1991, 1992, 1993, 1994]
        values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, values, ConsumptionGood())
        
        @test length(cpi) == 5
        @test cpi[1] == 100.0
        @test cpi[end] == 115.0
        
        # Construction with Dates
        dates = Date.(years)
        cpi2 = CPI(dates, values, ConsumptionGood())
        @test length(cpi2) == 5
        
        # CPI indexing by date
        idx = cpi_index(cpi, Date(1992))
        @test idx == 106.5
        
        # CPI indexing by vector of dates
        idxs = cpi_index(cpi, [1990, 1992, 1994])
        @test idxs == [100.0, 106.5, 115.0]
        
        # Multiple good types
        cpi_housing = CPI(years, [110.0, 115.0, 120.0, 125.0, 132.0], Housing())
        cpi_anygood = CPI(years, values, AnyGood())
        
        @test get_good(cpi) == ConsumptionGood()
        @test get_good(cpi_housing) == Housing()
        @test get_good(cpi_anygood) == AnyGood()
    end
end

function test_monetaryvariable_inflation()
    @testset "MonetaryVariable Inflation Conversions" begin
        # Setup
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        income_nom = MonetaryVariable([45000.0, 48000.0, 50000.0, 52000.0, 55000.0], 
                                     Annual(), Household(), NominalUSD())
        
        # Nominal to Real
        income_real = to_real(income_nom, cpi, years, 1990)
        @test currency(income_real) isa RealUSD{1990}
        @test base_date(currency(income_real)) == 1990
        @test income_real.data[1] == 45000.0  # Base year unchanged
        @test income_real.data[2] > income_nom.data[2]  # Deflated
        
        # Real to Nominal (round-trip)
        income_nom_again = to_nominal(income_real, cpi, years)
        @test currency(income_nom_again) isa NominalUSD
        @test all(isapprox.(income_nom.data, income_nom_again.data, rtol=1e-10))
        
        # Rebasing
        income_real_1992 = rebase(income_real, cpi, 1992)
        @test currency(income_real_1992) isa RealUSD{1992}
        @test base_date(currency(income_real_1992)) == 1992
        # Value at position 3 should equal real value deflated to 1992 base
        @test income_real_1992.data[3] ≈ income_real.data[3] * cpi_values[3] / cpi_values[1]
    end
end

function test_monetaryscalar_inflation()
    @testset "MonetaryScalar Inflation Conversions" begin
        # Setup
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        income_1993_nom = MonetaryScalar(52000.0, Annual(), Household(), NominalUSD())
        
        # Nominal to Real
        income_1993_real = to_real(income_1993_nom, cpi, 1993, 1990)
        @test currency(income_1993_real) isa RealUSD{1990}
        @test base_date(currency(income_1993_real)) == 1990
        @test income_1993_real.value > income_1993_nom.value  # Deflated
        
        # Real to Nominal (round-trip)
        income_1993_nom_again = to_nominal(income_1993_real, cpi, 1993)
        @test currency(income_1993_nom_again) isa NominalUSD
        @test isapprox(income_1993_nom.value, income_1993_nom_again.value, rtol=1e-10)
        
        # Rebasing
        income_1993_real_1992 = rebase(income_1993_real, cpi, 1992)
        @test currency(income_1993_real_1992) isa RealUSD{1992}
        @test base_date(currency(income_1993_real_1992)) == 1992
    end
end

function test_inflation_roundtrip()
    @testset "Inflation Round-trip Accuracy" begin
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        # MonetaryVariable round-trip
        v_nom = MonetaryVariable([45000.0, 48000.0, 50000.0, 52000.0, 55000.0], 
                                Annual(), Household(), NominalUSD())
        v_real = to_real(v_nom, cpi, years, 1990)
        v_nom_again = to_nominal(v_real, cpi, years)
        
        max_diff = maximum(abs.(v_nom.data .- v_nom_again.data))
        @test max_diff < 1e-10
        
        # MonetaryScalar round-trip
        s_nom = MonetaryScalar(52000.0, Annual(), Household(), NominalUSD())
        s_real = to_real(s_nom, cpi, 1993, 1990)
        s_nom_again = to_nominal(s_real, cpi, 1993)
        
        @test abs(s_nom.value - s_nom_again.value) < 1e-10
    end
end

function test_inflation_errors()
    @testset "Inflation Error Handling" begin
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        # Try to convert real to real (should fail)
        v_real = MonetaryVariable([45000.0, 48000.0], Annual(), Household(), RealUSD{1990}())
        @test_throws ArgumentError to_real(v_real, cpi, [1990, 1991], 1990)
        
        # Try to convert nominal to nominal (should fail)
        v_nom = MonetaryVariable([45000.0, 48000.0], Annual(), Household(), NominalUSD())
        @test_throws ArgumentError to_nominal(v_nom, cpi, [1990, 1991])
        
        # Try to rebase nominal (should fail)
        @test_throws ArgumentError rebase(v_nom, cpi, 1992)
        
        # Same for scalars
        s_real = MonetaryScalar(50000.0, Annual(), Household(), RealUSD{1990}())
        @test_throws ArgumentError to_real(s_real, cpi, 1990, 1990)
        
        s_nom = MonetaryScalar(50000.0, Annual(), Household(), NominalUSD())
        @test_throws ArgumentError to_nominal(s_nom, cpi, 1990)
        @test_throws ArgumentError rebase(s_nom, cpi, 1992)
    end
end

function test_multiple_cpis()
    @testset "Multiple CPIs for Different Good Types" begin
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_consumption = CPI(years, [100.0, 103.0, 106.5, 110.0, 115.0], ConsumptionGood())
        cpi_housing = CPI(years, [110.0, 115.0, 120.0, 125.0, 132.0], Housing())
        
        # Test with multiple CPIs - should not throw
        cpis = [cpi_consumption, cpi_housing]
        @test length(cpis) == 2
        
        # Test duplicate good types (should fail)
        cpi_consumption2 = CPI(years, [101.0, 104.0, 107.0, 111.0, 116.0], ConsumptionGood())
        @test_throws ArgumentError validate_cpis_unique([cpi_consumption, cpi_consumption2])
        
        # Test build_cpi_dict
        cpi_dict, anygood_cpi = build_cpi_dict(cpis)
        @test haskey(cpi_dict, ConsumptionGood())
        @test haskey(cpi_dict, Housing())
        @test isnothing(anygood_cpi)
        
        # Test with AnyGood CPI
        cpi_general = CPI(years, [105.0, 108.0, 111.0, 114.0, 118.0], AnyGood())
        cpi_dict2, anygood_cpi2 = build_cpi_dict([cpi_consumption, cpi_general])
        @test !isnothing(anygood_cpi2)
        @test get_good(anygood_cpi2) == AnyGood()
    end
end