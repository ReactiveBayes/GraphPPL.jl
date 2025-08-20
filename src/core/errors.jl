struct NotImplementedError <: Exception
    message::String
end

showerror(io::IO, e::NotImplementedError) = print(io, "NotImplementedError: " * e.message)