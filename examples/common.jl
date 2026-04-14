function parse_size_arg(; default="small")
    size = isempty(ARGS) ? default : lowercase(ARGS[1])

    if size != "small" && size != "medium" && size != "large"
        error("Invalid size `$size`. Choose from `small`, `medium`, or `large`.")
    end

    return size
end
