Position = UnitRange{Int64}

after_last(position::Position) = last(position) + 1
before_first(position::Position) = first(position) - 1
between(start::Position, final::Position) = after_last(start):before_first(final)

Base.merge(start::Position, final::Position) = first(start):last(final)
