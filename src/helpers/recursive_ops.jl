"""
    recursive_add!!(x, y)

Recursively add the leaves of two nested structures `x` and `y`. In Functor language, this
is equivalent to doing `fmap(+, x, y)`, but this implementation uses type stable code for
common cases.

Any leaves of `x` that are arrays and allow in-place addition will be modified in place.
"""
@inline recursive_add!!(x, y) = recursive_map(__add!!, x, y)

"""
    recursive_eltype(x)

Recursively determine the element type of a nested structure `x`. This is equivalent to
doing `fmap(eltype, x)`, but this implementation uses type stable code for common cases.
"""
@inline function recursive_eltype(x::AbstractArray{T}) where {T}
    isbitstype(T) && return eltype(x)
    return mapreduce(recursive_eltype, promote_type, x)
end
@inline recursive_eltype(::Union{Nothing, Missing, Val}) = Bool
@inline recursive_eltype(x::Number) = eltype(x)
@inline function recursive_eltype(x::Union{Tuple, NamedTuple})
    leaves = x isa Tuple ? x : values(x)
    length(leaves) == 0 && return Bool
    return unrolled_mapreduce(recursive_eltype, promote_type, leaves)
end
@inline function recursive_eltype(x)
    leaves = Functors.fleaves(x)
    length(leaves) == 0 && return Bool
    return mapreduce(recursive_eltype, promote_type, leaves)
end

"""
    recursive_make_zero(x)

Recursively create a zero value for a nested structure `x`. This is equivalent to doing
`fmap(zero, x)`, but this implementation uses type stable code for common cases.

See also [`Lux.recursive_make_zero!!`](@ref).
"""
@inline recursive_make_zero(x) = recursive_map(__zero, x)

"""
    recursive_make_zero!!(x)

Recursively create a zero value for a nested structure `x`. Leaves that can be mutated with
in-place zeroing will be modified in place.

See also [`Lux.recursive_make_zero`](@ref) for fully out-of-place version.
"""
@inline recursive_make_zero!!(x) = recursive_map(__zero!!, x)

"""
    recursive_copyto!(x, y)

Recursively copy the leaves of two nested structures `x` and `y`. In Functor language, this
is equivalent to doing `fmap(copyto!, x, y)`, but this implementation uses type stable code
for common cases. Note that any immutable leaf will lead to an error.
"""
@inline recursive_copyto!(x, y) = recursive_map(copyto!, x, y)

"""
    recursive_map(f, x, args...)

Similar to `fmap(f, args...)` but with restricted support for the notion of "leaf" types.
However, this allows for more efficient and type stable implementations of recursive
operations.

## How this works?

For the following types it directly defines recursion rules:

 1. `AbstractArray`: If eltype is `isbitstype`, then `f` is applied to the array, else we
    recurse on the array.
 2. `Tuple/NamedTuple`: We recurse on the values.
 3. `Number/Val/Nothing`: We directly apply `f`.
 4. For all other types, we recurse on the fields using `Functors.fmap`.

!!! note

    In most cases, users should gravitate towards `Functors.fmap` if it is being used
    outside of hot loops. Even for other cases, it is always recommended to verify the
    correctness of this implementation for specific usecases.
"""
function recursive_map end

for direct_call in (Number, Val, Nothing)
    @eval @inline recursive_map(f::F, x::$(direct_call), args...) where {F} = f(x, args...)
end
@inline function recursive_map(f::F, x::AbstractArray{T}, args...) where {F, T}
    isbitstype(T) && return f(x, args...)
    return f.(x, args...)
end
@inline function recursive_map(f::F, x::Tuple, args...) where {F}
    map_fn = let f = f
        (args_...) -> recursive_map(f, args_...)
    end
    return map(map_fn, x, args...)
end
@inline function recursive_map(f::F, x::NamedTuple{fields}, args...) where {F, fields}
    map_fn = let f = f
        (args_...) -> recursive_map(f, args_...)
    end
    return NamedTuple{fields}(unrolled_map(map_fn, values(x), values.(args)...))
end
@inline recursive_map(f::F, x, args...) where {F} = fmap(f, x, args...)
