Any[:assignment, :conditional, :arrow, :lazy_or, :lazy_and, :comparison, :pipe,
    :colon, :plus, :bitshift, :times, :rational, :power, :decl, :dot]

    begin_assignments,
          EQ, # =
          EQEQ, # ==
          EQEQEQ, # ===
          PAIR_ARROW, # =>
          GREATER_EQ, # >=
          LESS_EQ, # <=
          RBITSHIFT_EQ, # >>=
          UNSIGNED_BITSHIFT_EQ, # >>>=
          LBITSHIFT_EQ, # <<=
          OR_EQ, # |=
          AND_EQ, # &=
          REM_EQ, # %=
          FWD_SLASH_EQ, # /=
          FWDFWD_SLASH_EQ, # //=
        end_assignments,