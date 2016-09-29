module TestArrayCommon

using Base.Test
using CategoricalArrays
using NullableArrays
using CategoricalArrays: DefaultRefType
using Compat

typealias String Compat.ASCIIString

# == currently throws an error for Nullables
(==) = isequal


# Tests of vcat of CategoricalArray and NullableCategoricalArray

# Test that mergelevels handles mutually compatible ordering
@test CategoricalArrays.mergelevels([6, 3, 4, 7], [2, 3, 5, 4], [2, 4, 8]) == ([6, 2, 3, 5, 4, 7, 8], true)
@test CategoricalArrays.mergelevels([6, 3, 4, 7], [2, 3, 6, 5, 4], [2, 4, 8]) == ([6, 3, 4, 7, 2, 5, 8], false)

for (CA, A) in ((CategoricalArray, Array), (NullableCategoricalArray, NullableArray))
    # Test that vcat of compact arrays uses a reftype that doesn't overflow
    a1 = 3:200
    a2 = 300:-1:100
    ca1 = CA(a1)
    ca2 = CA(a2)
    cca1 = compact(ca1)
    cca2 = compact(ca2)
    r = vcat(cca1, cca2)
    @test r == A(vcat(a1, a2))
    @test isa(cca1, CA{Int, 1, UInt8})
    @test isa(cca2, CA{Int, 1, UInt8})
    @test isa(r, CA{Int, 1, CategoricalArrays.DefaultRefType})
    @test isa(vcat(cca1, ca2), CA{Int, 1, CategoricalArrays.DefaultRefType})
    @test ordered(r) == false
    @test levels(r) == collect(3:300)

    # Test vcat of multidimensional arrays
    a1 = Array{Int}(2, 3, 4, 5)
    a2 = Array{Int}(3, 3, 4, 5)
    a1[1:end] = (length(a1):-1:1) + 2
    a2[1:end] = (1:length(a2)) + 10
    ca1 = CA(a1)
    ca2 = CA(a2)
    cca1 = compact(ca1)
    cca2 = compact(ca2)
    r = vcat(cca1, cca2)
    @test r == A(vcat(a1, a2))
    @test isa(r, CA{Int, 4, CategoricalArrays.DefaultRefType})
    @test ordered(r) == false
    @test levels(r) == collect(3:length(a2)+10)

    # Test concatenation of mutually compatible levels
    a1 = ["Young", "Middle"]
    a2 = ["Middle", "Old"]
    ca1 = CA(a1, ordered=true)
    ca2 = CA(a2, ordered=true)
    levels!(ca1, ["Young", "Middle"])
    levels!(ca2, ["Middle", "Old"])
    r = vcat(ca1, ca2)
    @test r == A(vcat(a1, a2))
    @test levels(r) == ["Young", "Middle", "Old"]
    @test ordered(r) == true

    # Test concatenation of conflicting ordering. This drops the ordering
    a1 = ["Old", "Young", "Young"]
    a2 = ["Old", "Young", "Middle", "Young"]
    ca1 = CA(a1, ordered=true)
    ca2 = CA(a2, ordered=true)
    levels!(ca1, ["Young", "Middle", "Old"])
    # ca2 has another order
    r = vcat(ca1, ca2)
    @test r == A(vcat(a1, a2))
    @test levels(r) == ["Young", "Middle", "Old"]
    @test ordered(r) == false


    # Test that overflow of reftype is detected and doesn't corrupt data and levels
    res = @test_throws LevelsException{Int, UInt8} CategoricalArray{Int, 1, UInt8}(256:-1:1)
    VERSION >= v"0.5.0-dev" && @test res.value.levels == [1]
    @test sprint(showerror, res.value) == "cannot store level(s) 1 since reference type UInt8 can only hold 255 levels. Convert categorical array to a larger reference type to add more levels."

    x = CategoricalVector{Int, UInt8}(254:-1:1)
    x[1] = 1000
    res = @test_throws LevelsException{Int, UInt8} x[1] = 1001
    VERSION >= v"0.5.0-dev" && @test res.value.levels == [1001]
    @test sprint(showerror, res.value) == "cannot store level(s) 1001 since reference type UInt8 can only hold 255 levels. Convert categorical array to a larger reference type to add more levels."
    @test x == vcat(1000, 253:-1:1)
    @test levels(x) == vcat(1:254, 1000)

    x = CategoricalArray{Int, 1, UInt8}(1:254)
    res = @test_throws LevelsException{Int, UInt8} x[1:2] = 1000:1001
    VERSION >= v"0.5.0-dev" && @test res.value.levels == [1001]
    @test sprint(showerror, res.value) == "cannot store level(s) 1001 since reference type UInt8 can only hold 255 levels. Convert categorical array to a larger reference type to add more levels."
    @test x == vcat(1000, 2:254)
    @test levels(x) == vcat(1:254, 1000)

    x = CategoricalArray{Int, 1, UInt8}([1, 3, 256])
    res = @test_throws LevelsException{Int, UInt8} levels!(x, collect(1:256))
    VERSION >= v"0.5.0-dev" && @test res.value.levels == [255]
    @test sprint(showerror, res.value) == "cannot store level(s) 255 since reference type UInt8 can only hold 255 levels. Convert categorical array to a larger reference type to add more levels."

    x = CategoricalVector(30:2:131115)
    res = @test_throws LevelsException{Int, UInt16} CategoricalVector{Int, UInt16}(x)
    VERSION >= v"0.5.0-dev" && @test res.value.levels == collect(131100:2:131114)
    @test sprint(showerror, res.value) == "cannot store level(s) 131100, 131102, 131104, 131106, 131108, 131110, 131112 and 131114 since reference type UInt16 can only hold 65535 levels. Convert categorical array to a larger reference type to add more levels."

    x = CategoricalVector{String, UInt8}(@compat string.(Char.(65:318)))
    res = @test_throws LevelsException{String, UInt8} levels!(x, vcat(levels(x), "az", "bz", "cz"))
    VERSION >= v"0.5.0-dev" && @test res.value.levels == ["bz", "cz"]
    @test sprint(showerror, res.value) == "cannot store level(s) \"bz\" and \"cz\" since reference type UInt8 can only hold 255 levels. Convert categorical array to a larger reference type to add more levels."
    @test x == @compat string.(Char.(65:318))
    lev = copy(levels(x))
    @test levels!(x, vcat(lev, "az")) == vcat(lev, "az")
end

end
