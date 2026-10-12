-module(community_crypto_ffi).
-export([hash/2, verify/3, username/0]).

hash(Secret, Salt) ->
    binary:encode_hex(crypto:pbkdf2_hmac(sha256, Secret, Salt, 600000, 32)).

verify(Secret, Salt, Expected) ->
    Actual = hash(Secret, Salt),
    constant_equal(Actual, Expected, 0).

constant_equal(<<>>, <<>>, Acc) -> Acc =:= 0;
constant_equal(<<A, As/binary>>, <<B, Bs/binary>>, Acc) ->
    constant_equal(As, Bs, Acc bor (A bxor B));
constant_equal(_, _, _) -> false.

username() ->
    Adjectives = [<<"Bright">>, <<"Gentle">>, <<"Brave">>, <<"Happy">>, <<"Calm">>, <<"Swift">>, <<"Clever">>, <<"Sunny">>, <<"Kind">>, <<"Quiet">>, <<"Nice">>, <<"Cute">>, <<"Cool">>, <<"Warm">>, <<"Fresh">>, <<"Sweet">>, <<"Bold">>, <<"Lucky">>, <<"Tiny">>, <<"Soft">>, <<"Wise">>, <<"Quick">>, <<"Merry">>, <<"Jolly">>, <<"Shy">>, <<"Neat">>, <<"Fair">>, <<"Wild">>, <<"Cozy">>, <<"Chill">>, <<"Royal">>, <<"Noble">>, <<"Pink">>, <<"Blue">>, <<"Gold">>, <<"Red">>, <<"Silver">>, <<"Amber">>, <<"Magic">>, <<"Young">>],
    Fruits = [<<"Mango">>, <<"Apple">>, <<"Pear">>, <<"Peach">>, <<"Plum">>, <<"Kiwi">>, <<"Lime">>, <<"Lemon">>, <<"Orange">>, <<"Banana">>, <<"Cherry">>, <<"Grape">>, <<"Melon">>, <<"Papaya">>, <<"Guava">>, <<"Berry">>, <<"Fig">>, <<"Date">>, <<"Lychee">>, <<"Pomelo">>, <<"Apricot">>, <<"Coconut">>, <<"Durian">>, <<"Rambutan">>, <<"Mulberry">>, <<"Olive">>, <<"Tomato">>, <<"Avocado">>, <<"Jackfruit">>, <<"Nectarine">>, <<"Tangerine">>, <<"Mandarin">>, <<"Starfruit">>, <<"Longan">>, <<"Persimmon">>, <<"Quince">>, <<"Satsuma">>, <<"Clementine">>, <<"Loquat">>, <<"Damson">>],
    ShortFruits = [F || F <- Fruits, byte_size(F) =< 7],
    <<A:32, B:32>> = crypto:strong_rand_bytes(8),
    Adjective = lists:nth(A rem length(Adjectives) + 1, Adjectives),
    Fruit = lists:nth(B rem length(ShortFruits) + 1, ShortFruits),
    <<Adjective/binary, " ", Fruit/binary>>.
