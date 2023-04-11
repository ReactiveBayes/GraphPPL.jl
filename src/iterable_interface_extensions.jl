struct Iterable end
struct NotIterable end

is_iterable(x::AbstractArray) = Iterable()
is_iterable(x::ResizableArray) = Iterable()
is_iterable(x::Tuple) = Iterable()
is_iterable(x::NamedTuple) = Iterable()
is_iterable(x) = NotIterable()